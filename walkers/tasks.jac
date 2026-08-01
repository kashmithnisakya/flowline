"""Task walkers: the kanban board API."""

import from models {
    Project, Member, Task, TaskView,
    AssignedTo, ForProject, resolve, on_attached, owned
}
import from walkers.util { now_iso }
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
        assignee_id: str = "",
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
            created_at=stamp, updated_at=stamp, sort_order=peak + 1024.0
        );
        on_attached(here, fresh);
        m = resolve(self.assignee_id);
        if isinstance(m, Member) and owned(here, m) {
            fresh +>:AssignedTo():+> m;
        }
        p = resolve(self.project_id);
        if isinstance(p, Project) and owned(here, p) {
            fresh +>:ForProject():+> p;
        }
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
        assignee_id: str = "",
        project_id: str = "",
        reports: list[TaskView] = [];

    can apply with Task entry {
        # The task's container is the caller's root (root ++> Task).
        owners = [here<--];
        holder = owners[0];
        here.title = self.title;
        here.category = self.category;
        here.priority = self.priority;
        here.status = self.status;
        here.due_date = self.due_date;
        here.notes = self.notes;
        here.updated_at = now_iso();
        for e in [edge here ->:AssignedTo:->] {
            del e;
        }
        m = resolve(self.assignee_id);
        if isinstance(m, Member) and owned(holder, m) {
            here +>:AssignedTo():+> m;
        }
        for e in [edge here ->:ForProject:->] {
            del e;
        }
        p = resolve(self.project_id);
        if isinstance(p, Project) and owned(holder, p) {
            here +>:ForProject():+> p;
        }
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
        here.status = self.status;
        here.sort_order = peak + 1024.0;
        here.updated_at = now_iso();
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

