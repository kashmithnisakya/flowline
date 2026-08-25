"""Task walkers: the kanban board API."""

import from models {
    Project,
    Member,
    Task,
    TaskView,
    TaskPage,
    TaskTotals,
    ProjectTally,
    MemberTally,
    WorkflowStep,
    AssignedTo,
    ForProject,
    OnProject,
    hydrate_views,
    resolve,
    on_attached,
    owned
}
import from walkers.util {
    now_iso,
    today_iso,
    shift_day,
    page_bounds,
    caller_level,
    level_rank,
    attach_stamp
}
import from walkers.log { record_task_event, sync_task_links }
import from constants { STATUSES, KIND_STATUS, ACTIVE_STATUSES }


# The legacy status a step stands for. Every move writes both, so the rest of
# the app keeps reading `status` and never has to know about steps.
def status_for_step(holder: Root, step_id: str) -> str {
    step = resolve(step_id);
    if not isinstance(step, WorkflowStep) or not owned(holder, step) {
        return "";
    }
    return KIND_STATUS[step.kind] if step.kind in KIND_STATUS else "In Progress";
}

# The step's owner role is a hand-off: moving a task onto a step hands it to
# whoever holds that role ON THE TASK'S PROJECT. Returns that one member, or
# an empty list when the answer is ambiguous: no owner, "anyone", no project,
# or any count of holders but one. The caller leaves assignees alone on empty.
def handoff_target(holder: Root, task: Task, step: WorkflowStep) -> list[Member] {
    role = step.owner.strip() if step.owner else "";
    if not role or role == "anyone" {
        return [];
    }
    owning = [task->:ForProject:->];
    if not owning {
        return [];
    }
    project = owning[0];
    holders: list[Member] = [];
    for m in [holder-->[?:Member]] {
        if m.active and role in m.roles and [edge m->:OnProject:->project] {
            holders.append(m);
        }
    }
    if len(holders) != 1 {
        return [];
    }
    return holders;
}

# -------------------------------------------------------------------- tasks

# How well a title matches a search: exact, then prefix, then anywhere. Lower
# ranks first, so the assistant's exact title always lands on page 1.
def title_rank(title: str, needle: str) -> int {
    low = title.lower().strip();
    if low == needle {
        return 0;
    }
    if low.startswith(needle) {
        return 1;
    }
    return 2;
}

walker ListTasks {
    """One page of tasks. `scope` picks the working set the board renders
    ("working": open plus Done touched in the last `done_days`), the history
    behind its "+N older" ("older": Done before that cutoff, newest first),
    every Done task ("done"), what the Overview calls needs-attention
    (blocked first, then most overdue) ("attention"), or everything ("all").
    `q` matches titles server-side. Filters read node fields first; the
    assignee and project edge hops run only for rows that survived, and
    `to_view()` for the page. `older` on a working page counts the Done rows
    the cutoff left out, under the same filters, so the board's "+N older"
    needs no second call. Every ordering ends in the jid so two rows that
    tie on the sort key cannot swap between one page and the next."""
    has scope: str = "working",
        q: str = "",
        project_id: str = "",
        assignee_id: str = "",
        category: str = "",
        done_days: int = 7,
        page: int = 1,
        page_size: int = 0,
        reports: list[TaskPage] = [];

    can gather with Root entry {
        (p, size, start, end) = page_bounds(self.page, self.page_size, 50, 500);
        needle = self.q.lower().strip();
        today = today_iso();
        cutoff = shift_day(today_iso(), 0 - self.done_days)
            if self.done_days > 0
            else "";
        picked: list[Task] = [];
        left_out: list[Task] = [];
        for t in [here-->[?:Task]] {
            if needle and needle not in t.title.lower() {
                continue;
            }
            if self.category and t.category != self.category {
                continue;
            }
            done = t.status == "Done";
            old = done and bool(cutoff) and t.updated_at[:10] < cutoff;
            if self.scope == "working" {
                if old {
                    left_out.append(t);
                    continue;
                }
            } elif self.scope == "older" {
                if not old {
                    continue;
                }
            } elif self.scope == "done" {
                if not done {
                    continue;
                }
            } elif self.scope == "attention" {
                if done {
                    continue;
                }
                if t.status != "Blocked" and not (t.due_date and t.due_date < today) {
                    continue;
                }
            }
            picked.append(t);
        }
        if self.project_id or self.assignee_id {
            picked = self.linked(picked);
            # `older` is only read on an unfiltered working page (the board
            # asks the "older" scope itself once a filter is on), so the
            # edge hops over the whole pre-cutoff history are skipped here.
            left_out = [];
        }
        # Sorts are stable, so the jid pass underneath every other pass is
        # what makes ties deterministic across two requests: without it a
        # row can sit on page 1 for one call and page 2 for the next.
        picked.sort(key=lambda (t: Task) { jid(t); });
        if needle {
            picked.sort(key=lambda (t: Task) { t.updated_at; }, reverse=True);
            picked.sort(key=lambda (t: Task) { title_rank(t.title, needle); });
        } elif self.scope == "older" or self.scope == "done" {
            picked.sort(key=lambda (t: Task) { t.updated_at; }, reverse=True);
        } elif self.scope == "attention" {
            # Blocked first, then the soonest due date; undated last.
            picked.sort(key=lambda (t: Task) { t.due_date or "9999-12-31"; });
            picked.sort(key=lambda (t: Task) { 0 if t.status == "Blocked" else 1; });
        } else {
            picked.sort(key=lambda (t: Task) { t.sort_order; });
        }
        report TaskPage(
            rows=hydrate_views(here, picked[start:end]),
            page=p,
            page_size=size,
            has_more=len(picked) > end,
            total=len(picked),
            older=len(left_out)
        );
    }

    # The two edge-hop filters, applied after the node-field ones so the
    # hops run for candidates only.
    def linked(found: list[Task]) -> list[Task] {
        kept: list[Task] = [];
        for t in found {
            if self.project_id {
                owning = [t->:ForProject:->];
                if not owning or jid(owning[0]) != self.project_id {
                    continue;
                }
            }
            if self.assignee_id {
                hit = False;
                for m in [t->:AssignedTo:->] {
                    if jid(m) == self.assignee_id {
                        hit = True;
                    }
                }
                if not hit {
                    continue;
                }
            }
            kept.append(t);
        }
        return kept;
    }
}

walker TaskCounts {
    """The Overview's numbers over the whole history: open tasks, Done per
    week for the four weeks ending in `monday`'s week, and total/done per
    project. Per-project counts walk in from each Project, so the cost is a
    handful of edge reads rather than one hop per task."""
    has monday: str = "",
        reports: list[TaskTotals] = [];

    can count with Root entry {
        week0 = self.monday if len(self.monday) >= 10 else today_iso();
        today = today_iso();
        # Week bounds up front: shift_day parses a date, so calling it per
        # task would be four parses per row.
        starts = [shift_day(week0, -7 * (3 - i)) for i in range(4)];
        ends = [shift_day(starts[i], 7) for i in range(4)];
        by_week = [0, 0, 0, 0];
        open_count = 0;
        overdue_count = 0;
        blocked_count = 0;
        cats: list[str] = [];
        for t in [here-->[?:Task]] {
            if t.category and t.category not in cats {
                cats.append(t.category);
            }
            if t.status != "Done" {
                open_count = open_count + 1;
                if t.status == "Blocked" {
                    blocked_count = blocked_count + 1;
                }
                if t.due_date and t.due_date < today {
                    overdue_count = overdue_count + 1;
                }
                continue;
            }
            day = t.updated_at[:10];
            for i in range(4) {
                if day >= starts[i] and day < ends[i] {
                    by_week[i] = by_week[i] + 1;
                }
            }
        }
        # Per project and per member, walking IN from each holder: a handful
        # of edge reads instead of one hop per task.
        tallies: list[ProjectTally] = [];
        for pr in [here-->[?:Project]] {
            total = 0;
            done = 0;
            blocked = 0;
            active = 0;
            for t in [pr<-:ForProject:<-] {
                total = total + 1;
                if t.status == "Done" {
                    done = done + 1;
                } elif t.status == "Blocked" {
                    blocked = blocked + 1;
                } elif t.status in ACTIVE_STATUSES {
                    active = active + 1;
                }
            }
            tallies.append(
                ProjectTally(
                    project_id=jid(pr),
                    total=total,
                    done=done,
                    blocked=blocked,
                    active=active
                )
            );
        }
        people: list[MemberTally] = [];
        for m in [here-->[?:Member]] {
            mine_open = 0;
            mine_done = 0;
            for t in [m<-:AssignedTo:<-] {
                if t.status != "Done" {
                    mine_open = mine_open + 1;
                } elif t.updated_at[:10] >= week0 {
                    mine_done = mine_done + 1;
                }
            }
            people.append(
                MemberTally(member_id=jid(m), open=mine_open, done_in_week=mine_done)
            );
        }
        cats.sort();
        report TaskTotals(
            open=open_count,
            overdue=overdue_count,
            blocked=blocked_count,
            done_by_week=by_week,
            projects=tallies,
            members=people,
            categories=cats
        );
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
        # Org members below editor cannot write tasks; silent no-op like
        # every other unauthorized mutation.
        if level_rank(caller_level(here, jid(root))) < 2 {
            disengage;
        }
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
        # After the edges: attach_stamp covers the node and its incident
        # edges, and a member-created edge is as creator-sticky as the node.
        attach_stamp(here, fresh);
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
        # The task's container is the org root reached via [here<--], NOT
        # the caller's root: members enter this graph on a foreign root.
        owners = [here<--];
        holder = owners[0];
        if level_rank(caller_level(holder, jid(root))) < 2 {
            disengage;
        }
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
        # Re-stamp: the rewired assignee/project edges are fresh and
        # creator-sticky (idempotent for the task itself).
        attach_stamp(holder, here);
        if moved {
            record_task_event(holder, here, "Moved to " + here.status, here.updated_at);
        }
        report here.to_view();
        disengage;
    }
}

walker GetTask(find_task) {
    """One task by jid, owner-checked by find_task. For a deep link to a card
    the board's working set does not hold (older history, a search hit)."""
    has reports: list[TaskView] = [];

    can deliver with Task entry {
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
        # Editor gate (see UpdateTask).
        if level_rank(caller_level(holder, jid(root))) < 2 {
            disengage;
        }
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
        owners = [here<--];
        holder = owners[0];
        # Editor gate (see UpdateTask).
        if level_rank(caller_level(holder, jid(root))) < 2 {
            disengage;
        }
        landing = self.status;
        label = self.status;
        # Who the move hands the task to: one member, or empty. A list, not
        # an Optional: the checker does not narrow `Member | None` through
        # `if`, so the connect and the `.name` read would not type.
        handed: list[Member] = [];
        if self.step_id {
            mapped = status_for_step(holder, self.step_id);
            # An unknown or foreign step id is a no-op, not a silent move to
            # a blank column.
            if not mapped {
                disengage;
            }
            landing = mapped;
            # Only a CHANGE of step is a hand-off. Re-dropping a card in its
            # own column (a reorder) must not reassign it.
            if self.step_id != here.step_id {
                step = resolve(self.step_id);
                if isinstance(step, WorkflowStep) {
                    handed = handoff_target(holder, here, step);
                }
            }
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
        # A hand-off replaces the assignees: the card changes hands, it does
        # not gain a hand. The log line names who it went to.
        note = "Moved to " + label;
        took = False;
        if handed {
            target = handed[0];
            already = [here->:AssignedTo:->];
            if len(already) != 1 or jid(already[0]) != jid(target) {
                for e in [edge here->:AssignedTo:->] {
                    del e;
                }
                here +>:AssignedTo():+> target;
                note = note + " · " + target.name;
                took = True;
            }
        }
        if took {
            # The handoff rewired the AssignedTo edge; re-stamp so every
            # member keeps seeing it.
            attach_stamp(holder, here);
        }
        if landing != was or took {
            record_task_event(holder, here, note, here.updated_at);
        }
        report here.to_view();
        disengage;
    }
}

walker DeleteTask(find_task) {
    can remove with Task entry {
        owners = [here<--];
        holder = owners[0];
        # Editor gate (see UpdateTask).
        if level_rank(caller_level(holder, jid(root))) < 2 {
            disengage;
        }
        gone = jid(here);
        del here;
        report {"deleted": gone};
        disengage;
    }
}
