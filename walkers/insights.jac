"""Deterministic workspace insights: the Snapshot every assistant answer is built on.

No LLM lives here on purpose. This module is three things at once:
  (a) the context builder for every byLLM call in ai/assistant.jac,
  (b) exact answers to half the questions people would otherwise ask the bot,
  (c) a server-side source for the Overview page, which recomputes in the browser today.

NEVER nest `root spawn` in this module. A nested walker's `.reports` comes back EMPTY
and its rows leak into the outer walker's reports (jac 0.34.6 `_sv_on_complete` merges
into the outer frame and returns early). Everything here traverses `[root-->]` directly.
"""

import from models {
    Project, Member, Task, LogDay, LogEntry,
    AssignedTo, ForProject, Logged
}
import from walkers.util { now_iso }

glob ACTIVE_STATUSES: list[str] = ["In Progress", "Review", "Changes Requested"];
glob STALE_AFTER_DAYS: int = 7;

# ------------------------------------------------------------------ view objs

obj BlockedItem {
    has title: str,
        project: str,
        assignees: str,
        reason: str,
        since: str;
}

obj ReviewItem {
    has title: str,
        project: str,
        reviewer: str,
        review_due: str,
        pr_link: str,
        waiting_days: int;
}

obj AgingItem {
    has title: str,
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

def _assignee_names(t: Task) -> str {
    names: list[str] = [];
    for a in [t ->:AssignedTo:->] {
        names.append(a.name);
    }
    return ", ".join(names);
}

def _project_name(t: Task) -> str {
    for p in [t ->:ForProject:->] {
        return p.name;
    }
    return "";
}

def _entries_between(holder: Root, from_date: str, to_date: str) -> list[LogEntry] {
    rows: list[LogEntry] = [];
    for day in [holder-->[?:LogDay, date >= from_date, date <= to_date]] {
        for row in [day ->:Logged:->] {
            rows.append(row);
        }
    }
    rows.sort(key=lambda (r: LogEntry) { r.at if r.at else r.date; });
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
            since = row.at if row.at else row.date;
        }
    }
    return (reason, since);
}

# ------------------------------------------------------------------- assembly

# Gather the whole workspace into one object. Reads only, root-scoped.
def build_snapshot(holder: Root, from_date: str, to_date: str) -> Snapshot {
    today = _today();
    tasks = _tasks_of(holder);
    members = [m for m in [holder-->[?:Member]] if m.active];
    projects = [p for p in [holder-->[?:Project]] if p.active];
    entries = _entries_between(holder, from_date, to_date);

    open_tasks = [t for t in tasks if t.status != "Done"];
    done_period = [
        t for t in tasks
        if t.status == "Done" and t.updated_at[:10] >= from_date
    ];

    blocked: list[BlockedItem] = [];
    for t in tasks {
        if t.status == "Blocked" {
            (reason, since) = _blocked_reason(entries, jid(t));
            blocked.append(BlockedItem(
                title=t.title, project=_project_name(t),
                assignees=_assignee_names(t),
                reason=reason if reason else t.notes,
                since=since[:10] if since else t.updated_at[:10]
            ));
        }
    }

    review_queue: list[ReviewItem] = [];
    for t in tasks {
        if t.status == "Review" {
            review_queue.append(ReviewItem(
                title=t.title, project=_project_name(t),
                reviewer=t.reviewer_name, review_due=t.review_due,
                pr_link=t.pr_link,
                waiting_days=_days_between(t.updated_at[:10], today)
            ));
        }
    }

    aging: list[AgingItem] = [];
    overdue: list[OverdueItem] = [];
    for t in tasks {
        if t.status == "Done" {
            continue;
        }
        idle = _days_between(t.updated_at[:10], today);
        if idle >= STALE_AFTER_DAYS {
            aging.append(AgingItem(
                title=t.title, project=_project_name(t), status=t.status,
                assignees=_assignee_names(t), idle_days=idle
            ));
        }
        if t.due_date and t.due_date < today {
            overdue.append(OverdueItem(
                title=t.title, project=_project_name(t),
                assignees=_assignee_names(t), due_date=t.due_date,
                status=t.status
            ));
        }
    }

    people: list[PersonStat] = [];
    for m in members {
        mine = [t for t in tasks if m.name in _assignee_names(t)];
        people.append(PersonStat(
            name=m.name, roles=", ".join(m.roles), tags=", ".join(m.tags),
            open_tasks=len([t for t in mine if t.status != "Done"]),
            done_in_period=len([
                t for t in mine
                if t.status == "Done" and t.updated_at[:10] >= from_date
            ]),
            log_entries=len([e for e in entries if m.name in e.member_name]),
            blocked=len([t for t in mine if t.status == "Blocked"])
        ));
    }

    project_stats: list[ProjectStat] = [];
    for p in projects {
        owned_tasks = [t for t in tasks if _project_name(t) == p.name];
        project_stats.append(ProjectStat(
            name=p.name, total=len(owned_tasks),
            done=len([t for t in owned_tasks if t.status == "Done"]),
            active=len([t for t in owned_tasks if t.status in ACTIVE_STATUSES]),
            blocked=len([t for t in owned_tasks if t.status == "Blocked"])
        ));
    }

    activity: list[ActivityLine] = [];
    for e in entries {
        activity.append(ActivityLine(
            date=e.date, who=e.member_name, what=e.activity,
            task=e.task_title, project=e.project_name
        ));
    }

    return Snapshot(
        generated_at=now_iso(), period_from=from_date, period_to=to_date,
        org_members=len(members), active_projects=len(projects),
        open_tasks=len(open_tasks), done_in_period=len(done_period),
        log_entries_in_period=len(entries),
        blocked=blocked, review_queue=review_queue, aging=aging,
        overdue=overdue, people=people, projects=project_stats,
        activity=activity
    );
}

# --------------------------------------------------------------------- walker

walker Digest {
    """The workspace snapshot. Bare (JWT-required) like every walker here: a
    :pub walker would run anonymous callers on the shared guest graph."""
    has from_date: str = "",
        to_date: str = "",
        reports: list[Snapshot] = [];

    can build with Root entry {
        today = _today();
        start = self.from_date if self.from_date else today;
        end = self.to_date if self.to_date else today;
        report build_snapshot(here, start, end);
    }
}
