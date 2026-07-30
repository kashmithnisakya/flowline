"""standup - Server-Side Data Layer.

All persisted archetypes live in THIS module and must not move: archetype
identity includes the module path, so relocating a node/edge declaration
orphans persisted data.

Every walker is `:pub` — v1 has no auth (same trust model as the shared
spreadsheet). All mutations on a specific node go through the lookup-base
walkers (`find_task`, `find_member`, ...) so the v2 `walker:priv` migration
touches one place per concern.
"""

import datetime;
import csv;
import io;

import from constants { STATUSES, TEAMS, CATEGORIES, PRIORITIES, SECTIONS }


def _now -> str {
    return datetime.datetime.now(datetime.UTC).replace(tzinfo=None).isoformat() + "Z";
}

# jobj raises on a malformed/unknown anchor id — a stale client jid must
# no-op the walker, not 500 the request.
def _resolve(anchor_id: str) -> any {
    if not anchor_id {
        return None;
    }
    try {
        return jobj(anchor_id);
    } except Exception {
        return None;
    }
}

def _to_iso_date(raw: str) -> str {
    s = raw.strip();
    if not s {
        return "";
    }
    for fmt in ["%Y-%m-%d", "%m/%d/%Y", "%m/%d/%y"] {
        try {
            return datetime.datetime.strptime(s, fmt).date().isoformat();
        } except Exception {
            continue;
        }
    }
    return s;
}

# ---------------------------------------------------------------- archetypes

node Member {
    has name: str,
        team: str,
        role: str = "",
        email: str = "",
        github_username: str = "",
        section: str = "",
        active: bool = True;
}

node Repo {
    has full_name: str;
}

node Task {
    has title: str,
        category: str,
        team: str,
        priority: str,
        status: str = "Backlog",
        due_date: str = "",
        notes: str = "",
        created_at: str = "",
        updated_at: str = "",
        sort_order: float = 0.0;

    def to_view -> TaskView {
        assignee_id = "";
        assignee_name = "";
        assignees = [self ->:AssignedTo:->];
        if assignees {
            assignee_id = jid(assignees[0]);
            assignee_name = assignees[0].name;
        }
        return TaskView(
            id=jid(self), title=self.title, category=self.category,
            team=self.team, priority=self.priority, status=self.status,
            due_date=self.due_date, notes=self.notes,
            created_at=self.created_at, updated_at=self.updated_at,
            sort_order=self.sort_order,
            assignee_id=assignee_id, assignee_name=assignee_name
        );
    }
}

node LogDay {
    has date: str;
}

node LogEntry {
    has date: str,
        activity: str,
        category: str = "",
        repo: str = "",
        issue_link: str = "",
        pr_link: str = "",
        status: str = "",
        notes: str = "",
        member_name: str = "",
        team: str = "",
        section: str = "";
}

edge AssignedTo: Task --> Member {}
edge Logged: LogDay --> LogEntry {}
edge By: LogEntry --> Member {}

obj TaskView {
    has id: str,
        title: str,
        category: str,
        team: str,
        priority: str,
        status: str,
        due_date: str,
        notes: str,
        created_at: str,
        updated_at: str,
        sort_order: float,
        assignee_id: str,
        assignee_name: str;
}

# ------------------------------------------------------------------- roster

walker:pub ListMembers {
    has results: list[Member] = [],
        reports: list[list[Member]] = [];

    can start with Root entry {
        visit [here-->[?:Member]];
    }

    can gather with Member entry {
        self.results.append(here);
    }

    can deliver with Root exit {
        self.results.sort(key=lambda (m: Member) { m.name; });
        report self.results;
    }
}

walker:pub SaveMember {
    """Empty member_id creates; otherwise updates the addressed Member."""
    has member_id: str = "",
        name: str = "",
        team: str = "",
        role: str = "",
        email: str = "",
        github_username: str = "",
        section: str = "",
        reports: list[Member] = [];

    can save with Root entry {
        if self.member_id {
            target = _resolve(self.member_id);
            if isinstance(target, Member) {
                target.name = self.name;
                target.team = self.team;
                target.role = self.role;
                target.email = self.email;
                target.github_username = self.github_username;
                target.section = self.section;
                report target;
            }
        } else {
            fresh = here ++> Member(
                name=self.name, team=self.team, role=self.role,
                email=self.email, github_username=self.github_username,
                section=self.section
            );
            report fresh;
        }
    }
}

walker:pub ArchiveMember {
    """active=False, never delete — history edges must survive.

    Open (non-Done) tasks lose their AssignedTo edge so live work returns
    to Unassigned instead of pointing at a member no dropdown shows;
    Done-task edges stay for history.
    """
    has member_id: str;

    can archive with Root entry {
        target = _resolve(self.member_id);
        if isinstance(target, Member) {
            target.active = False;
            for t in [target<-:AssignedTo:<-] {
                if t.status != "Done" {
                    for e in [edge t ->:AssignedTo:->] {
                        del e;
                    }
                }
            }
            report {"archived": self.member_id};
        }
    }
}

walker:pub ListRepos {
    has results: list[Repo] = [],
        reports: list[list[Repo]] = [];

    can start with Root entry {
        visit [here-->[?:Repo]];
    }

    can gather with Repo entry {
        self.results.append(here);
    }

    can deliver with Root exit {
        self.results.sort(key=lambda (r: Repo) { r.full_name; });
        report self.results;
    }
}

walker:pub AddRepo {
    has full_name: str,
        reports: list[Repo] = [];

    can add with Root entry {
        existing = [here-->[?:Repo, full_name == self.full_name]];
        if existing {
            report existing[0];
        } else {
            fresh = here ++> Repo(full_name=self.full_name);
            report fresh;
        }
    }
}

walker:pub RemoveRepo {
    has repo_id: str;

    can remove with Root entry {
        target = _resolve(self.repo_id);
        if isinstance(target, Repo) {
            gone = jid(target);
            del target;
            report {"deleted": gone};
        }
    }
}

# -------------------------------------------------------------------- tasks

walker:pub ListTasks {
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

walker:pub CreateTask {
    has title: str,
        category: str,
        team: str,
        priority: str,
        status: str = "Backlog",
        due_date: str = "",
        notes: str = "",
        assignee_id: str = "",
        reports: list[TaskView] = [];

    can create with Root entry {
        col = self.status if self.status in STATUSES else "Backlog";
        peak = 0.0;
        for t in [here-->[?:Task, status == col]] {
            if t.sort_order > peak {
                peak = t.sort_order;
            }
        }
        stamp = _now();
        fresh = here ++> Task(
            title=self.title, category=self.category, team=self.team,
            priority=self.priority, status=col,
            due_date=self.due_date, notes=self.notes,
            created_at=stamp, updated_at=stamp, sort_order=peak + 1024.0
        );
        if self.assignee_id {
            m = _resolve(self.assignee_id);
            if isinstance(m, Member) {
                fresh +>:AssignedTo():+> m;
            }
        }
        report fresh.to_view();
    }
}

walker find_task {
    """Lookup base: resolve the jid once; every task mutation subclasses this."""
    has task_id: str = "";

    can locate with Root entry {
        target = _resolve(self.task_id);
        if isinstance(target, Task) {
            visit [target];
        }
    }
}

walker:pub UpdateTask(find_task) {
    has title: str = "",
        category: str = "",
        team: str = "",
        priority: str = "",
        status: str = "",
        due_date: str = "",
        notes: str = "",
        assignee_id: str = "",
        reports: list[TaskView] = [];

    can apply with Task entry {
        here.title = self.title;
        here.category = self.category;
        here.team = self.team;
        here.priority = self.priority;
        here.status = self.status;
        here.due_date = self.due_date;
        here.notes = self.notes;
        here.updated_at = _now();
        for e in [edge here ->:AssignedTo:->] {
            del e;
        }
        if self.assignee_id {
            m = _resolve(self.assignee_id);
            if isinstance(m, Member) {
                here +>:AssignedTo():+> m;
            }
        }
        report here.to_view();
        disengage;
    }
}

walker:pub MoveTask(find_task) {
    """The drag-drop / arrow-move endpoint.

    The server is authoritative for ordering: a move always appends to the
    end of the target column, so two clients moving cards concurrently
    cannot collide on a client-computed sort_order.
    """
    has status: str = "",
        reports: list[TaskView] = [];

    can move with Task entry {
        peak = 0.0;
        for t in [root-->[?:Task, status == self.status]] {
            if t.sort_order > peak {
                peak = t.sort_order;
            }
        }
        here.status = self.status;
        here.sort_order = peak + 1024.0;
        here.updated_at = _now();
        report here.to_view();
        disengage;
    }
}

walker:pub DeleteTask(find_task) {
    can remove with Task entry {
        gone = jid(here);
        del here;
        report {"deleted": gone};
        disengage;
    }
}

# ---------------------------------------------------------------- daily log

walker:pub ListLogEntries {
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

walker:pub LogActivity {
    """Get-or-create the day bucket, then append one denormalized row."""
    has date: str,
        member_id: str,
        activity: str,
        category: str = "",
        repo: str = "",
        issue_link: str = "",
        pr_link: str = "",
        status: str = "",
        notes: str = "",
        reports: list[LogEntry] = [];

    can start with Root entry {
        # Refuse writes that no view could ever fetch (empty date) or that
        # would produce a blank authorless row (stale/unknown member jid).
        if not self.date {
            disengage;
        }
        probe = _resolve(self.member_id);
        if not isinstance(probe, Member) {
            disengage;
        }
        visit [here-->[?:LogDay, date == self.date]] else {
            fresh = here ++> LogDay(date=self.date);
            visit fresh;
        }
    }

    can add with LogDay entry {
        member_name = "";
        team = "";
        section = "";
        m = _resolve(self.member_id);
        if isinstance(m, Member) {
            member_name = m.name;
            team = m.team;
            section = m.section;
        }
        row = here +>:Logged():+> LogEntry(
            date=here.date, activity=self.activity, category=self.category,
            repo=self.repo, issue_link=self.issue_link, pr_link=self.pr_link,
            status=self.status, notes=self.notes,
            member_name=member_name, team=team, section=section
        );
        if isinstance(m, Member) {
            row +>:By():+> m;
        }
        report row;
    }
}

walker:pub UpdateLogEntry {
    has entry_id: str,
        activity: str = "",
        category: str = "",
        repo: str = "",
        issue_link: str = "",
        pr_link: str = "",
        status: str = "",
        notes: str = "",
        reports: list[LogEntry] = [];

    can apply with Root entry {
        target = _resolve(self.entry_id);
        if isinstance(target, LogEntry) {
            target.activity = self.activity;
            target.category = self.category;
            target.repo = self.repo;
            target.issue_link = self.issue_link;
            target.pr_link = self.pr_link;
            target.status = self.status;
            target.notes = self.notes;
            report target;
        }
    }
}

walker:pub DeleteLogEntry {
    has entry_id: str;

    can remove with Root entry {
        target = _resolve(self.entry_id);
        if isinstance(target, LogEntry) {
            gone = jid(target);
            del target;
            report {"deleted": gone};
        }
    }
}

# ---------------------------------------------------------------- migration

# Rows after the header row. A raw Excel export carries title/legend rows
# above the header (it sits at sheet row 4), so locate the row whose first
# cell equals the expected header token instead of assuming row 0; fall
# back to all rows if no header is present.
def _data_rows(rows: list[list[str]], header_token: str) -> list[list[str]] {
    for (i, r) in enumerate(rows) {
        if r and r[0].strip() == header_token {
            return rows[i + 1:];
        }
    }
    return rows;
}

walker:pub ImportCsv {
    """One-time spreadsheet migration. sheet: roster | repos | todo.

    Idempotent-ish: members match by name, repos by full_name, tasks by
    title+team — existing rows are skipped (with their titles reported so
    losses are visible), so re-running after a partial import is safe.
    The roster sheet also carries the GitHub Repos list in column G, so
    the roster branch ingests repos too.
    """
    has sheet: str,
        csv_text: str;

    can ingest with Root entry {
        rows: list[list[str]] = list(csv.reader(io.StringIO(self.csv_text)));
        imported = 0;
        skipped = 0;
        skipped_titles: list[str] = [];
        if self.sheet == "roster" {
            # Name, Team, Role, Email, GitHub Username, Section, [GitHub Repos]
            for r in _data_rows(rows, "Name") {
                repo_cell = r[6].strip() if len(r) > 6 else "";
                if repo_cell and not [here-->[?:Repo, full_name == repo_cell]] {
                    here ++> Repo(full_name=repo_cell);
                }
                if len(r) < 2 or not r[0].strip() {
                    continue;
                }
                nm = r[0].strip();
                if [here-->[?:Member, name == nm]] {
                    skipped += 1;
                    skipped_titles.append(nm);
                    continue;
                }
                here ++> Member(
                    name=nm, team=r[1].strip(),
                    role=r[2].strip() if len(r) > 2 else "",
                    email=r[3].strip() if len(r) > 3 else "",
                    github_username=r[4].strip() if len(r) > 4 else "",
                    section=r[5].strip() if len(r) > 5 else ""
                );
                imported += 1;
            }
        } elif self.sheet == "repos" {
            for r in _data_rows(rows, "GitHub Repos") {
                if not r or not r[0].strip() {
                    continue;
                }
                fn = r[0].strip();
                if [here-->[?:Repo, full_name == fn]] {
                    skipped += 1;
                    skipped_titles.append(fn);
                    continue;
                }
                here ++> Repo(full_name=fn);
                imported += 1;
            }
        } elif self.sheet == "todo" {
            # Task, Task Category, Team, Assigned To, Priority, Status, Due Date, Notes
            order = 1024.0;
            for r in _data_rows(rows, "Task") {
                if len(r) < 1 or not r[0].strip() {
                    continue;
                }
                ttl = r[0].strip();
                tm = r[2].strip() if len(r) > 2 else "";
                assigned = r[3].strip() if len(r) > 3 else "";
                existing = [here-->[?:Task, title == ttl, team == tm]];
                if existing {
                    # Skip the duplicate, but backfill a missing assignment:
                    # importing todo before roster leaves tasks unassigned,
                    # and this heals them on the re-run.
                    if assigned and not [existing[0] ->:AssignedTo:->] {
                        found = [here-->[?:Member, name == assigned]];
                        if found {
                            existing[0] +>:AssignedTo():+> found[0];
                        }
                    }
                    skipped += 1;
                    skipped_titles.append(ttl);
                    continue;
                }
                status = r[5].strip() if len(r) > 5 else "Backlog";
                if status == "Not Started" or status not in STATUSES {
                    status = "Backlog";
                }
                priority = r[4].strip() if len(r) > 4 else "";
                if priority not in PRIORITIES {
                    priority = "Medium";
                }
                category = r[1].strip() if len(r) > 1 else "";
                if category not in CATEGORIES {
                    category = "";
                }
                stamp = _now();
                fresh = here ++> Task(
                    title=ttl,
                    category=category,
                    team=tm,
                    priority=priority,
                    status=status,
                    due_date=_to_iso_date(r[6]) if len(r) > 6 else "",
                    notes=r[7].strip() if len(r) > 7 else "",
                    created_at=stamp, updated_at=stamp, sort_order=order
                );
                if assigned {
                    found = [here-->[?:Member, name == assigned]];
                    if found {
                        fresh +>:AssignedTo():+> found[0];
                    }
                }
                order += 1024.0;
                imported += 1;
            }
        }
        report {
            "imported": imported, "skipped": skipped,
            "skipped_titles": skipped_titles, "sheet": self.sheet
        };
    }
}
