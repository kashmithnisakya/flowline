"""Daily-log walkers: day buckets and their entries."""

import from models {
    Project, Member, LogDay, LogEntry,
    Logged, By, resolve, on_attached, owned

}

# ---------------------------------------------------------------- daily log

walker ListLogEntries {
    """Entries whose LogDay date falls in [from_date, to_date], ISO strings."""
    has from_date: str,
        to_date: str,
        results: list[LogEntry] = [],
        reports: list[list[LogEntry]] = [];

    can start with Root entry {
        visit [here-->[?:LogDay, date >= self.from_date, date <= self.to_date]];
    }

    can descend with LogDay entry {
        visit [here ->:Logged:->];
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
        visit [here-->[?:LogDay, date == self.date]] else {
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
            date=here.date, activity=self.activity, category=self.category,
            repo=self.repo, issue_link=self.issue_link, pr_link=self.pr_link,
            status=self.status, notes=self.notes,
            member_name=member_name, tags=tags_snap, project_name=project_name
        );
        if isinstance(m, Member) {
            row +>:By():+> m;
        }
        report row;
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

walker DeleteLogEntry(find_log_entry) {
    can remove with LogEntry entry {
        gone = jid(here);
        del here;
        report {"deleted": gone};
        disengage;
    }
}
