"""Deterministic workspace insights: the Snapshot every assistant answer is
built on, exact answers for the Overview, no LLM here. NEVER nest `root spawn`
in this module: a nested walker's reports come back EMPTY and leak into the
outer walker (jac 0.35.1). Everything traverses `[root-->]` directly."""

import from models {
    Project,
    Member,
    Task,
    LogDay,
    LogEntry,
    TaskRow,
    TaskTotals,
    LogTotals,
    MemberView,
    TaskNames,
    member_view,
    member_roles,
    task_names,
    rows_from,
    open_tasks,
    done_since,
    projects_of,
    members_of,
    days_between,
    blocked_lines
}
import from services.util { now_iso, done_day, moved_to_done, ensure_tallies }
import from services.tasks.tasks {
    task_totals,
    tally_since,
    needs_attention,
    order_attention
}
import from services.log.log { log_totals }

glob ACTIVE_STATUSES: list[str] = ["In Progress", "Review", "Changes Requested"],
     STALE_AFTER_DAYS: int = 7;

# ------------------------------------------------------------------ view objs

obj BlockedItem {
    has task_id: str,
        title: str,
        project: str,
        assignees: str,
        reason: str,
        since: str;
}

obj ReviewItem {
    has task_id: str,
        title: str,
        project: str,
        reviewer: str,
        review_due: str,
        pr_link: str,
        waiting_days: int;
}

obj AgingItem {
    has task_id: str,
        title: str,
        project: str,
        status: str,
        assignees: str,
        idle_days: int;
}

obj OverdueItem {
    has title: str,
        project: str,
        assignees: str,
        due_date: str,
        status: str;
}

obj PersonStat {
    has name: str,
        roles: str,
        tags: str,
        open_tasks: int,
        done_in_period: int,
        log_entries: int,
        blocked: int;
}

obj ProjectStat {
    has name: str,
        total: int,
        done: int,
        active: int,
        blocked: int;
}

obj ActivityLine {
    has date: str,
        who: str,
        what: str,
        task: str,
        project: str;
}

obj Snapshot {
    """Everything the assistant is allowed to know, in one prompt-sized object."""
    has generated_at: str,
        period_from: str,
        period_to: str,
        org_members: int,
        active_projects: int,
        open_tasks: int,
        done_in_period: int,
        log_entries_in_period: int,
        blocked: list[BlockedItem],
        review_queue: list[ReviewItem],
        aging: list[AgingItem],
        overdue: list[OverdueItem],
        people: list[PersonStat],
        projects: list[ProjectStat],
        activity: list[ActivityLine];
}

# --------------------------------------------------------------- date helpers

# ISO dates are lexicographically ordered, so plain string compares work for
# range checks. Day arithmetic goes through the ordinal below.
def _days_between(earlier: str, later: str) -> int {
    if len(earlier) < 10 or len(later) < 10 {
        return 0;
    }
    gap = _ordinal(later) - _ordinal(earlier);
    return gap if gap > 0 else 0;
}

# Rough day ordinal from an ISO date. Only ever used for differences within a
# few months, where month-length drift does not change the story.
def _ordinal(iso: str) -> int {
    y = int(iso[0:4]);
    m = int(iso[5:7]);
    d = int(iso[8:10]);
    return y * 365 + m * 31 + d;
}

def _today -> str {
    return now_iso()[:10];
}

# ------------------------------------------------------------- gathering defs
# Each takes the caller's root and traverses it directly. No walker spawns.
# Every queue here is open work, so the readers load the open tasks and the
# Done tasks of the period; the all-time totals come from the tallies.

def _entries_between(holder: Root, from_date: str, to_date: str) -> list[LogEntry] {
    rows: list[LogEntry] = [];
    for day in days_between(holder, from_date, to_date) {
        for row in [day-->[?:LogEntry]] {
            rows.append(row);
        }
    }
    rows.sort(key=lambda (r: LogEntry) { r.at or r.date; });
    return rows;
}

# The reason a task is blocked lives on the log row that recorded the move, not
# on Task.notes (which the handoff dialog may leave untouched).
def _blocked_reason(entries: list[LogEntry], task_id: str) -> tuple[str, str] {
    reason = "";
    since = "";
    for row in entries {
        if row.task_id == task_id and row.status == "Blocked" {
            reason = row.notes;
            since = row.at or row.date;
        }
    }
    return (reason, since);
}

# Each blocked task's reason and since, from log rows already loaded.
def _reasons_from(
    entries: list[LogEntry], open: list[Task]
) -> dict[str, tuple[str, str]] {
    out: dict[str, tuple[str, str]] = {};
    for t in open {
        if t.status == "Blocked" {
            out[jid(t)] = _blocked_reason(entries, jid(t));
        }
    }
    return out;
}

# The same from the store: one query per blocked task for its Blocked lines
# in [since, until], the latest stamp winning. No blocked task, no read.
def _reasons_between(
    holder: Root, open: list[Task], since: str, until: str
) -> dict[str, tuple[str, str]] {
    out: dict[str, tuple[str, str]] = {};
    for t in open {
        if t.status != "Blocked" {
            continue;
        }
        reason = "";
        when = "";
        for row in blocked_lines(holder, jid(t), since, until) {
            stamp = row.at or row.date;
            if stamp >= when {
                reason = row.notes;
                when = stamp;
            }
        }
        out[jid(t)] = (reason, when);
    }
    return out;
}

# ------------------------------------------------------------------- assembly

# The three queues the Overview and the assistant both read. Each takes the
# open tasks and the names already gathered, so callers read the graph once.
# Blocked rows come out in the attention order (soonest due first, ties by
# jid) so a capped list still covers the attention list's blocked prefix.
def _blocked_items(
    open: list[Task], names: TaskNames, reasons: dict[str, tuple[str, str]]
) -> list[BlockedItem] {
    stuck = [
        t
        for t in open
        if t.status == "Blocked"
    ];
    stuck.sort(key=lambda (t: Task) { jid(t); });
    order_attention(stuck);
    rows: list[BlockedItem] = [];
    for t in stuck {
        (reason, since) = reasons[jid(t)] if jid(t) in reasons else ("", "");
        rows.append(
            BlockedItem(
                task_id=jid(t),
                title=t.title,
                project=names.project_of(t),
                assignees=names.named(t),
                reason=reason or t.notes,
                since=since[:10] if since else t.updated_at[:10]
            )
        );
    }
    return rows;
}


# Longest-waiting first; negative key because .sort takes no reverse here.
def _review_items(open: list[Task], names: TaskNames, today: str) -> list[ReviewItem] {
    rows: list[ReviewItem] = [];
    for t in open {
        if t.status != "Review" {
            continue;
        }
        rows.append(
            ReviewItem(
                task_id=jid(t),
                title=t.title,
                project=names.project_of(t),
                reviewer=t.reviewer_name,
                review_due=t.review_due,
                pr_link=t.pr_link,
                waiting_days=_days_between(t.updated_at[:10], today)
            )
        );
    }
    rows.sort(key=lambda (r: ReviewItem) { -r.waiting_days; });
    return rows;
}


# Open tasks untouched for STALE_AFTER_DAYS, longest-idle first.
def _aging_items(open: list[Task], names: TaskNames, today: str) -> list[AgingItem] {
    rows: list[AgingItem] = [];
    for t in open {
        idle = _days_between(t.updated_at[:10], today);
        if idle >= STALE_AFTER_DAYS {
            rows.append(
                AgingItem(
                    task_id=jid(t),
                    title=t.title,
                    project=names.project_of(t),
                    status=t.status,
                    assignees=names.named(t),
                    idle_days=idle
                )
            );
        }
    }
    rows.sort(key=lambda (a: AgingItem) { -a.idle_days; });
    return rows;
}


# Open tasks already past their due date. Assistant-only: the Overview shows
# the overdue count from task_totals, not the list.
def _overdue_items(
    open: list[Task], names: TaskNames, today: str
) -> list[OverdueItem] {
    rows: list[OverdueItem] = [];
    for t in open {
        if not (t.due_date and t.due_date < today) {
            continue;
        }
        rows.append(
            OverdueItem(
                title=t.title,
                project=names.project_of(t),
                assignees=names.named(t),
                due_date=t.due_date,
                status=t.status
            )
        );
    }
    return rows;
}


# Gather the whole workspace into one object. Root-scoped; the only write
# is the one-off tally fill.
def build_snapshot(holder: Root, from_date: str, to_date: str) -> Snapshot {
    ensure_tallies(holder);
    today = _today();
    open = open_tasks(holder);
    done_period = [
        t
        for t in done_since(holder, from_date)
        if moved_to_done(t) and done_day(t) >= from_date
    ];
    members = [
        m
        for m in members_of(holder)
        if m.active
    ];
    projects = [
        p
        for p in projects_of(holder)
        if p.active
    ];
    entries = _entries_between(holder, from_date, to_date);
    names = task_names(holder);

    blocked = _blocked_items(open, names, _reasons_from(entries, open));
    review_queue = _review_items(open, names, today);
    aging = _aging_items(open, names, today);
    overdue = _overdue_items(open, names, today);

    people: list[PersonStat] = [];
    for m in members {
        shown = m.full_name();
        mid = jid(m);
        mine_open = [
            t
            for t in open
            if mid in t.assignee_ids
        ];
        people.append(
            PersonStat(
                name=shown,
                roles=", ".join(member_roles(m)),
                tags=", ".join(m.tags),
                open_tasks=len(mine_open),
                done_in_period=len(
                    [
                        t
                        for t in done_period
                        if mid in t.assignee_ids
                    ]
                ),
                log_entries=len(
                    [
                        e
                        for e in entries
                        if shown in e.member_name
                    ]
                ),
                blocked=len(
                    [
                        t
                        for t in mine_open
                        if t.status == "Blocked"
                    ]
                )
            )
        );
    }

    project_stats: list[ProjectStat] = [];
    for p in projects {
        pid = jid(p);
        mine = [
            t
            for t in open
            if t.project_id == pid
        ];
        project_stats.append(
            ProjectStat(
                name=p.name,
                total=p.task_total,
                done=p.done_total,
                active=len(
                    [
                        t
                        for t in mine
                        if t.status in ACTIVE_STATUSES
                    ]
                ),
                blocked=len(
                    [
                        t
                        for t in mine
                        if t.status == "Blocked"
                    ]
                )
            )
        );
    }

    activity: list[ActivityLine] = [];
    for e in entries {
        activity.append(
            ActivityLine(
                date=e.date,
                who=e.member_name,
                what=e.activity,
                task=e.task_title,
                project=e.project_name
            )
        );
    }

    return Snapshot(
        generated_at=now_iso(),
        period_from=from_date,
        period_to=to_date,
        org_members=len(members),
        active_projects=len(projects),
        open_tasks=len(open),
        done_in_period=len(done_period),
        log_entries_in_period=len(entries),
        blocked=blocked,
        review_queue=review_queue,
        aging=aging,
        overdue=overdue,
        people=people,
        projects=project_stats,
        activity=activity
    );
}

# --------------------------------------------------------------------- walker

obj OverviewData {
    """Exactly what the Overview renders. The three queues are the only
    Snapshot slices the page uses; the rest of a Digest is assistant-only."""
    has counts: TaskTotals,
        logs: LogTotals,
        attention: list[TaskRow],
        attention_total: int,
        members: list[MemberView],
        projects: list[Project],
        review_queue: list[ReviewItem],
        aging: list[AgingItem],
        blocked: list[BlockedItem];
}


walker OverviewSnapshot {
    """The whole Overview in one call. The open tasks and the four weeks of
    Done are read once and every panel is computed from that, so the page
    costs one round trip and never loads the history. The three queues
    are capped at `attention_size`, in their own order."""
    has monday: str = "",
        from_date: str = "",
        attention_size: int = 8,
        reports: list[OverviewData] = [];

    can build with Root entry {
        ensure_tallies(here);
        today = _today();
        open = open_tasks(here);
        recent = done_since(here, tally_since(self.monday));
        names = task_names(here);
        flagged = [
            t
            for t in open
            if needs_attention(t, today)
        ];
        # Same tiebreak as ListTasks: sorts are stable, so the jid pass
        # underneath the real key keeps paging deterministic.
        flagged.sort(key=lambda (t: Task) { jid(t); });
        order_attention(flagged);
        members: list[MemberView] = [];
        for m in members_of(here) {
            members.append(member_view(m));
        }
        members.sort(key=lambda (m: MemberView) { m.name; });
        projects = projects_of(here);
        projects.sort(key=lambda (p: Project) { p.name; });
        cap = self.attention_size;
        report OverviewData(
            counts=task_totals(here, open, recent, names, self.monday),
            logs=log_totals(here, self.monday),
            attention=rows_from(names, flagged[:cap]),
            attention_total=len(flagged),
            members=members,
            projects=projects,
            review_queue=_review_items(open, names, today)[:cap],
            aging=_aging_items(open, names, today)[:cap],
            blocked=_blocked_items(
                open,
                names,
                _reasons_between(here, open, self.from_date or today, today)
            )[:cap]
        );
    }
}


walker Digest {
    """The workspace snapshot. Bare (JWT-required) like every walker here: a
    :pub walker would run anonymous callers on the shared guest graph."""
    has from_date: str = "",
        to_date: str = "",
        reports: list[Snapshot] = [];

    can build with Root entry {
        today = _today();
        start = self.from_date or today;
        end = self.to_date or today;
        report build_snapshot(here, start, end);
    }
}
