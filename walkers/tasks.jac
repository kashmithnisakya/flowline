"""Task walkers: the kanban board API."""

import from models {
    Project, Member, Task, TaskView,
    AssignedTo, ForProject, resolve, on_attached, owned
}
import from walkers.util { now_iso }
import from walkers.log { record_task_event, sync_task_links }
import from constants { STATUSES }

# -------------------------------------------------------------------- tasks

walker ListTasks {
    has results: list[TaskView] = [],
        reports: list[list[TaskView]] = [];

    can start with Root entry {
        visit [here-->[?:Task]];
    }

    can gather with Task entry {
        self.results.append(here.to_view());
    }

    can deliver with Root exit {
        self.results.sort(key=lambda (t: TaskView) { t.sort_order; });
        report self.results;
    }
}

walker CreateTask {
    has title: str,
        category: str = "",
        priority: str = "Medium",
        status: str = "Backlog",
        due_date: str = "",
        notes: str = "",
        issue_link: str = "",
        assignee_ids: list[str] = [],
        project_id: str = "",
        reports: list[TaskView] = [];

    can create with Root entry {
        if not self.title.strip() {
            disengage;
        }
        col = self.status if self.status in STATUSES else "Backlog";
        peak = 0.0;
        for t in [here-->[?:Task, status == col]] {
            if t.sort_order > peak {
                peak = t.sort_order;
            }
        }
        stamp = now_iso();
        fresh = here ++> Task(
            title=self.title.strip(), category=self.category,
            priority=self.priority, status=col,
            due_date=self.due_date, notes=self.notes,
            issue_link=self.issue_link,
            created_at=stamp, updated_at=stamp, sort_order=peak + 1024.0
        );
        on_attached(here, fresh);
        for aid in self.assignee_ids {
            m = resolve(aid);
            if isinstance(m, Member) and owned(here, m) {
                fresh +>:AssignedTo():+> m;
            }
        }
        p = resolve(self.project_id);
        if isinstance(p, Project) and owned(here, p) {
            fresh +>:ForProject():+> p;
        }
        record_task_event(here, fresh, "Added to " + col, stamp);
        report fresh.to_view();
    }
}

walker find_task {
    """Lookup base: resolve the jid once, verify org parentage, then visit.
    Every task mutation subclasses this — jobj resolution alone is NOT
    authorization."""
    has task_id: str = "";

    can locate with Root entry {
        target = resolve(self.task_id);
        if isinstance(target, Task) and owned(here, target) {
            visit [target];
        }
    }
}

walker UpdateTask(find_task) {
    has title: str = "",
        category: str = "",
        priority: str = "",
        status: str = "",
        due_date: str = "",
        notes: str = "",
        issue_link: str = "",
        pr_link: str = "",
        reviewer_id: str = "",
        review_due: str = "",
        assignee_ids: list[str] = [],
        project_id: str = "",
        reports: list[TaskView] = [];

    can apply with Task entry {
        # The task's container is the caller's root (root ++> Task).
        owners = [here<--];
        holder = owners[0];
        moved = self.status and self.status != here.status;
        here.title = self.title;
        here.category = self.category;
        here.priority = self.priority;
        here.status = self.status;
        here.due_date = self.due_date;
        here.notes = self.notes;
        here.issue_link = self.issue_link;
        here.pr_link = self.pr_link;
        here.review_due = self.review_due;
        rev = resolve(self.reviewer_id);
        if isinstance(rev, Member) and owned(holder, rev) {
            here.reviewer_id = self.reviewer_id;
            here.reviewer_name = rev.name;
        } else {
            here.reviewer_id = "";
            here.reviewer_name = "";
        }
        here.updated_at = now_iso();
        for e in [edge here ->:AssignedTo:->] {
            del e;
        }
        for aid in self.assignee_ids {
            m = resolve(aid);
            if isinstance(m, Member) and owned(holder, m) {
                here +>:AssignedTo():+> m;
            }
        }
        for e in [edge here ->:ForProject:->] {
            del e;
        }
        p = resolve(self.project_id);
        if isinstance(p, Project) and owned(holder, p) {
            here +>:ForProject():+> p;
        }
        if moved {
            record_task_event(
                holder, here, "Moved to " + here.status, here.updated_at
            );
        }
        report here.to_view();
        disengage;
    }
}

walker SetMoveInfo(find_task) {
    """The move handoff, all fields optional. Review gets a reviewer, an
    ETA and a PR link; Blocked and Changes Requested get a note. Partial
    by design; anything left empty stays untouched."""
    has reviewer_id: str = "",
        review_due: str = "",
        pr_link: str = "",
        note: str = "",
        reports: list[TaskView] = [];

    can apply with Task entry {
        owners = [here<--];
        holder = owners[0];
        rev = resolve(self.reviewer_id);
        if isinstance(rev, Member) and owned(holder, rev) {
            here.reviewer_id = self.reviewer_id;
            here.reviewer_name = rev.name;
        }
        if self.review_due {
            here.review_due = self.review_due;
        }
        if self.pr_link.strip() {
            here.pr_link = self.pr_link.strip();
        }
        if self.note.strip() {
            here.notes = self.note.strip();
        }
        here.updated_at = now_iso();
        sync_task_links(holder, here, self.note.strip());
        report here.to_view();
        disengage;
    }
}

walker MoveTask(find_task) {
    """The drag-drop / arrow-move endpoint. Server-authoritative ordering:
    a move appends to the end of the target column."""
    has status: str = "",
        reports: list[TaskView] = [];

    can move with Task entry {
        # The task's container is the caller's root (root ++> Task).
        owners = [here<--];
        holder = owners[0];
        peak = 0.0;
        for t in [holder-->[?:Task, status == self.status]] {
            if t.sort_order > peak {
                peak = t.sort_order;
            }
        }
        was = here.status;
        here.status = self.status;
        here.sort_order = peak + 1024.0;
        here.updated_at = now_iso();
        if self.status != was {
            record_task_event(
                holder, here, "Moved to " + here.status, here.updated_at
            );
        }
        report here.to_view();
        disengage;
    }
}

walker DeleteTask(find_task) {
    can remove with Task entry {
        gone = jid(here);
        del here;
        report {"deleted": gone};
        disengage;
    }
}

