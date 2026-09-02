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
    TaskView,
    TaskTotals,
    LogTotals,
    MemberView,
    TaskLinks,
    AssignedTo,
    ForProject,
    Logged,
    member_view,
    task_links,
    views_from
}
import from walkers.util { now_iso }
import from walkers.tasks { task_totals, needs_attention, order_attention }
import from walkers.log { log_totals }

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

def _tasks_of(holder: Root) -> list[Task] {
    return [holder-->[?:Task]];
}


def _entries_between(holder: Root, from_date: str, to_date: str) -> list[LogEntry] {
    rows: list[LogEntry] = [];
    for day in [holder-->[?:LogDay, date>=from_date, date<=to_date]] {
        for row in [day->:Logged:->] {
            rows.append(row);
        }
    }
    rows.sort(key=lambda (r: LogEntry) { r.at or r.date; });
    return rows;
}

# The reason a task is blocked lives on the log row that recorded the move, not
# on Task.notes (which the handoff dialog may leave untouched).
def _blocked_reason(entries: list[LogEntry], task_id: str) -> tuple {
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

# ------------------------------------------------------------------- assembly

# The three queues the Overview and the assistant both read. Each takes tasks
# and links already gathered, so callers traverse the graph once.
def _blocked_items(
    tasks: list[Task], links: TaskLinks, entries: list[LogEntry]
) -> list[BlockedItem] {
    rows: list[BlockedItem] = [];
    for t in tasks {
        if t.status != "Blocked" {
            continue;
        }
        (reason, since) = _blocked_reason(entries, jid(t));
        rows.append(
            BlockedItem(
                task_id=jid(t),
                title=t.title,
                project=links.project_of(jid(t)),
                assignees=links.named(jid(t)),
                reason=reason or t.notes,
                since=since[:10] if since else t.updated_at[:10]
            )
        );
    }
    return rows;
}


# Longest-waiting first; negative key because .sort takes no reverse here.
def _review_items(tasks: list[Task], links: TaskLinks, today: str) -> list[ReviewItem] {
    rows: list[ReviewItem] = [];
    for t in tasks {
        if t.status != "Review" {
            continue;
        }
        rows.append(
            ReviewItem(
                task_id=jid(t),
                title=t.title,
                project=links.project_of(jid(t)),
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
def _aging_items(tasks: list[Task], links: TaskLinks, today: str) -> list[AgingItem] {
    rows: list[AgingItem] = [];
    for t in tasks {
        if t.status == "Done" {
            continue;
        }
        idle = _days_between(t.updated_at[:10], today);
        if idle >= STALE_AFTER_DAYS {
            rows.append(
                AgingItem(
                    task_id=jid(t),
                    title=t.title,
                    project=links.project_of(jid(t)),
                    status=t.status,
                    assignees=links.named(jid(t)),
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
    tasks: list[Task], links: TaskLinks, today: str
) -> list[OverdueItem] {
    rows: list[OverdueItem] = [];
    for t in tasks {
        if t.status == "Done" or not (t.due_date and t.due_date < today) {
            continue;
        }
        rows.append(
            OverdueItem(
                title=t.title,
                project=links.project_of(jid(t)),
                assignees=links.named(jid(t)),
                due_date=t.due_date,
                status=t.status
            )
        );
    }
    return rows;
}


# Gather the whole workspace into one object. Reads only, root-scoped.
def build_snapshot(holder: Root, from_date: str, to_date: str) -> Snapshot {
    today = _today();
    tasks = _tasks_of(holder);
    members = [
        m
        for m in [holder-->[?:Member]]
        if m.active
    ];
    projects = [
        p
        for p in [holder-->[?:Project]]
        if p.active
    ];
    entries = _entries_between(holder, from_date, to_date);
    links = task_links(holder);

    open_tasks = [
        t
        for t in tasks
        if t.status != "Done"
    ];
    done_period = [
        t
        for t in tasks
        if t.status == "Done" and t.updated_at[:10] >= from_date
    ];

    blocked = _blocked_items(tasks, links, entries);
    review_queue = _review_items(tasks, links, today);
    aging = _aging_items(tasks, links, today);
    overdue = _overdue_items(tasks, links, today);

    people: list[PersonStat] = [];
    for m in members {
        mine = [
            t
            for t in tasks
            if m.name in links.named(jid(t))
        ];
        people.append(
            PersonStat(
                name=m.name,
                roles=", ".join(m.roles),
                tags=", ".join(m.tags),
                open_tasks=len(
                    [
                        t
                        for t in mine
                        if t.status != "Done"
                    ]
                ),
                done_in_period=len(
                    [
                        t
                        for t in mine
                        if t.status == "Done" and t.updated_at[:10] >= from_date
                    ]
                ),
                log_entries=len(
                    [
                        e
                        for e in entries
                        if m.name in e.member_name
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

    project_stats: list[ProjectStat] = [];
    for p in projects {
        owned_tasks = [
            t
            for t in tasks
            if links.project_of(jid(t)) == p.name
        ];
        project_stats.append(
            ProjectStat(
                name=p.name,
                total=len(owned_tasks),
                done=len(
                    [
                        t
                        for t in owned_tasks
                        if t.status == "Done"
                    ]
                ),
                active=len(
                    [
                        t
                        for t in owned_tasks
                        if t.status in ACTIVE_STATUSES
                    ]
                ),
                blocked=len(
                    [
                        t
                        for t in owned_tasks
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
        open_tasks=len(open_tasks),
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
        attention: list[TaskView],
        attention_total: int,
        members: list[MemberView],
        projects: list[Project],
        review_queue: list[ReviewItem],
        aging: list[AgingItem],
        blocked: list[BlockedItem];
}


walker OverviewSnapshot {
    """The whole Overview in one call. Tasks, members and projects are walked
    once and every panel is computed from that, so the page costs one round
    trip and one traversal instead of six and three."""
    has monday: str = "",
        from_date: str = "",
        attention_size: int = 8,
        reports: list[OverviewData] = [];

    can build with Root entry {
        today = _today();
        tasks = _tasks_of(here);
        links = task_links(here);
        entries = _entries_between(here, self.from_date or today, today);
        flagged = [
            t
            for t in tasks
            if needs_attention(t, today)
        ];
        # Same tiebreak as ListTasks: sorts are stable, so the jid pass
        # underneath the real key keeps paging deterministic.
        flagged.sort(key=lambda (t: Task) { jid(t); });
        order_attention(flagged);
        members: list[MemberView] = [];
        for m in [here-->[?:Member]] {
            members.append(member_view(m));
        }
        members.sort(key=lambda (m: MemberView) { m.name; });
        projects = [here-->[?:Project]];
        projects.sort(key=lambda (p: Project) { p.name; });
        report OverviewData(
            counts=task_totals(here, tasks, links, self.monday),
            logs=log_totals(here, self.monday),
            attention=views_from(links, flagged[:self.attention_size]),
            attention_total=len(flagged),
            members=members,
            projects=projects,
            review_queue=_review_items(tasks, links, today),
            aging=_aging_items(tasks, links, today),
            blocked=_blocked_items(tasks, links, entries)
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
