"""Task walkers: the kanban board API."""

import from models {
    Project,
    Projects,
    Member,
    Task,
    TaskView,
    TaskPage,
    TaskTitle,
    TaskTotals,
    WeeklyHistory,
    ProjectTally,
    MemberTally,
    WorkflowStep,
    AssignedTo,
    OnProject,
    HasRole,
    TaskNames,
    task_names,
    hydrate_rows,
    resolve,
    on_attached,
    owned,
    all_tasks,
    all_tasks_in,
    open_tasks,
    done_tasks,
    done_tasks_in,
    done_since,
    done_before,
    done_before_in,
    working_tasks,
    project_tasks_in,
    project_open,
    project_done,
    project_done_in,
    project_done_since,
    project_done_before,
    project_done_before_in,
    done_since_count,
    project_done_since_count,
    project_working,
    step_column_peak,
    step_column_below,
    step_column_above,
    step_column,
    status_column_peak,
    status_column_below,
    status_column_above,
    status_column,
    seeded_done,
    task_project,
    count_task,
    tally_totals,
    categories_of,
    note_category,
    forget_category,
    projects_of,
    members_of,
    roles_of,
    steps_of,
    rehome_task,
    week_start
}
import from services.util {
    now_iso,
    today_iso,
    shift_day,
    page_bounds,
    clean_tags,
    short_id,
    iso_day,
    done_cutoff,
    order_working,
    done_day,
    moved_to_done,
    ensure_tallies,
    ensure_history,
    ensure_keys
}
import from services.tasks.history {
    HistoryBase,
    Column,
    SORT_FIELDS,
    board_columns,
    sorted_window,
    column_window,
    parts_count
}
import from jaclang.lib.jaclib { QPred }
import from services.log.log { record_task_event, sync_task_links }
import from services.github.util { sync_issue_state }
import from constants { STATUSES, STATUS_KIND, KIND_STATUS, ACTIVE_STATUSES }


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
    owning = [task<--[?:Project]];
    if not owning {
        return [];
    }
    project = owning[0];
    holders: list[Member] = [];
    for r in roles_of(holder) {
        if r.name != role {
            continue;
        }
        for m in [r<-:HasRole:<-] {
            if m.active and [edge m->:OnProject:->project] {
                holders.append(m);
            }
        }
    }
    if len(holders) != 1 {
        return [];
    }
    return holders;
}

# What a move onto a step does beyond the step: the step's owner takes the
# task (`handed`, from handoff_target), and a move across Done writes back
# to GitHub. Returns the log line's tail, "" when neither applied.
def landing_tail(holder: Root, t: Task, handed: list[Member], was: str) -> str {
    tail = "";
    if handed {
        target = handed[0];
        already = [t->:AssignedTo:->];
        if len(already) != 1 or jid(already[0]) != jid(target) {
            t.assignee_ids = link_assignees(holder, t, [jid(target)]);
            tail = tail + " · " + target.full_name();
        }
    }
    if (t.status == "Done") != (was == "Done") {
        wrote = sync_issue_state(holder, t, t.status == "Done", t.updated_at);
        if wrote {
            tail = tail + " · " + wrote;
        }
    }
    return tail;
}

# Move `t` to the end of `step`'s column as a drag there would, and log why.
# `peaks` keeps each column's top per step id across one pass: a pushed
# query does not see this request's writes, so two landings would tie.
def land_on_step(
    holder: Root,
    t: Task,
    step: WorkflowStep,
    why: str,
    stamp: str,
    peaks: dict[str, float]
) {
    sid = jid(step);
    if sid not in peaks {
        top = step_column_peak(holder, sid);
        peaks[sid] = top[0].sort_order if top else 0.0;
    }
    peaks[sid] = peaks[sid] + 1024.0;
    handed = handoff_target(holder, t, step);
    was = t.status;
    t.step_id = sid;
    t.set_status(
        KIND_STATUS[step.kind] if step.kind in KIND_STATUS else "In Progress", stamp
    );
    t.sort_order = peaks[sid];
    t.updated_at = stamp;
    tail = landing_tail(holder, t, handed, was);
    record_task_event(holder, t, "Moved to " + step.name + " · " + why + tail, stamp);
}

# A GitHub fact the flow line can act on: follow the first transition out
# of the task's step whose trigger is `trigger` (for "label", one waiting
# for a label in `added`). A target whose entry rule turns the task away
# keeps it where it is, and the log says why. True when the task moved.
def follow_trigger(
    holder: Root,
    t: Task,
    trigger: str,
    added: list[str],
    why: str,
    stamp: str,
    peaks: dict[str, float]
) -> bool {
    source = resolve(t.step_id) if t.step_id else None;
    if not isinstance(source, WorkflowStep) or not owned(holder, source) {
        return False;
    }
    fresh = [a.strip().lower() for a in added];
    for tr in source.transitions {
        if tr.get("trigger", "") != trigger {
            continue;
        }
        if trigger == "label"
            and tr.get("trigger_label", "").strip().lower() not in fresh {
            continue;
        }
        target = resolve(tr["to"]);
        if not isinstance(target, WorkflowStep) or not owned(holder, target) {
            continue;
        }
        refused = target.refusal(t.due_date, t.pr_link);
        if refused {
            record_task_event(
                holder, t, "Stayed on " + source.name + " · " + refused, stamp
            );
            return False;
        }
        land_on_step(holder, t, target, why, stamp, peaks);
        return True;
    }
    return False;
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

# The needs-attention rule: an open task that is Blocked or already past due.
def needs_attention(t: Task, today: str) -> bool {
    if t.status == "Done" {
        return False;
    }
    return t.status == "Blocked" or bool(t.due_date and t.due_date < today);
}


# Blocked first, then soonest due date; undated last. Callers sort by jid
# first, so ties stay deterministic across two requests.
def order_attention(rows: list[Task]) {
    rows.sort(key=lambda (t: Task) { t.due_date or "9999-12-31"; });
    rows.sort(key=lambda (t: Task) { 0 if t.status == "Blocked" else 1; });
}


glob PRIORITY_RANK: dict[str, int] = {"High": 0, "Medium": 1, "Low": 2},
     # A date no done_at reaches: the done scope is Done before it.
     FAR_FUTURE: str = "9999-12-31";

# A task's board column as a number, by the board's placement rule: its own
# step, else the status itself (no flow line), else the first column of its
# status's kind. `rank` and `kind_rank` come from column_ranks.
def column_rank(t: Task, rank: dict[str, int], kind_rank: dict[str, int]) -> int {
    if t.step_id in rank {
        return rank[t.step_id];
    }
    if t.status in rank {
        return rank[t.status];
    }
    kind = STATUS_KIND[t.status] if t.status in STATUS_KIND else "active";
    return kind_rank[kind] if kind in kind_rank else 0;
}


# The board's column keys in order (canvas x, ties by sort_order; without a
# flow line the columns are STATUSES) with each key's rank and each kind's
# first column, for column_rank.
def column_ranks(holder: Root) -> tuple[list[str], dict[str, int], dict[str, int]] {
    order = steps_of(holder);
    order.sort(key=lambda (s: WorkflowStep) { s.sort_order; });
    order.sort(key=lambda (s: WorkflowStep) { s.x; });
    keys: list[str] = [];
    rank: dict[str, int] = {};
    kind_rank: dict[str, int] = {};
    for (i, s) in enumerate(order) {
        keys.append(jid(s));
        rank[jid(s)] = i;
        if s.kind not in kind_rank {
            kind_rank[s.kind] = i;
        }
    }
    if len(order) == 0 {
        for (i, st) in enumerate(STATUSES) {
            keys.append(st);
            rank[st] = i;
            kind = STATUS_KIND[st] if st in STATUS_KIND else "active";
            if kind not in kind_rank {
                kind_rank[kind] = i;
            }
        }
    }
    return (keys, rank, kind_rank);
}


# The table view's user-chosen column sort, over node fields only so it runs
# on the full match set before paging. Priority sorts by urgency; step sorts
# in board column order, cards in board order within a column; undated tasks
# sort last on the due column. The jid pass keeps ties deterministic.
def sort_tasks(holder: Root, rows: list[Task], field: str, reverse: bool) {
    rows.sort(key=lambda (t: Task) { jid(t); });
    if field == "step" {
        (keys, rank, kind_rank) = column_ranks(holder);
        rows.sort(key=lambda (t: Task) { t.sort_order; });
        rows.sort(
            key=lambda (t: Task) { column_rank(t, rank, kind_rank); }, reverse=reverse
        );
    } elif field == "title" {
        rows.sort(key=lambda (t: Task) { t.title.lower(); }, reverse=reverse);
    } elif field == "priority" {
        rows.sort(
            key=lambda (t: Task) { PRIORITY_RANK[t.priority]
                if t.priority in PRIORITY_RANK
                else 1; },
            reverse=reverse
        );
    } elif field == "category" {
        rows.sort(key=lambda (t: Task) { t.category.lower(); }, reverse=reverse);
    } elif field == "estimate" {
        rows.sort(key=lambda (t: Task) { t.estimate; }, reverse=reverse);
    } elif field == "due" {
        rows.sort(
            key=lambda (t: Task) { t.due_date or "9999-12-31"; }, reverse=reverse
        );
    } elif field == "created" {
        rows.sort(key=lambda (t: Task) { t.created_at; }, reverse=reverse);
    } else {
        rows.sort(key=lambda (t: Task) { t.updated_at; }, reverse=reverse);
    }
}


walker ListTasks {
    """One page of tasks. `scope` picks the working set the board renders
    ("working": open plus Done reached in the last `done_days`), the history
    behind its "+N older" ("older": Done before that cutoff, newest first),
    every Done task ("done"), what the Overview calls needs-attention
    (blocked first, then most overdue) ("attention"), or everything ("all").
    A history scope with no title search or tag filter pages in the store
    (services/tasks/history.jac): scope, filters and sort become the query,
    so a page loads its own rows. The live scopes, and a search or tag
    filter, page their loaded pool. `older` on an unfiltered working page
    counts the Done rows the cutoff left out, from the project tallies. Every
    ordering ends in the jid so two rows that tie on the sort key cannot
    swap between one page and the next."""
    has scope: str = "working",
        q: str = "",
        project_id: str = "",
        assignee_id: str = "",
        category: str = "",
        # A tag the task must carry; "estimated" is "" (any), "yes" (has an
        # estimate) or "no" (unestimated).
        tag: str = "",
        estimated: str = "",
        # A priority, and a board column (a step jid, or a status when the
        # workspace has no flow line), each "" for any.
        priority: str = "",
        column: str = "",
        # The table view's column sort; empty keeps the scope's own order.
        sort: str = "",
        sort_dir: str = "asc",
        done_days: int = 7,
        page: int = 1,
        page_size: int = 0,
        reports: list[TaskPage] = [];

    # A project filter visits that project and pages its own children;
    # otherwise the page is built over every project from the root. Keys
    # filled in this request are invisible to a pushed query until the next
    # one, so that request pages what ensure_keys loaded.
    can start with Root entry {
        ensure_tallies(here);
        fresh = ensure_keys(here);
        if self.project_id {
            p = resolve(self.project_id);
            if not (isinstance(p, Project) and owned(here, p)) {
                report self.page_of(here, [], []);
            } elif fresh {
                report self.page_of(here, self.pool_of(here, [p]), [p]);
            } else {
                visit [p];
            }
        } else {
            cut = None if fresh else self.store_page(here, []);
            report cut or self.page_of(here, self.pool_of(here, []), []);
        }
    }

    can gather with Project entry {
        cut = self.store_page(root, [here]);
        report cut or self.page_of(root, self.pool_of(root, [here]), [here]);
        disengage;
    }

    # A history scope without a title search or a tag filter, paged in the
    # store: its rows, and its total from the tallies or from counts in the
    # store. Anything else answers None and pages the loaded pool.
    def store_page(holder: Root, projects: list[Project]) -> TaskPage | None {
        if self.scope not in ["older", "done", "all"] or self.q.strip() or self.tag {
            return None;
        }
        (p, size, start, end) = page_bounds(self.page, self.page_size, 50, 500);
        cutoff = done_cutoff(self.done_days) if self.scope == "older" else FAR_FUTURE;
        whole = self.history_total(holder, [], cutoff);
        empty = TaskPage(
            rows=[], page=p, page_size=size, has_more=False, total=0, scope_total=whole
        );
        base = self.history_base(holder, projects, cutoff);
        if base is None or not cutoff {
            return empty;
        }
        columns: list[Column] = [];
        parts: list[list[QPred]] = [[]];
        if self.sort == "step" or self.column {
            columns = board_columns(holder);
        }
        if self.column {
            columns = [
                c
                for c in columns
                if c.key == self.column
            ];
            if len(columns) == 0 {
                return empty;
            }
            parts = columns[0].parts;
        }
        rows: list[Task] = [];
        if self.sort == "step" {
            rows = column_window(base, columns, self.sort_dir == "desc", start, end);
        } else {
            (field, desc) = self.store_order();
            rows = sorted_window(base, parts, field, desc, start, end);
        }
        # Every column together is the whole query, so only a column filter
        # counts its parts; with no filter the tallies answer.
        total = self.history_total(holder, projects, cutoff)
            if not self.narrowed()
            else parts_count(base, parts);
        return TaskPage(
            rows=hydrate_rows(holder, rows),
            page=p,
            page_size=size,
            has_more=total > end,
            total=total,
            scope_total=whole
        );
    }

    # Where the store's query starts and what every row must meet: the
    # scope and the filters. An assignee starts from the member, back over
    # AssignedTo; a foreign or unknown one, or no projects box, is None.
    def history_base(
        holder: Root, projects: list[Project], cutoff: str
    ) -> HistoryBase | None {
        preds: list[QPred] = [];
        if self.scope != "all" {
            preds.append(QPred(field="status", op="==", value="Done"));
        }
        if self.scope == "older" {
            preds.append(QPred(field="done_at", op="<", value=cutoff));
        }
        if self.category {
            preds.append(QPred(field="category", op="==", value=self.category));
        }
        if self.priority {
            preds.append(QPred(field="priority", op="==", value=self.priority));
        }
        if self.estimated == "yes" {
            preds.append(QPred(field="estimate", op=">", value=0.0));
        } elif self.estimated == "no" {
            preds.append(QPred(field="estimate", op="<=", value=0.0));
        }
        if self.assignee_id {
            m = resolve(self.assignee_id);
            if not isinstance(m, Member) or not owned(holder, m) {
                return None;
            }
            if projects {
                preds.append(
                    QPred(field="project_id", op="==", value=jid(projects[0]))
                );
            }
            return HistoryBase(origin=[m], via="member", preds=preds);
        }
        if projects {
            return HistoryBase(origin=[projects[0]], via="project", preds=preds);
        }
        boxes = [holder-->[?:Projects]];
        if not boxes {
            return None;
        }
        return HistoryBase(origin=[boxes[0]], via="box", preds=preds);
    }

    # The table's column sort, else the scope's own order: newest update
    # first for the Done history, board order for everything.
    def store_order -> tuple[str, bool] {
        if self.sort {
            field = SORT_FIELDS[self.sort]
                if self.sort in SORT_FIELDS
                else "updated_at";
            return (field, self.sort_dir == "desc");
        }
        if self.scope in ["older", "done"] {
            return ("updated_at", True);
        }
        return ("sort_order", False);
    }

    # Any filter besides a project visit, which the tallies already answer.
    def narrowed -> bool {
        return bool(
            self.category
                or self.priority
                or self.estimated
                or self.assignee_id
                or self.column
        );
    }

    # The scope's size from the tallies: every task, every Done task, or the
    # Done tasks less a count in the store of those reached since the cutoff.
    def history_total(holder: Root, projects: list[Project], cutoff: str) -> int {
        if projects {
            pr = projects[0];
            if self.scope == "all" {
                return pr.task_total;
            }
            return pr.done_total - project_done_since_count(pr, cutoff)
                if self.scope == "older"
                else pr.done_total;
        }
        totals = tally_totals(holder);
        if self.scope == "all" {
            return totals[0];
        }
        return totals[1] - done_since_count(holder, cutoff)
            if self.scope == "older"
            else totals[1];
    }

    # The rows a scope pages over, from the pushed readers: the working set
    # or the open tasks for the live scopes, the Done history or everything
    # for the history scopes, narrowed by the category when one is set.
    # `projects` is the visited project, or empty for the whole workspace.
    def pool_of(holder: Root, projects: list[Project]) -> list[Task] {
        cutoff = done_cutoff(self.done_days);
        cat = self.category;
        if projects {
            p = projects[0];
            if self.scope == "working" {
                return project_working(p, cutoff);
            } elif self.scope == "attention" {
                return project_open(p);
            } elif self.scope == "older" {
                return project_done_before_in(p, cutoff, cat)
                    if cat
                    else project_done_before(p, cutoff);
            } elif self.scope == "done" {
                return project_done_in(p, cat) if cat else project_done(p);
            }
            return project_tasks_in(p, cat) if cat else [p-->[?:Task]];
        }
        if self.scope == "working" {
            return working_tasks(holder, cutoff);
        } elif self.scope == "attention" {
            return open_tasks(holder);
        } elif self.scope == "older" {
            return done_before_in(holder, cutoff, cat)
                if cat
                else done_before(holder, cutoff);
        } elif self.scope == "done" {
            return done_tasks_in(holder, cat) if cat else done_tasks(holder);
        }
        return all_tasks_in(holder, cat) if cat else all_tasks(holder);
    }

    # Filter and sort on node fields over the pool, hydrate the page.
    def page_of(holder: Root, pool: list[Task], projects: list[Project]) -> TaskPage {
        (p, size, start, end) = page_bounds(self.page, self.page_size, 50, 500);
        needle = self.q.lower().strip();
        today = today_iso();
        cutoff = done_cutoff(self.done_days);
        filtered = bool(needle or self.tag or self.project_id or self.narrowed());
        # A column filter places each row by the board's rule.
        (keys, rank, kind_rank) = column_ranks(holder) if self.column else ([], {}, {});
        picked: list[Task] = [];
        recent_done = 0;
        for t in pool {
            if needle and needle not in t.title.lower() {
                continue;
            }
            if self.category and t.category != self.category {
                continue;
            }
            if self.tag and self.tag not in t.tags {
                continue;
            }
            if self.estimated == "yes" and t.estimate <= 0.0 {
                continue;
            }
            if self.estimated == "no" and t.estimate > 0.0 {
                continue;
            }
            if self.priority and t.priority != self.priority {
                continue;
            }
            if self.column and keys[column_rank(t, rank, kind_rank)] != self.column {
                continue;
            }
            if self.scope == "attention" and not needs_attention(t, today) {
                continue;
            }
            if t.status == "Done" {
                recent_done = recent_done + 1;
            }
            picked.append(t);
        }
        if self.assignee_id {
            picked = self.assigned_to(holder, picked);
        }
        # `older` is only filled on an unfiltered working page (the board
        # asks the "older" scope itself once a filter is on): the Done
        # tally less the Done rows the cutoff kept, no history loaded.
        older = 0;
        if self.scope == "working" and cutoff and not filtered {
            older = tally_totals(holder)[1] - recent_done;
        }
        # Sorts are stable, so the jid pass underneath every other pass is
        # what makes ties deterministic across two requests: without it a
        # row can sit on page 1 for one call and page 2 for the next.
        picked.sort(key=lambda (t: Task) { jid(t); });
        if self.sort {
            # An explicit column sort wins over the scope default and the
            # search rank: the table user asked for this order.
            sort_tasks(holder, picked, self.sort, self.sort_dir == "desc");
        } elif needle {
            picked.sort(key=lambda (t: Task) { t.updated_at; }, reverse=True);
            picked.sort(key=lambda (t: Task) { title_rank(t.title, needle); });
        } elif self.scope == "older" or self.scope == "done" {
            picked.sort(key=lambda (t: Task) { t.updated_at; }, reverse=True);
        } elif self.scope == "attention" {
            order_attention(picked);
        } else {
            order_working(picked);
        }
        return TaskPage(
            rows=hydrate_rows(holder, picked[start:end]),
            page=p,
            page_size=size,
            has_more=len(picked) > end,
            total=len(picked),
            older=older,
            scope_total=self.scope_size(holder, pool, projects, cutoff, today)
        );
    }

    # The scope's count with no filter on: the pool when it is the whole
    # scope, else a tally, or one more pushed read for the live scopes (a
    # project or category filter narrowed the pool in the query).
    def scope_size(
        holder: Root, pool: list[Task], projects: list[Project], cutoff: str, today: str
    ) -> int {
        whole = pool;
        if projects or self.category {
            if self.scope == "done" {
                return tally_totals(holder)[1];
            } elif self.scope == "all" {
                return tally_totals(holder)[0];
            } elif self.scope == "older" {
                return tally_totals(holder)[1] - done_since_count(holder, cutoff)
                    if cutoff
                    else 0;
            }
            whole = working_tasks(holder, cutoff)
                if self.scope == "working"
                else open_tasks(holder);
        }
        if self.scope != "attention" {
            return len(whole);
        }
        n = 0;
        for t in whole {
            if needs_attention(t, today) {
                n = n + 1;
            }
        }
        return n;
    }

    # The assignee filter, read off the rows' link field. A foreign or
    # unknown id matches nothing.
    def assigned_to(holder: Root, found: list[Task]) -> list[Task] {
        m = resolve(self.assignee_id);
        if not isinstance(m, Member) or not owned(holder, m) {
            return [];
        }
        return [
            t
            for t in found
            if self.assignee_id in t.assignee_ids
        ];
    }
}

# The Monday of the week the Overview's window ends in: `monday` snapped to
# its week, or this week's. The weekly counts are keyed by these Mondays.
def week_of(monday: str) -> str {
    anchor = monday if len(monday) >= 10 else today_iso();
    return week_start(anchor) or anchor;
}


# Every Overview number. `open` is every open task and `week_done` the Done
# tasks since week_of(monday). Done per week is the projects' weekly counts
# and the all-time totals their tallies, both kept on write, so the only
# Done rows read are this week's (for who finished what).
def task_totals(
    holder: Root, open: list[Task], week_done: list[Task], names: TaskNames, monday: str
) -> TaskTotals {
    week0 = week_of(monday);
    today = today_iso();
    starts = [shift_day(week0, -7 * (3 - i)) for i in range(4)];
    by_week = [0, 0, 0, 0];
    open_count = 0;
    overdue_count = 0;
    blocked_count = 0;
    blocked_by_project: dict[str, int] = {};
    active_by_project: dict[str, int] = {};
    open_by_member: dict[str, int] = {};
    done_by_member: dict[str, int] = {};
    days = [shift_day(week0, i) for i in range(7)];
    by_day = [0, 0, 0, 0, 0, 0, 0];
    for t in open {
        open_count = open_count + 1;
        if t.status == "Blocked" {
            blocked_count = blocked_count + 1;
            blocked_by_project[t.project_id] = (
                blocked_by_project[t.project_id]
                    if t.project_id in blocked_by_project
                    else 0
            )
                + 1;
        } elif t.status in ACTIVE_STATUSES {
            active_by_project[t.project_id] = (
                active_by_project[t.project_id]
                    if t.project_id in active_by_project
                    else 0
            )
                + 1;
        }
        if t.due_date and t.due_date < today {
            overdue_count = overdue_count + 1;
        }
        for who in names.ids_of(t) {
            open_by_member[who] = (open_by_member[who] if who in open_by_member else 0)
                + 1;
        }
    }
    for t in week_done {
        if not moved_to_done(t) or done_day(t) < week0 {
            continue;
        }
        if done_day(t) in days {
            at = days.index(done_day(t));
            by_day[at] = by_day[at] + 1;
        }
        for who in names.ids_of(t) {
            done_by_member[who] = (done_by_member[who] if who in done_by_member else 0)
                + 1;
        }
    }
    tallies: list[ProjectTally] = [];
    for pr in projects_of(holder) {
        pid = jid(pr);
        for (i, week) in enumerate(starts) {
            if week in pr.week_finished {
                by_week[i] = by_week[i] + pr.week_finished[week];
            }
        }
        tallies.append(
            ProjectTally(
                project_id=pid,
                total=pr.task_total,
                done=pr.done_total,
                blocked=blocked_by_project[pid] if pid in blocked_by_project else 0,
                active=active_by_project[pid] if pid in active_by_project else 0
            )
        );
    }
    people: list[MemberTally] = [];
    for m in members_of(holder) {
        mid = jid(m);
        people.append(
            MemberTally(
                member_id=mid,
                open=open_by_member[mid] if mid in open_by_member else 0,
                done_in_week=done_by_member[mid] if mid in done_by_member else 0
            )
        );
    }
    return TaskTotals(
        open=open_count,
        overdue=overdue_count,
        blocked=blocked_count,
        done_by_week=by_week,
        done_by_day=by_day,
        projects=tallies,
        members=people,
        categories=categories_of(holder)
    );
}


walker TaskCounts {
    """The Overview's numbers over the whole history: open tasks, Done per
    week for the four weeks ending in `monday`'s week (from the weekly
    counts), and total/done per project (from the tallies)."""
    has monday: str = "",
        reports: list[TaskTotals] = [];

    can count with Root entry {
        ensure_tallies(here);
        ensure_history(here);
        report task_totals(
            here,
            open_tasks(here),
            done_since(here, week_of(self.monday)),
            task_names(here),
            self.monday
        );
    }
}


walker TaskHistory {
    """The Overview's charts over time: for the `weeks` weeks ending in
    `monday`'s week, tasks added and moved to Done per week plus running
    scope and done totals. `project_id` narrows it to that project. It reads
    the projects' weekly counts, kept on write; what came before the window
    is the tallies less the window. A task created already Done counts
    nowhere."""
    has project_id: str = "",
        monday: str = "",
        weeks: int = 12,
        reports: list[WeeklyHistory] = [];

    can start with Root entry {
        ensure_tallies(here);
        ensure_history(here);
        if self.project_id {
            p = resolve(self.project_id);
            if isinstance(p, Project) and owned(here, p) {
                visit [p];
            } else {
                report self.history_of([], [0, 0, 0]);
            }
        } else {
            report self.history_of(projects_of(here), tally_totals(here));
        }
    }

    can gather with Project entry {
        report self.history_of(
            [here], [here.task_total, here.done_total, here.seeded_done_total]
        );
        disengage;
    }

    # The window's Mondays, oldest first: the weeks the counts are kept by.
    def starts -> list[str] {
        count = min(max(self.weeks, 4), 52);
        week0 = week_of(self.monday);
        return [shift_day(week0, -7 * (count - 1 - i)) for i in range(count)];
    }

    # `projects` carry the weekly counts, `totals` is the all-time
    # [tasks, done, seeded done] over the same projects.
    def history_of(projects: list[Project], totals: list[int]) -> WeeklyHistory {
        starts = self.starts();
        count = len(starts);
        added = [0 for _ in range(count)];
        finished = [0 for _ in range(count)];
        for p in projects {
            for (i, week) in enumerate(starts) {
                if week in p.week_added {
                    added[i] = added[i] + p.week_added[week];
                }
                if week in p.week_finished {
                    finished[i] = finished[i] + p.week_finished[week];
                }
            }
        }
        # Before the window: everything that ever counted, less the window.
        scope_before = totals[0] - totals[2] - sum(added);
        done_before = totals[1] - totals[2] - sum(finished);
        scope: list[int] = [];
        done: list[int] = [];
        for i in range(count) {
            scope_before = scope_before + added[i];
            done_before = done_before + finished[i];
            scope.append(scope_before);
            done.append(done_before);
        }
        return WeeklyHistory(
            weeks=starts, added=added, finished=finished, scope=scope, done=done
        );
    }
}


walker CreateTask {
    has title: str,
        category: str = "",
        tags: list[str] = [],
        estimate: float = 0.0,
        priority: str = "Medium",
        status: str = "Backlog",
        step_id: str = "",
        due_date: str = "",
        start_date: str = "",
        notes: str = "",
        issue_link: str = "",
        assignee_ids: list[str] = [],
        project_id: str = "",
        reports: list[TaskView] = [];

    # Every task lives under a project. An empty, unknown, foreign or
    # archived project id creates nothing: the walker never leaves the root.
    can start with Root entry {
        if not self.title.strip() {
            disengage;
        }
        p = resolve(self.project_id);
        if isinstance(p, Project) and owned(here, p) and p.active {
            visit [p];
        }
    }

    can create with Project entry {
        holder = root;
        col = self.status if self.status in STATUSES else "Backlog";
        step = "";
        if self.step_id {
            mapped = status_for_step(holder, self.step_id);
            if mapped {
                col = mapped;
                step = self.step_id;
            }
        }
        # A step's entry rule holds from the first write: a new task has no
        # PR, so a step that needs one is never where work starts.
        chosen = resolve(step) if step else None;
        if isinstance(chosen, WorkflowStep) and chosen.refusal(self.due_date, "") {
            disengage;
        }
        # The end of the column: its top card, one bounded query.
        top = (
            step_column_peak(holder, step) if step else status_column_peak(holder, col)
        );
        peak = top[0].sort_order if top else 0.0;
        stamp = now_iso();
        fresh = here ++> Task(
            title=self.title.strip(),
            category=self.category,
            tags=clean_tags(self.tags),
            estimate=self.estimate,
            priority=self.priority,
            status=col,
            step_id=step,
            due_date=self.due_date,
            start_date=iso_day(self.start_date),
            notes=self.notes,
            issue_link=self.issue_link,
            created_at=stamp,
            updated_at=stamp,
            done_at=stamp if col == "Done" else "",
            sort_order=peak + 1024.0,
            project_id=jid(here)
        );
        on_attached(holder, fresh);
        fresh.keep_keys();
        fresh.assignee_ids = link_assignees(holder, fresh, self.assignee_ids);
        count_task(here, fresh, 1);
        note_category(holder, fresh.category);
        record_task_event(holder, fresh, "Added to " + col, stamp);
        report fresh.to_view();
        disengage;
    }
}

# Point the task at exactly these members: the AssignedTo edges and the
# link field together. Unknown or foreign ids are skipped, never invented.
def link_assignees(holder: Root, t: Task, wanted: list[str]) -> list[str] {
    for e in [edge t->:AssignedTo:->] {
        del e;
    }
    linked: list[str] = [];
    for aid in wanted {
        m = resolve(aid);
        if isinstance(m, Member) and owned(holder, m) and aid not in linked {
            t +>:AssignedTo():+> m;
            linked.append(aid);
        }
    }
    return linked;
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
        tags: list[str] = [],
        estimate: float = 0.0,
        priority: str = "",
        status: str = "",
        step_id: str = "",
        due_date: str = "",
        start_date: str = "",
        notes: str = "",
        issue_link: str = "",
        pr_link: str = "",
        reviewer_id: str = "",
        review_due: str = "",
        assignee_ids: list[str] = [],
        project_id: str = "",
        reports: list[TaskView] = [];

    can apply with Task entry {
        # `here` is the task; `root` is the caller's own root.
        holder = root;
        landing = self.status;
        refused = "";
        was_step = here.step_id;
        # A change of step meets the target's entry rule with the due date
        # and PR link this same save writes; a refused step stays put.
        if self.step_id {
            mapped = status_for_step(holder, self.step_id);
            target = resolve(self.step_id);
            if mapped
                and self.step_id != here.step_id
                and isinstance(target, WorkflowStep) {
                refused = target.refusal(self.due_date, self.pr_link.strip());
            }
            if refused {
                landing = here.status;
            } elif mapped {
                landing = mapped;
                here.step_id = self.step_id;
            }
        }
        was = here.status;
        # Two steps can share a kind, so a new step is a move on its own.
        moved = (landing and landing != was) or here.step_id != was_step;
        here.title = self.title;
        was_category = here.category;
        here.category = self.category;
        if self.category != was_category {
            note_category(holder, self.category);
            forget_category(holder, was_category, jid(here));
        }
        here.tags = clean_tags(self.tags);
        here.estimate = self.estimate;
        here.priority = self.priority;
        here.set_status(landing, now_iso());
        here.due_date = self.due_date;
        here.keep_keys();
        here.start_date = iso_day(self.start_date);
        here.notes = self.notes;
        here.issue_link = self.issue_link;
        here.pr_link = self.pr_link;
        here.review_due = self.review_due;
        rev = resolve(self.reviewer_id);
        if isinstance(rev, Member) and owned(holder, rev) {
            here.reviewer_id = self.reviewer_id;
            here.reviewer_name = rev.full_name();
        } else {
            here.reviewer_id = "";
            here.reviewer_name = "";
        }
        here.updated_at = now_iso();
        here.assignee_ids = link_assignees(holder, here, self.assignee_ids);
        # A change of project re-homes the card. An empty, unknown or
        # foreign id leaves it where it is: a task always has a project.
        p = resolve(self.project_id);
        if isinstance(p, Project) and owned(holder, p) {
            current = [here<--[?:Project]];
            if not current or jid(current[0]) != jid(p) {
                rehome_task(here, p);
            }
        }
        if moved {
            now_on = resolve(here.step_id) if here.step_id else None;
            line = "Moved to "
                + (now_on.name if isinstance(now_on, WorkflowStep) else here.status);
            # A move always crosses Done or not; only crossing it writes back.
            if here.status == "Done" or was == "Done" {
                wrote = sync_issue_state(
                    holder, here, here.status == "Done", here.updated_at
                );
                if wrote {
                    line = line + " · " + wrote;
                }
            }
            record_task_event(holder, here, line, here.updated_at);
        }
        view = here.to_view();
        view.refused = refused;
        report view;
        disengage;
    }
}

walker GetTask(find_task) {
    """One task by jid, owner-checked by find_task: the full TaskView, which
    is what the task sheet loads when it opens (a list row carries no notes
    or checklist items), and a deep link to a card the board's working set
    does not hold (older history, a search hit)."""
    has reports: list[TaskView] = [];

    can deliver with Task entry {
        report here.to_view();
        disengage;
    }
}


walker ListTaskTitles {
    """The working set as id and title only, for the assistant's citations:
    the rows and order of ListTasks(scope="working"), at most `limit` (capped
    at 500), with nothing else on the wire."""
    has done_days: int = 7,
        limit: int = 500,
        reports: list[list[TaskTitle]] = [];

    can gather with Root entry {
        ensure_tallies(here);
        (p, size, start, end) = page_bounds(1, self.limit, 500, 500);
        picked = working_tasks(here, done_cutoff(self.done_days));
        picked.sort(key=lambda (t: Task) { jid(t); });
        order_working(picked);
        report [TaskTitle(id=jid(t), title=t.title) for t in picked[:size]];
    }
}

# ---------------------------------------------------------------- checklist

glob CHECKLIST_MAX: int = 50,
     CHECKLIST_TEXT_MAX: int = 200;

# A copy of the stored checklist, so a write assigns a new list (the store
# sees the field change) and a malformed row from any source is dropped.
def checklist_rows(t: Task) -> list[dict[str, any]] {
    rows: list[dict[str, any]] = [];
    for item in t.checklist {
        if isinstance(item, dict) and item.get("id") and item.get("text") {
            rows.append(
                {
                    "id": str(item["id"]),
                    "text": str(item["text"]),
                    "done": bool(item.get("done"))
                }
            );
        }
    }
    return rows;
}


walker AddChecklistItem(find_task) {
    """Append one item to the task's checklist. Blank text or a full list
    (CHECKLIST_MAX) adds nothing; the task view is reported either way."""
    has text: str = "",
        reports: list[TaskView] = [];

    can add with Task entry {
        text = self.text.strip()[:CHECKLIST_TEXT_MAX];
        rows = checklist_rows(here);
        if text and len(rows) < CHECKLIST_MAX {
            rows.append({"id": short_id(), "text": text, "done": False});
            here.checklist = rows;
            here.updated_at = now_iso();
        }
        report here.to_view();
        disengage;
    }
}


walker SetChecklistItem(find_task) {
    """Check, uncheck or rename one item: `done` is "yes", "no" or "" to leave
    it, `text` renames when not blank. Checking an item off writes a log
    line with the progress; nothing else does."""
    has item_id: str = "",
        done: str = "",
        text: str = "",
        reports: list[TaskView] = [];

    can set with Task entry {
        rows = checklist_rows(here);
        checked = "";
        changed = False;
        for item in rows {
            if item["id"] != self.item_id {
                continue;
            }
            fresh = self.text.strip()[:CHECKLIST_TEXT_MAX];
            if fresh and fresh != item["text"] {
                item["text"] = fresh;
                changed = True;
            }
            if self.done == "yes" and not item["done"] {
                item["done"] = True;
                checked = str(item["text"]);
                changed = True;
            } elif self.done == "no" and item["done"] {
                item["done"] = False;
                changed = True;
            }
        }
        if changed {
            here.checklist = rows;
            here.updated_at = now_iso();
            if checked {
                ticked = 0;
                for item in rows {
                    if item["done"] {
                        ticked = ticked + 1;
                    }
                }
                record_task_event(
                    root,
                    here,
                    "Checked off: "
                        + checked
                        + " ("
                        + str(ticked)
                        + "/"
                        + str(len(rows))
                        + ")",
                    here.updated_at
                );
            }
        }
        report here.to_view();
        disengage;
    }
}


walker RemoveChecklistItem(find_task) {
    """Drop one item from the task's checklist; an unknown id removes nothing."""
    has item_id: str = "",
        reports: list[TaskView] = [];

    can remove with Task entry {
        rows = checklist_rows(here);
        kept = [
            item
            for item in rows
            if item["id"] != self.item_id
        ];
        if len(kept) != len(rows) {
            here.checklist = kept;
            here.updated_at = now_iso();
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
        holder = root;
        rev = resolve(self.reviewer_id);
        if isinstance(rev, Member) and owned(holder, rev) {
            here.reviewer_id = self.reviewer_id;
            here.reviewer_name = rev.full_name();
        }
        if self.review_due {
            here.review_due = self.review_due;
        }
        if self.pr_link.strip() {
            here.pr_link = self.pr_link.strip();
        }
        if self.note.strip() {
            # Prepend, never replace: notes is the task's description (or an
            # imported issue body). Newest-first keeps the blocked card's
            # excerpt leading with the reason. Same-line resubmits are no-ops.
            line = "**" + now_iso()[:10] + ":** " + self.note.strip();
            if not here.notes.startswith(line) {
                here.notes = line + ("\n\n" + here.notes if here.notes else "");
            }
        }
        here.updated_at = now_iso();
        sync_task_links(holder, here, self.note.strip());
        report here.to_view();
        disengage;
    }
}

walker MoveTask(find_task) {
    """The drag-drop / arrow-move endpoint. Server-authoritative: a move
    appends to the end of the target column, unless `before_id`/`after_id`
    asks for the spot beside that card there (a stale anchor appends). A
    positioned drop in the card's own column is a pure reorder: no status
    write, no hand-off, no log row, no updated_at bump. `step_id` is the
    flow line column and its mapped status is written too; without it, the
    legacy status-only move."""
    has status: str = "",
        step_id: str = "",
        step_name: str = "",
        before_id: str = "",
        after_id: str = "",
        reports: list[TaskView] = [];

    can move with Task entry {
        # `here` is the task; `root` is the caller's own root.
        holder = root;
        landing = self.status;
        label = self.status;
        # Read before step_id is rewritten below: a positioned drop in the
        # card's own column stays a reorder for the writes further down.
        positioned = bool(self.before_id or self.after_id);
        was_step = here.step_id;
        reorder = False;
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
            reorder = positioned and self.step_id == here.step_id;
            # Only a CHANGE of step is a hand-off, and only a change meets
            # the step's entry rule. Re-dropping a card in its own column (a
            # reorder) must not reassign it.
            if self.step_id != here.step_id {
                step = resolve(self.step_id);
                if isinstance(step, WorkflowStep) {
                    refused = step.refusal(here.due_date, here.pr_link);
                    if refused {
                        view = here.to_view();
                        view.refused = refused;
                        report view;
                        disengage;
                    }
                    handed = handoff_target(holder, here, step);
                }
            }
            here.step_id = self.step_id;
            label = self.step_name or mapped;
        } else {
            reorder = positioned and not here.step_id and landing == here.status;
            # A status-only move (the assistant, a merged PR, an org with no
            # flow line) must drop whatever step the task was on, or the board
            # keeps drawing it in the old column while the status says
            # otherwise.
            here.step_id = "";
        }
        was = here.status;
        here.set_status(landing, now_iso());
        here.sort_order = self.landing_sort(holder, here, landing);
        if not reorder {
            here.updated_at = now_iso();
        }
        # A hand-off replaces the assignees: the card changes hands, it does
        # not gain a hand. The tail names who it went to and any write-back
        # a move across Done made, on the move's own log line.
        tail = landing_tail(holder, here, handed, was);
        if landing != was or tail or here.step_id != was_step {
            record_task_event(
                holder, here, "Moved to " + label + tail, here.updated_at
            );
        }
        report here.to_view();
        disengage;
    }

    # The landing sort: the midpoint beside a valid anchor, the end of the
    # column otherwise. Each read is one bounded query on the landing
    # column; only two neighbours too close for a float midpoint load the
    # whole column, to re-spread it at 1024 with the card in its slot.
    def landing_sort(holder: Root, moving: Task, landing: str) -> float {
        anchor_id = self.before_id or self.after_id;
        anchor = resolve(anchor_id) if anchor_id else None;
        if isinstance(anchor, Task)
            and jid(anchor) != jid(moving)
            and owned(holder, anchor)
            and self.in_column(anchor, landing) {
            ahead = bool(self.before_id);
            if ahead {
                hi = anchor.sort_order;
                below = self.others(self.column_below(holder, landing, hi), moving);
                lo = below[0].sort_order if below else hi - 2048.0;
            } else {
                lo = anchor.sort_order;
                above = self.others(self.column_above(holder, landing, lo), moving);
                hi = above[0].sort_order if above else lo + 2048.0;
            }
            mid = (lo + hi) / 2.0;
            if mid > lo and mid < hi {
                return mid;
            }
            col = self.others(self.column_all(holder, landing), moving);
            col.sort(key=lambda (t: Task) { jid(t); });
            col.sort(key=lambda (t: Task) { t.sort_order; });
            slot = len(col);
            for (i, t) in enumerate(col) {
                if jid(t) == jid(anchor) {
                    slot = i;
                }
            }
            at = slot if ahead else slot + 1;
            spread = col[0:at] + [moving] + col[at:];
            n = 0.0;
            out = 0.0;
            for t in spread {
                n = n + 1024.0;
                t.sort_order = n;
                if jid(t) == jid(moving) {
                    out = n;
                }
            }
            return out;
        }
        top = self.others(self.column_peak(holder, landing), moving);
        peak = top[0].sort_order if top else 0.0;
        return peak + 1024.0;
    }

    # The landing column is the step when the move names one, else the
    # legacy column: the status with no step.
    def in_column(t: Task, landing: str) -> bool {
        if self.step_id {
            return t.step_id == self.step_id;
        }
        return t.status == landing and not t.step_id;
    }

    def column_peak(holder: Root, landing: str) -> list[Task] {
        if self.step_id {
            return step_column_peak(holder, self.step_id);
        }
        return status_column_peak(holder, landing);
    }

    def column_below(holder: Root, landing: str, bound: float) -> list[Task] {
        if self.step_id {
            return step_column_below(holder, self.step_id, bound);
        }
        return status_column_below(holder, landing, bound);
    }

    def column_above(holder: Root, landing: str, bound: float) -> list[Task] {
        if self.step_id {
            return step_column_above(holder, self.step_id, bound);
        }
        return status_column_above(holder, landing, bound);
    }

    def column_all(holder: Root, landing: str) -> list[Task] {
        if self.step_id {
            return step_column(holder, self.step_id);
        }
        return status_column(holder, landing);
    }

    # The rows without the moving card, whichever column it came from.
    def others(rows: list[Task], moving: Task) -> list[Task] {
        return [
            t
            for t in rows
            if jid(t) != jid(moving)
        ];
    }
}

walker DeleteTask(find_task) {
    can remove with Task entry {
        gone = jid(here);
        for p in task_project(here) {
            count_task(p, here, -1);
        }
        forget_category(root, here.category, gone);
        del here;
        report {"deleted": gone};
        disengage;
    }
}
