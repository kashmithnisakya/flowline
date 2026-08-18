"""Task walkers: the kanban board API."""

import from models {
    Project,
    Member,
    Task,
    TaskView,
    WorkflowStep,
    AssignedTo,
    ForProject,
    resolve,
    on_attached,
    owned
}
import from walkers.util { now_iso }
import from walkers.log { record_task_event, sync_task_links }
import from constants { STATUSES, KIND_STATUS }


# The legacy status a step stands for. Every move writes both, so the rest of
# the app keeps reading `status` and never has to know about steps.
def status_for_step(holder: Root, step_id: str) -> str {
    step = resolve(step_id);
    if not isinstance(step, WorkflowStep) or not owned(holder, step) {
        return "";
    }
    return KIND_STATUS[step.kind] if step.kind in KIND_STATUS else "In Progress";
}

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
        step_id: str = "",
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
        step = "";
        if self.step_id {
            mapped = status_for_step(here, self.step_id);
            if mapped {
                col = mapped;
                step = self.step_id;
            }
        }
        peak = 0.0;
        for t in [here-->[?:Task]] {
            in_column = (
                t.step_id == step if step else (t.status == col and not t.step_id)
            );
            if in_column and t.sort_order > peak {
                peak = t.sort_order;
            }
        }
        stamp = now_iso();
        fresh = here ++> Task(
            title=self.title.strip(),
            category=self.category,
            priority=self.priority,
            status=col,
            step_id=step,
            due_date=self.due_date,
            notes=self.notes,
            issue_link=self.issue_link,
            created_at=stamp,
            updated_at=stamp,
            sort_order=peak + 1024.0
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
    Every task mutation subclasses this, jobj resolution alone is NOT
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
        step_id: str = "",
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
        landing = self.status;
        if self.step_id {
            mapped = status_for_step(holder, self.step_id);
            if mapped {
                landing = mapped;
                here.step_id = self.step_id;
            }
        }
        moved = landing and landing != here.status;
        here.title = self.title;
        here.category = self.category;
        here.priority = self.priority;
        here.status = landing;
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
        for e in [edge here->:AssignedTo:->] {
            del e;
        }
        for aid in self.assignee_ids {
            m = resolve(aid);
            if isinstance(m, Member) and owned(holder, m) {
                here +>:AssignedTo():+> m;
            }
        }
        for e in [edge here->:ForProject:->] {
            del e;
        }
        p = resolve(self.project_id);
        if isinstance(p, Project) and owned(holder, p) {
            here +>:ForProject():+> p;
        }
        if moved {
            record_task_event(holder, here, "Moved to " + here.status, here.updated_at);
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
    """The drag-drop / arrow-move endpoint. Server-authoritative: a move appends
    to the end of the target column. `step_id` is the flow line column and its
    mapped status is written too; without it, the legacy status-only move."""
    has status: str = "",
        step_id: str = "",
        step_name: str = "",
        reports: list[TaskView] = [];

    can move with Task entry {
        # The task's container is the caller's root (root ++> Task).
        owners = [here<--];
        holder = owners[0];
        landing = self.status;
        label = self.status;
        if self.step_id {
            mapped = status_for_step(holder, self.step_id);
            # An unknown or foreign step id is a no-op, not a silent move to
            # a blank column.
            if not mapped {
                disengage;
            }
            landing = mapped;
            here.step_id = self.step_id;
            label = self.step_name or mapped;
        } else {
            # A status-only move (the assistant, a merged PR, an org with no
            # flow line) must drop whatever step the task was on, or the board
            # keeps drawing it in the old column while the status says
            # otherwise.
            here.step_id = "";
        }
        # Peak over the column the task is LANDING in, counted the way the
        # board draws it: step-addressed tasks by step, everything else by
        # status.
        peak = 0.0;
        for t in [holder-->[?:Task]] {
            in_column = (
                t.step_id == self.step_id
                    if self.step_id
                    else (t.status == landing and not t.step_id)
            );
            if in_column and t.sort_order > peak {
                peak = t.sort_order;
            }
        }
        was = here.status;
        here.status = landing;
        here.sort_order = peak + 1024.0;
        here.updated_at = now_iso();
        if landing != was {
            record_task_event(holder, here, "Moved to " + label, here.updated_at);
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
