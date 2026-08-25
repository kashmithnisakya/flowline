"""Daily-log walkers: day buckets and their entries."""

import from models {
    Project,
    Member,
    Task,
    LogDay,
    LogEntry,
    LogPage,
    LogTotals,
    MemberDays,
    Logged,
    By,
    AssignedTo,
    ForProject,
    resolve,
    on_attached,
    owned
}
import from walkers.util {
    today_iso,
    shift_day,
    page_bounds,
    caller_level,
    level_rank,
    attach_stamp
}

# ---------------------------------------------------------------- daily log

walker ListLogEntries {
    """One page of entries whose LogDay date falls in [from_date, to_date],
    ISO strings, newest day first. `total` counts the whole range so a page
    can say how much of the week it is."""
    has from_date: str,
        to_date: str,
        page: int = 1,
        page_size: int = 0,
        reports: list[LogPage] = [];

    can gather with Root entry {
        (p, size, start, end) = page_bounds(self.page, self.page_size, 200, 500);
        found: list[LogEntry] = [];
        for day in [here-->[?:LogDay, date>=self.from_date, date<=self.to_date]] {
            for row in [day->:Logged:->] {
                found.append(row);
            }
        }
        # Newest day first so page 1 is the end of the week; the jid pass
        # underneath keeps rows that tie on day and name in one order
        # across pages (sorts are stable).
        found.sort(key=lambda (r: LogEntry) { jid(r); });
        found.sort(key=lambda (r: LogEntry) { r.member_name; });
        found.sort(key=lambda (r: LogEntry) { r.date; }, reverse=True);
        report LogPage(
            rows=found[start:end],
            page=p,
            page_size=size,
            has_more=len(found) > end,
            total=len(found)
        );
    }
}

walker LogCounts {
    """The Overview's log numbers: entries per week for the four weeks ending
    in `monday`'s week (oldest first), per weekday of that week, and which
    days each person logged on. Reads node fields only, so a week with two
    thousand rows costs the same as one with twenty."""
    has monday: str = "",
        reports: list[LogTotals] = [];

    can count with Root entry {
        week0 = self.monday if len(self.monday) >= 10 else today_iso();
        starts = [shift_day(week0, -7 * (3 - i)) for i in range(4)];
        since = starts[0];
        until = shift_day(week0, 6);
        week_days = [shift_day(week0, i) for i in range(7)];
        # Week bounds up front, for the same reason as TaskCounts.
        ends = [shift_day(starts[i], 7) for i in range(4)];
        by_week = [0, 0, 0, 0];
        by_day = [0, 0, 0, 0, 0, 0, 0];
        per_person: dict[str, list[int]] = {};
        for day in [here-->[?:LogDay, date>=since, date<=until]] {
            for row in [day->:Logged:->] {
                for i in range(4) {
                    if row.date >= starts[i] and row.date < ends[i] {
                        by_week[i] = by_week[i] + 1;
                    }
                }
                if row.date < week0 {
                    continue;
                }
                slot = -1;
                for i in range(7) {
                    if row.date == week_days[i] {
                        slot = i;
                    }
                }
                if slot < 0 {
                    continue;
                }
                by_day[slot] = by_day[slot] + 1;
                for who in row.member_name.split(",") {
                    name = who.strip();
                    if not name {
                        continue;
                    }
                    if name not in per_person {
                        per_person[name] = [0, 0, 0, 0, 0, 0, 0];
                    }
                    per_person[name][slot] = per_person[name][slot] + 1;
                }
            }
        }
        people: list[MemberDays] = [];
        for name in per_person {
            counts = per_person[name];
            people.append(MemberDays(name=name, by_day=counts, total=sum(counts)));
        }
        report LogTotals(by_week=by_week, by_day=by_day, members=people);
    }
}

walker LogActivity {
    """Get-or-create the day bucket under the caller's root, then append one
    denormalized row. Refuses writes no view could fetch (empty date) or
    that would produce a blank authorless row (bad member jid)."""
    has date: str,
        member_id: str,
        activity: str,
        project_id: str = "",
        category: str = "",
        repo: str = "",
        issue_link: str = "",
        pr_link: str = "",
        status: str = "",
        notes: str = "",
        reports: list[LogEntry] = [];

    can start with Root entry {
        # Org members below editor cannot write the log; silent no-op like
        # every other unauthorized mutation.
        if level_rank(caller_level(here, jid(root))) < 2 {
            disengage;
        }
        if not self.date {
            disengage;
        }
        probe = resolve(self.member_id);
        if not isinstance(probe, Member) or not owned(here, probe) {
            disengage;
        }
        visit [here-->[?:LogDay, date==self.date]] else {
            fresh = here ++> LogDay(date=self.date);
            attach_stamp(here, fresh);
            visit fresh;
        }
    }

    can add with LogDay entry {
        # `here` is the LogDay; its container is the caller's root.
        owners = [here<--];
        holder = owners[0];
        member_name = "";
        tags_snap = "";
        m = resolve(self.member_id);
        if isinstance(m, Member) {
            member_name = m.name;
            tags_snap = ", ".join(m.tags);
        }
        project_name = "";
        p = resolve(self.project_id);
        if isinstance(p, Project) and owned(holder, p) {
            project_name = p.name;
        }
        row = here +>:Logged():+> LogEntry(
            date=here.date,
            activity=self.activity,
            category=self.category,
            repo=self.repo,
            issue_link=self.issue_link,
            pr_link=self.pr_link,
            status=self.status,
            notes=self.notes,
            member_name=member_name,
            tags=tags_snap,
            project_name=project_name
        );
        if isinstance(m, Member) {
            row +>:By():+> m;
        }
        # Fresh row and edges are creator-sticky; stamp for the whole team.
        attach_stamp(holder, row);
        report row;
    }
}

# Board moves write the log now: append one denormalized row describing a
# task event to today's bucket. Called from the task walkers.
def record_task_event(holder: Root, task: Task, activity: str, stamp: str) -> None {
    today = stamp[:10];
    if not today {
        return;
    }
    # Server-side, a filtered re-query is answered from committed storage,
    # so a bucket created in this request is invisible to it. Use the
    # freshly connected node directly instead of querying it back.
    days = [holder-->[?:LogDay, date==today]];
    if days {
        day = days[0];
    } else {
        day = holder ++> LogDay(date=today);
        attach_stamp(holder, day);
    }
    names: list[str] = [];
    tag_pool: list[str] = [];
    for a in [task->:AssignedTo:->] {
        names.append(a.name);
        for t in a.tags {
            if t not in tag_pool {
                tag_pool.append(t);
            }
        }
    }
    projects = [task->:ForProject:->];
    row = day +>:Logged():+> LogEntry(
        date=today,
        at=stamp,
        task_id=jid(task),
        task_title=task.title,
        activity=activity,
        category=task.category,
        repo="",
        issue_link=task.issue_link,
        pr_link=task.pr_link,
        status=task.status,
        notes="",
        member_name=", ".join(names),
        tags=", ".join(tag_pool),
        project_name=projects[0].name if projects else ""
    );
    attach_stamp(holder, row);
}

# The move handoff arrives after the move row was written; refresh the
# latest row for this task today so its links and note show in the feed.
def sync_task_links(holder: Root, task: Task, note: str) -> None {
    today = task.updated_at[:10];
    days = [holder-->[?:LogDay, date==today]];
    if not days {
        return;
    }
    matches = [
        r
        for r in [days[0]->:Logged:->]
        if r.task_id == jid(task)
    ];
    if not matches {
        return;
    }
    matches.sort(key=lambda (r: LogEntry) { r.at; });
    target = matches[-1];
    target.issue_link = task.issue_link;
    target.pr_link = task.pr_link;
    if note {
        target.notes = note;
    }
}

walker find_log_entry {
    """Lookup base for log-entry mutations: two-hop parentage check
    (LogEntry <- LogDay <- root) before visiting."""
    has entry_id: str = "";

    can locate with Root entry {
        # Editor gate: the only subclass (UpdateLogEntry) mutates.
        if level_rank(caller_level(here, jid(root))) < 2 {
            disengage;
        }
        target = resolve(self.entry_id);
        if not isinstance(target, LogEntry) {
            disengage;
        }
        days = [target<-:Logged:<-];
        if days and owned(here, days[0]) {
            visit [target];
        }
    }
}

walker UpdateLogEntry(find_log_entry) {
    has activity: str = "",
        category: str = "",
        repo: str = "",
        issue_link: str = "",
        pr_link: str = "",
        status: str = "",
        notes: str = "",
        reports: list[LogEntry] = [];

    can apply with LogEntry entry {
        here.activity = self.activity;
        here.category = self.category;
        here.repo = self.repo;
        here.issue_link = self.issue_link;
        here.pr_link = self.pr_link;
        here.status = self.status;
        here.notes = self.notes;
        report here;
        disengage;
    }
}

walker DeleteLogEntries {
    """Bulk delete: every id is parentage-checked (LogEntry <- LogDay <-
    root) before removal, same rule as the single-entry lookup base."""
    has entry_ids: list[str] = [];

    can remove with Root entry {
        # Editor gate (see LogActivity).
        if level_rank(caller_level(here, jid(root))) < 2 {
            disengage;
        }
        gone: list[str] = [];
        for eid in self.entry_ids {
            target = resolve(eid);
            if not isinstance(target, LogEntry) {
                continue;
            }
            days = [target<-:Logged:<-];
            if days and owned(here, days[0]) {
                gone.append(jid(target));
                del target;
            }
        }
        report {"deleted": gone};
    }
}
