"""Daily-log walkers: day buckets and their entries."""

import from models {
    Project,
    Member,
    Task,
    LogDay,
    LogEntry,
    Logged,
    By,
    AssignedTo,
    ForProject,
    resolve,
    on_attached,
    owned
}

# ---------------------------------------------------------------- daily log

walker ListLogEntries {
    """Entries whose LogDay date falls in [from_date, to_date], ISO strings."""
    has from_date: str,
        to_date: str,
        results: list[LogEntry] = [],
        reports: list[list[LogEntry]] = [];

    can start with Root entry {
        visit [here-->[?:LogDay, date>=self.from_date, date<=self.to_date]];
    }

    can descend with LogDay entry {
        visit [here->:Logged:->];
    }

    can gather with LogEntry entry {
        self.results.append(here);
    }

    can deliver with Root exit {
        self.results.sort(key=lambda (r: LogEntry) { r.date + r.member_name; });
        report self.results;
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
        if not self.date {
            disengage;
        }
        probe = resolve(self.member_id);
        if not isinstance(probe, Member) or not owned(here, probe) {
            disengage;
        }
        visit [here-->[?:LogDay, date==self.date]] else {
            fresh = here ++> LogDay(date=self.date);
            on_attached(here, fresh);
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
        on_attached(holder, day);
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
    day +>:Logged():+> LogEntry(
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
