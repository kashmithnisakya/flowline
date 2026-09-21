"""flowline - persisted graph model and shared helpers. EVERY node/edge/obj
archetype lives HERE and must not move: archetype identity includes the module
path, so relocating a declaration orphans persisted data.

Layout: root ++> Projects ++> Project ++> Task, root ++> Members ++> Member,
root ++> Roles ++> Role, root ++> WorkflowSteps ++> WorkflowStep and
root ++> Logs ++> LogDay ++> LogEntry and root ++> Iterations ++> Iteration;
repos and the GitHub connection hang off the root directly. `owned()` climbs
those container edges.
"""

# jobj raises on a malformed/unknown anchor id — a stale client jid must
# no-op the walker, not 500 the request.
def resolve(anchor_id: str) -> any {
    if not anchor_id {
        return None;
    }
    try {
        return jobj(anchor_id);
    } except Exception {
        return None;
    }
}

# v3 hook: when multi-PM orgs land, grant `fresh` to every collaborating
# root here. Deliberately a no-op while one account == one organization.
def on_attached(holder: any, fresh: any) -> None {
    return;
}

# "org/repo" and nothing else: repo names land in api.github.com paths, so
# `..`, `?` or `#` could redirect a request. Pure string work, so it lives
# here rather than in the Python-importing helpers, shared by storage and API.
def valid_full_name(full_name: str) -> bool {
    if full_name.count("/") != 1 {
        return False;
    }
    for part in full_name.split("/") {
        if not part or len(part) > 100 {
            return False;
        }
        for ch in part {
            if not (ch.isalnum() or ch in "-_.") {
                return False;
            }
        }
    }
    return True;
}

# The nodes a row may sit under on its way to the root: the three boxes
# and, for a task, its project. Anything else hangs off the root.
def is_container(owner: any) -> bool {
    return (
        isinstance(owner, Projects)
        or isinstance(owner, Project)
        or isinstance(owner, Members)
        or isinstance(owner, Roles)
        or isinstance(owner, WorkflowSteps)
        or isinstance(owner, Logs)
        or isinstance(owner, LogDay)
        or isinstance(owner, Iterations)
    );
}


# Does this node belong to the caller's root? Climbs container edges, at
# most three hops (task, project, Projects box); typed in-edges never lead
# to a container, so they drop out. jobj/jid resolution is NOT authorization:
# every jid-addressed mutation calls this first. "My root" is the tenant line.
def owned(holder: any, target: any) -> bool {
    frontier: list[any] = [target];
    for hop in range(3) {
        higher: list[any] = [];
        for node_ in frontier {
            for owner in [node_<--] {
                if jid(owner) == jid(holder) {
                    return True;
                }
                if is_container(owner) {
                    higher.append(owner);
                }
            }
        }
        frontier = higher;
    }
    return False;
}

# ---------------------------------------------------------------- archetypes

node Project {
    has name: str,
        description: str = "",
        active: bool = True,
        # All-time tallies kept on every task write, so no count loads the
        # history. `seeded_done_total` is the Done tasks created already
        # Done (history, not throughput). An empty `tallies_at` means never
        # set: ensure_tallies fills them from one full load and stamps it.
        task_total: int = 0,
        done_total: int = 0,
        seeded_done_total: int = 0,
        tallies_at: str = "",
        # The Overview's history, kept on the same writes: tasks added and
        # moved to Done per week, keyed by the week's Monday (history_days).
        # An empty `history_at` means not counted yet; ensure_history fills it.
        week_added: dict[str, int] = {},
        week_finished: dict[str, int] = {},
        history_at: str = "";
}

# Roles are HasRole edges to Role nodes, never names on the member.
node Member {
    has first_name: str = "",
        last_name: str = "",
        email: str = "",
        github_username: str = "",
        tags: list[str] = [],
        # A manager-picked avatar colour (a step colour key). Empty falls
        # back to the hue hashed from the name, so existing members keep
        # the colour they already show.
        color: str = "",
        active: bool = True;

    # The display name; the log and every view show this.
    def full_name -> str {
        return (self.first_name + " " + self.last_name).strip();
    }
}

node Repo {
    has full_name: str,
        # Auto-file new issues onto the entry step on every GitHub sync.
        # The cursor is the newest `updated_at` seen, so each sync asks
        # GitHub only for what changed since; empty means backfill.
        auto_sync: bool = False,
        issue_cursor: str = "",
        # Merged PR moves the linked card to the done step on sync.
        auto_done: bool = False,
        # The reverse direction: a card landing on Done closes its issue,
        # and one leaving Done reopens it.
        auto_close: bool = False;
}

node Task {
    has title: str,
        category: str,
        priority: str,
        # The board column this task sits in, as a WorkflowStep jid. Empty on
        # every task written before flow lines existed, and on any task whose
        # step was deleted; the board falls back to `status` for those, so
        # this is additive and old rows keep working.
        step_id: str = "",
        # Legacy column AND the semantic signal the rest of the app reads
        # ("Done" is terminal, "Blocked" needs attention). A move keeps it in
        # step with the step's kind, so insights, GitHub sync and the
        # assistant never have to learn about steps.
        status: str = "Backlog",
        due_date: str = "",
        notes: str = "",
        issue_link: str = "",
        pr_link: str = "",
        reviewer_id: str = "",
        reviewer_name: str = "",
        review_due: str = "",
        created_at: str = "",
        updated_at: str = "",
        sort_order: float = 0.0,
        # Free labels beside the single category; GitHub issue labels land
        # here at import. Additive with a default, so old rows keep working.
        tags: list[str] = [],
        # Effort estimate in the org's own unit (points or hours). 0 means
        # unestimated; additive with a default, so old rows read as such.
        estimate: float = 0.0,
        # GitHub identity. issue_link/pr_link stay the human URLs anyone can
        # paste by hand; these are the machine key the API syncs against.
        # gh_issue_number == 0 means "not linked to a real issue".
        gh_repo: str = "",
        gh_issue_number: int = 0,
        gh_issue_state: str = "",
        gh_synced_at: str = "",
        # GitHub's updated_at of the newest issue item applied here, kept
        # monotonic so an older event can never roll a newer one back. The
        # linked PR is a different object with its own clock, hence two.
        gh_updated_at: str = "",
        pr_updated_at: str = "",
        # GitHub sub-issue family, stamped by the sync. A parent carries its
        # summary counts; a child carries its parent's identity. Fields, not
        # edges: an edge would cost a traversal per row in every list.
        gh_parent_repo: str = "",
        gh_parent_number: int = 0,
        gh_sub_total: int = 0,
        gh_sub_done: int = 0,
        pr_number: int = 0,
        pr_state: str = "",
        # GitHub's own assignees on the issue, refreshed by every issue
        # event. The card's assignees are the roster's and stay the
        # workspace's to set; these say what GitHub thinks.
        gh_assignees: list[str] = [],
        # The linked PR's review conversation: "requested" from a review
        # request, then the verdict a review submits. Its own clock, because
        # the PR's updated_at does not move when someone reviews it.
        pr_review_state: str = "",
        pr_review_at: str = "",
        # When the task last entered Done, "" while it is open. Written only
        # by set_status; rows from before it read updated_at (done_day).
        done_at: str = "",
        # The card's own breakdown: {"id", "text", "done"} in display order.
        # Written only by the checklist walkers, never by UpdateTask.
        checklist: list[dict[str, any]] = [],
        # The Iteration this task is planned into, by jid ("" for none), and
        # when work on it starts. Fields, not edges, so list rows stay
        # hop-free; the roadmap falls back to the iteration's dates.
        iteration_id: str = "",
        start_date: str = "",
        # The container project's jid and the assignees' jids, kept in step
        # with the edges at every write point so a list row needs no hop.
        # The edges stay the truth: `owned` climbs the container edge.
        project_id: str = "",
        assignee_ids: list[str] = [];

    # Every status write goes through here, so `done_at` stays true to the
    # move into Done (kept while the task stays Done, cleared when it
    # leaves) and the project's Done tallies move with it.
    def set_status(status: str, stamp: str) {
        was_done = self.status == "Done";
        was_seeded = seeded_done(self);
        before = history_days(self);
        if status == "Done" and not was_done {
            self.done_at = stamp;
        } elif status != "Done" {
            self.done_at = "";
        }
        self.status = status;
        now_done = status == "Done";
        now_seeded = seeded_done(self);
        if was_done == now_done and was_seeded == now_seeded {
            return;
        }
        for p in task_project(self) {
            if was_done != now_done {
                p.done_total = p.done_total + (1 if now_done else -1);
            }
            if was_seeded != now_seeded {
                p.seeded_done_total = p.seeded_done_total + (1 if now_seeded else -1);
            }
            shift_history(p, before, history_days(self));
        }
    }

    # One task's view, hopping its own edges (the structural truth). Fine
    # for a single task; a list reads the link fields through hydrate_rows.
    def to_view -> TaskView {
        assignee_ids: list[str] = [];
        assignee_names: list[str] = [];
        for a in [self->:AssignedTo:->] {
            assignee_ids.append(jid(a));
            assignee_names.append(a.full_name());
        }
        project_id = "";
        project_name = "";
        projects = [self<--[?:Project]];
        if projects {
            project_id = jid(projects[0]);
            project_name = projects[0].name;
        }
        return self.view_with(assignee_ids, assignee_names, project_id, project_name);
    }

    # The list row given names the caller already has. The row's field list
    # lives here once; view_with adds the sheet's fields on top of it.
    def row_with(
        assignee_ids: list[str],
        assignee_names: list[str],
        project_id: str,
        project_name: str
    ) -> TaskRow {
        counts = checklist_counts(self.checklist);
        return TaskRow(
            id=jid(self),
            title=self.title,
            category=self.category,
            tags=self.tags,
            estimate=self.estimate,
            priority=self.priority,
            status=self.status,
            step_id=self.step_id,
            due_date=self.due_date,
            created_at=self.created_at,
            updated_at=self.updated_at,
            done_at=self.done_at,
            sort_order=self.sort_order,
            assignee_ids=assignee_ids,
            assignee_names=assignee_names,
            issue_link=self.issue_link,
            pr_link=self.pr_link,
            reviewer_id=self.reviewer_id,
            reviewer_name=self.reviewer_name,
            review_due=self.review_due,
            project_id=project_id,
            project_name=project_name,
            gh_repo=self.gh_repo,
            gh_issue_number=self.gh_issue_number,
            gh_issue_state=self.gh_issue_state,
            gh_parent_repo=self.gh_parent_repo,
            gh_parent_number=self.gh_parent_number,
            gh_sub_total=self.gh_sub_total,
            gh_sub_done=self.gh_sub_done,
            pr_number=self.pr_number,
            pr_state=self.pr_state,
            iteration_id=self.iteration_id,
            start_date=self.start_date,
            note_lead=note_lead(self.notes),
            checklist_done=counts[0],
            checklist_total=counts[1]
        );
    }

    # The full view: the row plus notes, the checklist and the GitHub-only
    # fields. vars() of an obj is exactly its declared fields.
    def view_with(
        assignee_ids: list[str],
        assignee_names: list[str],
        project_id: str,
        project_name: str
    ) -> TaskView {
        row = self.row_with(assignee_ids, assignee_names, project_id, project_name);
        return TaskView(
            **vars(row),
            notes=self.notes,
            gh_synced_at=self.gh_synced_at,
            gh_assignees=self.gh_assignees,
            pr_review_state=self.pr_review_state,
            checklist=self.checklist
        );
    }
}

# The first line of a task's notes, capped: what a card's overdue reason and
# blocked line read (leadNote in TaskCard), so a list row never ships the
# rest of a 2,000-character note.
glob NOTE_LEAD_MAX: int = 200;


def note_lead(notes: str) -> str {
    text = notes.strip() if notes else "";
    if not text {
        return "";
    }
    return text.split("\n")[0].strip()[:NOTE_LEAD_MAX];
}


# [done, total] over a checklist, the way the card counts it.
def checklist_counts(items: list[dict[str, any]]) -> list[int] {
    done = 0;
    for item in items {
        if isinstance(item, dict) and item.get("done") {
            done = done + 1;
        }
    }
    return [done, len(items)];
}

# One day of the log under the Logs box; its entries hang off it. Its
# tallies (entries, and entries per person named on them) are kept on write
# by note_entry / forget_entry once `tallied`; fill_day sets them for a day
# written before they existed, so no count ever loads the entries.
node LogDay {
    has date: str,
        entry_total: int = -1,
        member_counts: dict[str, int] = {},
        tallied: bool = False;
}

node LogEntry {
    has date: str,
        activity: str,
        at: str = "",
        task_id: str = "",
        task_title: str = "",
        category: str = "",
        repo: str = "",
        issue_link: str = "",
        pr_link: str = "",
        status: str = "",
        notes: str = "",
        member_name: str = "",
        tags: str = "",
        project_name: str = "",
        # entry_key(): the stamp as digits, then the jid. Unique, so a page of
        # a day is an ORDER BY plus OFFSET/LIMIT in the store.
        sort_key: str = "",
        # The issues an import line stands for ("Imported 12 issues from
        # org/repo", one per day, repo and status); 0 on every other entry.
        item_count: int = 0;
}


# The org's GitHub App installation, singleton per root. It stores an
# installation id, NOT a credential: tokens are minted on demand in ghutil.
# `pending_state` is the one-shot CSRF nonce for an install round trip;
# without it a forged callback could bind someone else's installation here.
node GithubConnection {
    has installation_id: int = 0,
        account_login: str = "",
        account_avatar: str = "",
        status: str = "ok",
        connected_at: str = "",
        last_sync_at: str = "",
        pending_state: str = "",
        pending_at: str = "";
}

# An org-level role definition, seeded by ApplyTemplate and editable on the
# Roles tab. A member holds it through a HasRole edge, so a rename or delete
# reaches members on its own; a step's `owner` still holds the NAME.
node Role {
    has name: str,
        blurb: str = "",
        color: str = "",
        sort_order: float = 0.0;
}

# One step of the org's flow line: a named column with a semantic `kind`
# behind the user's label. The kind, not the name, is what the app keys
# behaviour on, so renaming never breaks anything. Position is the
# designer's canvas placement in px, persisted because it is drawn by hand.
node WorkflowStep {
    has name: str,
        kind: str = "active",
        color: str = "",
        # A ROLE, not a person: "domain expert", "model", "whoever raised it".
        owner: str = "",
        # One line of what happens here, in the org's own words. Shown on the
        # card in the Lane view, where it takes the kind row's place.
        blurb: str = "",
        x: float = 0.0,
        y: float = 0.0,
        sort_order: float = 0.0,
        # Outgoing transitions in draw order, one per target step:
        # {"to": step jid, "label": what has to be true to cross, "carries":
        # "issue" | "pr" | ""}. Cycles are allowed; self-loops are refused.
        transitions: list[dict[str, str]] = [],
        created_at: str = "",
        updated_at: str = "";
}

# Boxes, one of each per root, made on first write by the *_box helpers.
# Every project, member, role and step hangs off its box, never off the root.
# The projects' box also lists every category a task carries, kept exact
# on write (note_category / forget_category), so no list scans for them.
node Projects {
    has categories: list[str] = [];
}

node Members {}

node Roles {}

# The steps' box is also the flow line's own record: its display name and
# which template seeded it ("" means drawn from scratch). The Roles tab keys
# on the template: one with a `roles` list brings fixed roles.
node WorkflowSteps {
    has name: str = "Flow line",
        template_key: str = "";
}

node Logs {}

# A time box the team plans in: a name and an inclusive ISO date span. Tasks
# point at one through Task.iteration_id.
node Iteration {
    has name: str,
        start_date: str,
        end_date: str,
        created_at: str = "";
}

node Iterations {}

edge HasRepo: Project --> Repo {}
edge AssignedTo: Task --> Member {}
edge By: LogEntry --> Member {}
edge OnProject: Member --> Project {}
edge HasRole: Member --> Role {}

obj TaskRow {
    """What a list renders: the board card, the table row, the roadmap bar,
    the step panel and the Overview's queues. Every list walker reports
    these; the notes and the checklist items stay on TaskView, which the
    task sheet loads with GetTask when it opens."""
    has id: str,
        title: str,
        category: str,
        priority: str,
        status: str,
        due_date: str,
        created_at: str,
        updated_at: str,
        sort_order: float,
        assignee_ids: list[str],
        assignee_names: list[str],
        issue_link: str,
        pr_link: str,
        reviewer_id: str,
        reviewer_name: str,
        review_due: str,
        project_id: str,
        project_name: str,
        step_id: str = "",
        tags: list[str] = [],
        estimate: float = 0.0,
        gh_repo: str = "",
        gh_issue_number: int = 0,
        gh_issue_state: str = "",
        gh_parent_repo: str = "",
        gh_parent_number: int = 0,
        gh_sub_total: int = 0,
        gh_sub_done: int = 0,
        pr_number: int = 0,
        pr_state: str = "",
        iteration_id: str = "",
        start_date: str = "",
        done_at: str = "",
        # The first line of the notes (at most NOTE_LEAD_MAX characters):
        # the card's blocked line and overdue reason.
        note_lead: str = "",
        # How many checklist items are ticked, and how many there are.
        checklist_done: int = 0,
        checklist_total: int = 0;
}

obj TaskView(TaskRow) {
    """One task in full: a TaskRow plus the notes, the checklist items and
    the GitHub-only fields. GetTask and every task write report this."""
    has notes: str = "",
        gh_synced_at: str = "",
        gh_assignees: list[str] = [],
        pr_review_state: str = "",
        checklist: list[dict[str, any]] = [];
}

# A task by id and title, for the assistant's citations: nothing else rides.
obj TaskTitle {
    has id: str,
        title: str;
}

# The Overview's charts over time, one entry per week oldest first: `weeks`
# holds each Monday, `added` / `finished` count that week, `scope` / `done`
# are running totals at the week's end.
obj WeeklyHistory {
    has weeks: list[str] = [],
        added: list[int] = [],
        finished: list[int] = [],
        scope: list[int] = [],
        done: list[int] = [];
}

# One page of tasks. `total` counts every row that matched the filters, not
# just this page, so a caller can say "50 of 1,417" without a second call.
obj TaskPage {
    has rows: list[TaskRow] = [],
        page: int = 1,
        page_size: int = 50,
        has_more: bool = False,
        total: int = 0,
        # Working scope only: Done rows older than the cutoff, same filters.
        older: int = 0,
        # The scope's count with no filter on (what `total` would be on an
        # unfiltered page), so a filtered view says "12 of 210" in one call.
        scope_total: int = 0;
}

obj LogPage {
    has rows: list[LogEntry] = [],
        page: int = 1,
        page_size: int = 200,
        has_more: bool = False,
        total: int = 0;
}

# The Overview's numbers, computed where the tasks live so the page never
# has to load the whole history to count it.
obj ProjectTally {
    has project_id: str,
        total: int = 0,
        done: int = 0,
        blocked: int = 0,
        active: int = 0;
}

obj MemberTally {
    has member_id: str,
        open: int = 0,
        done_in_week: int = 0;
}

obj TaskTotals {
    has open: int = 0,
        overdue: int = 0,
        blocked: int = 0,
        # Done per week for the four weeks ending on the given Monday's week,
        # oldest first. A Done task only remembers its last update.
        done_by_week: list[int] = [],
        projects: list[ProjectTally] = [],
        members: list[MemberTally] = [],
        # Every category in use, so a filter built from the working set
        # alone does not lose the ones only old Done tasks carry.
        categories: list[str] = [];
}

# One person's entries this week, by roster name (a log row's member_name is
# every assignee comma-joined, split server-side): a count per weekday,
# Monday first, and the week's total.
obj MemberDays {
    has name: str,
        by_day: list[int] = [],
        total: int = 0;
}

obj LogTotals {
    has by_week: list[int] = [],
        by_day: list[int] = [],
        members: list[MemberDays] = [];
}

obj MemberView {
    has id: str,
        name: str,
        first_name: str,
        last_name: str,
        roles: list[str],
        email: str,
        github_username: str,
        tags: list[str],
        color: str,
        active: bool,
        project_ids: list[str],
        project_names: list[str];
}

obj RepoView {
    has id: str,
        full_name: str,
        project_id: str,
        project_name: str,
        auto_sync: bool = False,
        auto_done: bool = False,
        auto_close: bool = False;
}

obj RoleView {
    has id: str,
        name: str,
        blurb: str,
        color: str,
        sort_order: float;
}

obj IterationView {
    has id: str,
        name: str,
        start_date: str,
        end_date: str;
}

def iteration_view(it: Iteration) -> IterationView {
    return IterationView(
        id=jid(it), name=it.name, start_date=it.start_date, end_date=it.end_date
    );
}

def role_view(r: Role) -> RoleView {
    return RoleView(
        id=jid(r), name=r.name, blurb=r.blurb, color=r.color, sort_order=r.sort_order
    );
}


obj StepView {
    has id: str,
        name: str,
        kind: str,
        color: str,
        x: float,
        y: float,
        sort_order: float,
        owner: str = "",
        blurb: str = "",
        prev_ids: list[str] = [],
        next_ids: list[str] = [],
        # Index-aligned with next_ids, all three read off the step's field.
        next_labels: list[str] = [],
        next_carries: list[str] = [],
        # How much work is sitting here, counted per request in GetFlowLine
        # because it depends on the project filter the caller asked for.
        task_count: int = 0,
        # The first two titles in the step panel's order, filled with the
        # count, so a close zoom on the flow line needs no request.
        task_titles: list[str] = [];
}

# What the client is allowed to know about the GitHub link. The connection
# node itself is never reported: `report <node>` serializes every field, so
# routing it through a view is what keeps internals off the wire.
obj GithubConnectionView {
    has connected: bool = False,
        account_login: str = "",
        account_avatar: str = "",
        status: str = "",
        connected_at: str = "",
        last_sync_at: str = "",
        webhook_seen_at: str = "",
        configured: bool = False,
        missing_config: list[str] = [];
}

# Live GitHub reads. These are request-scoped projections, never persisted,
# so they can change shape freely.
obj GhRepoRow {
    has full_name: str,
        private: bool = False,
        description: str = "",
        attached: bool = False;
}

obj GhIssueRow {
    has number: int,
        title: str,
        state: str,
        labels: list[str] = [],
        assignee: str = "",
        html_url: str = "",
        already_imported: bool = False,
        imported_task_id: str = "";
}

obj GhPrRow {
    has number: int,
        title: str,
        state: str,
        author: str = "",
        html_url: str = "",
        linked_task_id: str = "",
        updated_at: str = "";
}

def repo_view(r: Repo) -> RepoView {
    project_id = "";
    project_name = "";
    for p in [r<-:HasRepo:<-] {
        project_id = jid(p);
        project_name = p.name;
    }
    return RepoView(
        id=jid(r),
        full_name=r.full_name,
        project_id=project_id,
        project_name=project_name,
        auto_sync=r.auto_sync,
        auto_done=r.auto_done,
        auto_close=r.auto_close
    );
}


# ------------------------------------------------------------------ layout
# One box per kind under the root; the box is the one traversal that yields
# every row of that kind. These readers serve the walkers that aggregate
# across kinds from the root; a box-scoped walker visits its box instead.
# Two overlapping first writes can leave two boxes, so readers merge every
# box and writers take the first.

def projects_of(holder: Root) -> list[Project] {
    out: list[Project] = [];
    for box in [holder-->[?:Projects]] {
        out.extend([box-->[?:Project]]);
    }
    return out;
}


def members_of(holder: Root) -> list[Member] {
    out: list[Member] = [];
    for box in [holder-->[?:Members]] {
        out.extend([box-->[?:Member]]);
    }
    return out;
}


def roles_of(holder: Root) -> list[Role] {
    out: list[Role] = [];
    for box in [holder-->[?:Roles]] {
        out.extend([box-->[?:Role]]);
    }
    return out;
}


def iterations_of(holder: Root) -> list[Iteration] {
    out: list[Iteration] = [];
    for box in [holder-->[?:Iterations]] {
        out.extend([box-->[?:Iteration]]);
    }
    return out;
}


def steps_of(holder: Root) -> list[WorkflowStep] {
    out: list[WorkflowStep] = [];
    for box in [holder-->[?:WorkflowSteps]] {
        out.extend([box-->[?:WorkflowStep]]);
    }
    return out;
}


# Log days with `date` in [since, until], ISO strings. The date filter runs
# in the store's query, so a week costs the same however long the history.
def days_between(holder: Root, since: str, until: str) -> list[LogDay] {
    out: list[LogDay] = [];
    for box in [holder-->[?:Logs]] {
        out.extend([box-->[?:LogDay, date>=since, date<=until]]);
    }
    return out;
}


# Rows [start, stop) of a day's entries, newest first. The order and the
# slice run in the store, so a page loads its own rows and no others.
def day_entries(day: LogDay, start: int, stop: int) -> list[LogEntry] {
    return [day-->[?:LogEntry, -sort_key]][start:stop];
}


# One task's entries under a day, the filter in the store's query.
def day_task_entries(day: LogDay, tid: str) -> list[LogEntry] {
    return [day-->[?:LogEntry, task_id==tid]];
}


# A day's import lines for one repo: the entries no single task owns.
def day_import_lines(day: LogDay, full_name: str) -> list[LogEntry] {
    return [day-->[?:LogEntry, repo==full_name, task_id==""]];
}


# A task's entries between two dates, in one query across the days.
def task_entries_between(
    holder: Root, tid: str, since: str, until: str
) -> list[LogEntry] {
    out: list[LogEntry] = [];
    for box in [holder-->[?:Logs]] {
        out.extend(
            [box-->[?:LogDay, date>=since, date<=until]-->[?:LogEntry, task_id==tid]]
        );
    }
    return out;
}


# A task's Blocked lines between two dates, in one query across the days.
def blocked_lines(holder: Root, tid: str, since: str, until: str) -> list[LogEntry] {
    out: list[LogEntry] = [];
    for box in [holder-->[?:Logs]] {
        out.extend(
            [box-->[?:LogDay, date>=since, date<=until]-->[?:LogEntry, task_id==tid, status=="Blocked"]]
        );
    }
    return out;
}


# The stamp (else the date) as 20 digits, then the jid. Digits and lowercase
# hex sort alike under any collation, so the store and a Python sort agree,
# and a stamp with or without microseconds lands in time order.
def entry_key(at: str, date: str, id: str) -> str {
    base = at or date;
    digits = "".join(
        [
            c
            for c in base[:19]
            if c.isdigit()
        ]
    );
    frac = "";
    if len(base) > 20 and base[19] == "." {
        for c in base[20:] {
            if not c.isdigit() {
                break;
            }
            frac = frac + c;
        }
    }
    return (digits + "00000000000000")[:14] + (frac + "000000")[:6] + id;
}


# The people an entry counts for: `member_name` is every assignee joined
# with ", ", so a name appears once per mention.
def entry_people(member_name: str) -> list[str] {
    out: list[str] = [];
    for who in member_name.split(",") {
        name = who.strip();
        if name {
            out.append(name);
        }
    }
    return out;
}


# Move a day's tallies by one entry, in or out. The dict is rebuilt and
# assigned, so the write is tracked like any field.
def tally_entry(day: LogDay, row: LogEntry, delta: int) {
    if not day.tallied {
        return;
    }
    day.entry_total = max(0, day.entry_total + delta);
    counts = dict(day.member_counts);
    for name in entry_people(row.member_name) {
        left = (counts[name] if name in counts else 0) + delta;
        if left > 0 {
            counts[name] = left;
        } elif name in counts {
            del counts[name];
        }
    }
    day.member_counts = counts;
}


# A new entry under its day: key it and count it. Every LogEntry write goes
# through here, or the day's pages skip or repeat rows.
def note_entry(day: LogDay, row: LogEntry) {
    row.sort_key = entry_key(row.at, row.date, jid(row));
    tally_entry(day, row, 1);
}


# An entry about to be deleted leaves its day's tallies.
def forget_entry(row: LogEntry) {
    for day in [row<--[?:LogDay]] {
        tally_entry(day, row, -1);
    }
}


# ------------------------------------------------------------- task readers
# Every predicate below is pushed into the store's query, so a reader loads
# only the rows it returns. The working set (open plus recently Done) is what
# the pages render; the whole history is loaded only by the explicit history
# scopes of ListTasks (all_tasks, done_tasks, done_before) and by the
# one-off ensure_tallies. `since` and `cutoff` are ISO days compared as
# text against the full stamp, which is the same test as done_day >= day.

# Every task, the whole history: one traversal per project.
def all_tasks(holder: Root) -> list[Task] {
    out: list[Task] = [];
    for p in projects_of(holder) {
        out.extend([p-->[?:Task]]);
    }
    return out;
}


def all_tasks_in(holder: Root, said: str) -> list[Task] {
    out: list[Task] = [];
    for p in projects_of(holder) {
        out.extend([p-->[?:Task, category==said]]);
    }
    return out;
}


# Every open (non-Done) task of every project, one query.
def open_tasks(holder: Root) -> list[Task] {
    out: list[Task] = [];
    for box in [holder-->[?:Projects]] {
        out.extend([box-->[?:Project]-->[?:Task, status!="Done"]]);
    }
    return out;
}


# Done tasks that reached Done on or after `since`.
def done_since(holder: Root, since: str) -> list[Task] {
    out: list[Task] = [];
    for box in [holder-->[?:Projects]] {
        out.extend([box-->[?:Project]-->[?:Task, status=="Done", done_at>=since]]);
    }
    return out;
}


# Done tasks that reached Done before `cutoff`: the board's "+N older"
# history. Nothing is older when history is not being trimmed.
def done_before(holder: Root, cutoff: str) -> list[Task] {
    out: list[Task] = [];
    if not cutoff {
        return out;
    }
    for box in [holder-->[?:Projects]] {
        out.extend([box-->[?:Project]-->[?:Task, status=="Done", done_at<cutoff]]);
    }
    return out;
}


def done_before_in(holder: Root, cutoff: str, said: str) -> list[Task] {
    out: list[Task] = [];
    if not cutoff {
        return out;
    }
    for box in [holder-->[?:Projects]] {
        out.extend(
            [box-->[?:Project]-->[?:Task, status=="Done", done_at<cutoff, category==said]]
        );
    }
    return out;
}


def done_tasks(holder: Root) -> list[Task] {
    out: list[Task] = [];
    for box in [holder-->[?:Projects]] {
        out.extend([box-->[?:Project]-->[?:Task, status=="Done"]]);
    }
    return out;
}


def done_tasks_in(holder: Root, said: str) -> list[Task] {
    out: list[Task] = [];
    for box in [holder-->[?:Projects]] {
        out.extend([box-->[?:Project]-->[?:Task, status=="Done", category==said]]);
    }
    return out;
}


# The working set the board renders: open tasks plus the Done tasks that
# reached Done since `cutoff` (every Done task when the cutoff is empty).
def working_tasks(holder: Root, cutoff: str) -> list[Task] {
    out = open_tasks(holder);
    out.extend(done_since(holder, cutoff) if cutoff else done_tasks(holder));
    return out;
}


# The same readers for one project, which a project-scoped walker visits.
def project_tasks_in(p: Project, said: str) -> list[Task] {
    return [p-->[?:Task, category==said]];
}


def project_open(p: Project) -> list[Task] {
    return [p-->[?:Task, status!="Done"]];
}


def project_done(p: Project) -> list[Task] {
    return [p-->[?:Task, status=="Done"]];
}


def project_done_in(p: Project, said: str) -> list[Task] {
    return [p-->[?:Task, status=="Done", category==said]];
}


def project_done_since(p: Project, since: str) -> list[Task] {
    return [p-->[?:Task, status=="Done", done_at>=since]];
}


def project_done_before(p: Project, cutoff: str) -> list[Task] {
    if not cutoff {
        return [];
    }
    return [p-->[?:Task, status=="Done", done_at<cutoff]];
}


# The history in updated order, for a page the store cuts: the first `n`
# rows, newest first, and every row stamped exactly `at` (the tie at a
# page's end). "Done" is Done before `cutoff` (the done scope passes a date
# no task reaches). Across the projects, or under one.
def recent_tasks(holder: Root, n: int) -> list[Task] {
    out: list[Task] = [];
    for box in [holder-->[?:Projects]] {
        out.extend([box-->[?:Project]-->[?:Task, -updated_at]][:n]);
    }
    return out;
}


def tasks_stamped(holder: Root, at: str) -> list[Task] {
    out: list[Task] = [];
    for box in [holder-->[?:Projects]] {
        out.extend([box-->[?:Project]-->[?:Task, updated_at==at]]);
    }
    return out;
}


def recent_done_before(holder: Root, cutoff: str, n: int) -> list[Task] {
    out: list[Task] = [];
    for box in [holder-->[?:Projects]] {
        out.extend(
            [box-->[?:Project]-->[?:Task, status=="Done", done_at<cutoff, -updated_at]][:n]
        );
    }
    return out;
}


def done_before_stamped(holder: Root, cutoff: str, at: str) -> list[Task] {
    out: list[Task] = [];
    for box in [holder-->[?:Projects]] {
        out.extend(
            [box-->[?:Project]-->[?:Task, status=="Done", done_at<cutoff, updated_at==at]]
        );
    }
    return out;
}


def project_recent(p: Project, n: int) -> list[Task] {
    return [p-->[?:Task, -updated_at]][:n];
}


def project_stamped(p: Project, at: str) -> list[Task] {
    return [p-->[?:Task, updated_at==at]];
}


def project_recent_done_before(p: Project, cutoff: str, n: int) -> list[Task] {
    return [p-->[?:Task, status=="Done", done_at<cutoff, -updated_at]][:n];
}


def project_done_before_stamped(p: Project, cutoff: str, at: str) -> list[Task] {
    return [p-->[?:Task, status=="Done", done_at<cutoff, updated_at==at]];
}


def project_done_before_in(p: Project, cutoff: str, said: str) -> list[Task] {
    if not cutoff {
        return [];
    }
    return [p-->[?:Task, status=="Done", done_at<cutoff, category==said]];
}


def project_working(p: Project, cutoff: str) -> list[Task] {
    out = project_open(p);
    out.extend(project_done_since(p, cutoff) if cutoff else project_done(p));
    return out;
}


# Rows the flow line walkers rewrite: every task on one step, on any of a
# list of steps, or on a step with a status other than the one it maps to.
def tasks_on_step(holder: Root, step: str) -> list[Task] {
    out: list[Task] = [];
    for box in [holder-->[?:Projects]] {
        out.extend([box-->[?:Project]-->[?:Task, step_id==step]]);
    }
    return out;
}


def tasks_on_steps(holder: Root, step_ids: list[str]) -> list[Task] {
    out: list[Task] = [];
    for step in step_ids {
        out.extend(tasks_on_step(holder, step));
    }
    return out;
}


def mismatched_on_step(holder: Root, step: str, landing: str) -> list[Task] {
    out: list[Task] = [];
    for box in [holder-->[?:Projects]] {
        out.extend([box-->[?:Project]-->[?:Task, step_id==step, status!=landing]]);
    }
    return out;
}


def tasks_in_iteration(holder: Root, it_id: str) -> list[Task] {
    out: list[Task] = [];
    for box in [holder-->[?:Projects]] {
        out.extend([box-->[?:Project]-->[?:Task, iteration_id==it_id]]);
    }
    return out;
}


# The Done tasks whose span (task_span in the iterations service) can
# overlap [lo, hi]: due or start inside the window, one on each side of it,
# or an iteration touching it. A superset on purpose: the caller applies
# the exact span test, so these only have to be cheap and complete. The
# iteration ids are few, so each is its own query.
def done_in_window(
    holder: Root,
    lo: str,
    hi: str,
    window_ids: list[str],
    after_ids: list[str],
    before_ids: list[str]
) -> list[Task] {
    seen: dict[str, bool] = {};
    out: list[Task] = [];
    for box in [holder-->[?:Projects]] {
        found: list[Task] = [];
        found.extend(
            [box-->[?:Project]-->[?:Task, status=="Done", due_date>=lo, due_date<=hi]]
        );
        found.extend(
            [box-->[?:Project]-->[?:Task, status=="Done", start_date>=lo, start_date<=hi]]
        );
        found.extend(
            [box-->[?:Project]-->[?:Task, status=="Done", start_date!="", start_date<lo, due_date>hi]]
        );
        found.extend(
            [box-->[?:Project]-->[?:Task, status=="Done", due_date!="", due_date<lo, start_date>hi]]
        );
        for it_id in window_ids {
            found.extend(
                [box-->[?:Project]-->[?:Task, status=="Done", iteration_id==it_id]]
            );
        }
        for it_id in after_ids {
            found.extend(
                [box-->[?:Project]-->[?:Task, status=="Done", start_date!="", start_date<lo, iteration_id==it_id]]
            );
        }
        for it_id in before_ids {
            found.extend(
                [box-->[?:Project]-->[?:Task, status=="Done", due_date!="", due_date>hi, iteration_id==it_id]]
            );
        }
        for t in found {
            if jid(t) not in seen {
                seen[jid(t)] = True;
                out.append(t);
            }
        }
    }
    return out;
}


# GitHub lookups by the machine key, per page of items rather than per
# workspace. `numbers` are the issue or PR numbers on the page: a short
# list is one query per number; a long one is one query over the numbers'
# range, kept to the page in Python. (A pushed `in` list would be one
# query, but the pinned formatter mangles `in` inside a filter.)
glob LOOKUP_ONE_BY_ONE: int = 8;


def number_range(numbers: list[int]) -> list[int] {
    lo = numbers[0];
    hi = numbers[0];
    for n in numbers {
        if n < lo {
            lo = n;
        }
        if n > hi {
            hi = n;
        }
    }
    return [lo, hi];
}


def tasks_by_issue(holder: Root, full_name: str, numbers: list[int]) -> list[Task] {
    out: list[Task] = [];
    if not numbers {
        return out;
    }
    if len(numbers) <= LOOKUP_ONE_BY_ONE {
        for box in [holder-->[?:Projects]] {
            for n in numbers {
                out.extend(
                    [box-->[?:Project]-->[?:Task, gh_repo==full_name, gh_issue_number==n]]
                );
            }
        }
        return out;
    }
    (lo, hi) = number_range(numbers);
    wanted: dict[int, bool] = {};
    for n in numbers {
        wanted[n] = True;
    }
    for box in [holder-->[?:Projects]] {
        for t in [box-->[?:Project]-->[?:Task, gh_repo==full_name, gh_issue_number>=lo, gh_issue_number<=hi]] {
            if t.gh_issue_number in wanted {
                out.append(t);
            }
        }
    }
    return out;
}


def tasks_by_pr(holder: Root, full_name: str, numbers: list[int]) -> list[Task] {
    out: list[Task] = [];
    if not numbers {
        return out;
    }
    if len(numbers) <= LOOKUP_ONE_BY_ONE {
        for box in [holder-->[?:Projects]] {
            for n in numbers {
                out.extend(
                    [box-->[?:Project]-->[?:Task, gh_repo==full_name, pr_number==n]]
                );
            }
        }
        return out;
    }
    (lo, hi) = number_range(numbers);
    wanted: dict[int, bool] = {};
    for n in numbers {
        wanted[n] = True;
    }
    for box in [holder-->[?:Projects]] {
        for t in [box-->[?:Project]-->[?:Task, gh_repo==full_name, pr_number>=lo, pr_number<=hi]] {
            if t.pr_number in wanted {
                out.append(t);
            }
        }
    }
    return out;
}


# Tasks whose pr_link is one of `links`, any repo: the numbered ones by the
# number the link carries, the unnumbered ones from the small set the sync
# has not adopted yet. Exact on the link, so a cross-repo paste still hits.
def tasks_by_pr_link(holder: Root, links: list[str], numbers: list[int]) -> list[Task] {
    out: list[Task] = [];
    if not links {
        return out;
    }
    wanted: dict[str, bool] = {};
    for link in links {
        wanted[link] = True;
    }
    found: list[Task] = unnumbered_pr_links(holder);
    if numbers {
        (lo, hi) = number_range(numbers);
        for box in [holder-->[?:Projects]] {
            found.extend([box-->[?:Project]-->[?:Task, pr_number>=lo, pr_number<=hi]]);
        }
    }
    for t in found {
        if t.pr_link in wanted {
            out.append(t);
        }
    }
    return out;
}


# Hand-pasted PR links not yet adopted by the sync: pr_link set, no number.
# Self-shrinking, since adoption writes the number.
def unnumbered_pr_links(holder: Root) -> list[Task] {
    out: list[Task] = [];
    for box in [holder-->[?:Projects]] {
        out.extend([box-->[?:Project]-->[?:Task, pr_number==0, pr_link!=""]]);
    }
    return out;
}


# The children stamped under one GitHub parent issue.
def children_of(holder: Root, full_name: str, number: int) -> list[Task] {
    out: list[Task] = [];
    for box in [holder-->[?:Projects]] {
        out.extend(
            [box-->[?:Project]-->[?:Task, gh_parent_repo==full_name, gh_parent_number==number]]
        );
    }
    return out;
}


# The linked task of a repo synced longest ago, one row: where a sync
# without a cursor starts for a repo that only holds imported tasks.
def earliest_synced(holder: Root, full_name: str) -> list[Task] {
    out: list[Task] = [];
    for box in [holder-->[?:Projects]] {
        out.extend(
            [box-->[?:Project]-->[?:Task, gh_repo==full_name, gh_issue_number>0, gh_synced_at!="", gh_synced_at]][:1]
        );
    }
    out.sort(key=lambda (t: Task) { t.gh_synced_at; });
    return out[:1];
}


# Board columns for the drag order, each one bounded query: the top cards
# of a column (two, so a caller can skip the card being moved), the cards
# just below or above a sort position, and the whole column for the rare
# re-spread. A step column is `step_id`; the legacy column (no flow line)
# is a status with no step.
def step_column_peak(holder: Root, step: str) -> list[Task] {
    out: list[Task] = [];
    for box in [holder-->[?:Projects]] {
        out.extend([box-->[?:Project]-->[?:Task, step_id==step, -sort_order]][:2]);
    }
    out.sort(key=lambda (t: Task) { -t.sort_order; });
    return out[:2];
}


def step_column_below(holder: Root, step: str, bound: float) -> list[Task] {
    out: list[Task] = [];
    for box in [holder-->[?:Projects]] {
        out.extend(
            [box-->[?:Project]-->[?:Task, step_id==step, sort_order<bound, -sort_order]][:2]
        );
    }
    out.sort(key=lambda (t: Task) { -t.sort_order; });
    return out[:2];
}


def step_column_above(holder: Root, step: str, bound: float) -> list[Task] {
    out: list[Task] = [];
    for box in [holder-->[?:Projects]] {
        out.extend(
            [box-->[?:Project]-->[?:Task, step_id==step, sort_order>bound, sort_order]][:2]
        );
    }
    out.sort(key=lambda (t: Task) { t.sort_order; });
    return out[:2];
}


def step_column(holder: Root, step: str) -> list[Task] {
    return tasks_on_step(holder, step);
}


def status_column_peak(holder: Root, col: str) -> list[Task] {
    out: list[Task] = [];
    for box in [holder-->[?:Projects]] {
        out.extend(
            [box-->[?:Project]-->[?:Task, status==col, step_id=="", -sort_order]][:2]
        );
    }
    out.sort(key=lambda (t: Task) { -t.sort_order; });
    return out[:2];
}


def status_column_below(holder: Root, col: str, bound: float) -> list[Task] {
    out: list[Task] = [];
    for box in [holder-->[?:Projects]] {
        out.extend(
            [box-->[?:Project]-->[?:Task, status==col, step_id=="", sort_order<bound, -sort_order]][:2]
        );
    }
    out.sort(key=lambda (t: Task) { -t.sort_order; });
    return out[:2];
}


def status_column_above(holder: Root, col: str, bound: float) -> list[Task] {
    out: list[Task] = [];
    for box in [holder-->[?:Projects]] {
        out.extend(
            [box-->[?:Project]-->[?:Task, status==col, step_id=="", sort_order>bound, sort_order]][:2]
        );
    }
    out.sort(key=lambda (t: Task) { t.sort_order; });
    return out[:2];
}


def status_column(holder: Root, col: str) -> list[Task] {
    out: list[Task] = [];
    for box in [holder-->[?:Projects]] {
        out.extend([box-->[?:Project]-->[?:Task, status==col, step_id==""]]);
    }
    return out;
}


# The highest sort_order among tasks of one status, step or not: where the
# GitHub sync appends a filed or auto-moved card.
def status_peak(holder: Root, col: str) -> float {
    peak = 0.0;
    for box in [holder-->[?:Projects]] {
        for t in [box-->[?:Project]-->[?:Task, status==col, -sort_order]][:1] {
            if t.sort_order > peak {
                peak = t.sort_order;
            }
        }
    }
    return peak;
}


# ------------------------------------------------------------ task tallies

# A Done task created already Done (a closed issue filed by a back-fill, a
# task created straight into Done): history, not throughput.
def seeded_done(t: Task) -> bool {
    return t.status == "Done" and bool(t.done_at) and t.done_at == t.created_at;
}


# The project a task hangs under: the link field when it is filled, else
# the container edge (a row ensure_tallies has not touched yet).
def task_project(t: Task) -> list[Project] {
    if t.project_id {
        p = resolve(t.project_id);
        if isinstance(p, Project) {
            return [p];
        }
    }
    return [t<--[?:Project]];
}


# A task joining (+1) or leaving (-1) a project's tallies, as it stands now.
def count_task(p: Project, t: Task, delta: int) {
    p.task_total = p.task_total + delta;
    if t.status == "Done" {
        p.done_total = p.done_total + delta;
        if seeded_done(t) {
            p.seeded_done_total = p.seeded_done_total + delta;
        }
    }
    days = history_days(t);
    shift_history(p, [] if delta > 0 else days, days if delta > 0 else []);
}


# Where a task counts in the Overview's history, as [added day, finished
# day], "" where it does not: added the day it was made, unless it was made
# already Done; finished the day it reached Done (never before it was made).
def history_days(t: Task) -> list[str] {
    if seeded_done(t) {
        return ["", ""];
    }
    finished = "";
    if t.status == "Done" {
        day = (t.done_at or t.updated_at)[:10];
        made = t.created_at[:10];
        finished = made if made and day < made else day;
    }
    return [t.created_at[:10], finished];
}


# Move a task's weekly counts from `before` to `after` (history_days of the
# task before and after a write; [] for not counted). Each dict is rebuilt
# and assigned, so the write is tracked like any field.
def shift_history(p: Project, before: list[str], after: list[str]) {
    if not p.history_at or before == after {
        return;
    }
    added = dict(p.week_added);
    finished = dict(p.week_finished);
    if before {
        bump_week(added, before[0], -1);
        bump_week(finished, before[1], -1);
    }
    if after {
        bump_week(added, after[0], 1);
        bump_week(finished, after[1], 1);
    }
    p.week_added = added;
    p.week_finished = finished;
}


def bump_week(counts: dict[str, int], day: str, delta: int) {
    week = week_start(day);
    if not week {
        return;
    }
    n = (counts[week] if week in counts else 0) + delta;
    if n > 0 {
        counts[week] = n;
    } elif week in counts {
        del counts[week];
    }
}


# The Monday on or before an ISO date, "" for anything else. Plain integer
# arithmetic on days since 1970-01-01 (a Thursday), after H. Hinnant's
# civil-date algorithms, since this module imports no Python.
def week_start(day: str) -> str {
    if len(day) < 10 or day[4] != "-" or day[7] != "-" {
        return "";
    }
    for c in day[0:4] + day[5:7] + day[8:10] {
        if not c.isdigit() {
            return "";
        }
    }
    y = int(day[0:4]);
    m = int(day[5:7]);
    d = int(day[8:10]);
    if m < 1 or m > 12 or d < 1 or d > 31 {
        return "";
    }
    yy = y - 1 if m <= 2 else y;
    era = yy // 400;
    yoe = yy - era * 400;
    doy = (153 * (m - 3 if m > 2 else m + 9) + 2) // 5 + d - 1;
    doe = yoe * 365 + yoe // 4 - yoe // 100 + doy;
    z = era * 146097 + doe - 719468;
    z = z - (z + 3) % 7;
    z = z + 719468;
    era = z // 146097;
    doe = z - era * 146097;
    yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365;
    doy = doe - (365 * yoe + yoe // 4 - yoe // 100);
    mp = (5 * doy + 2) // 153;
    dd = doy - (153 * mp + 2) // 5 + 1;
    mm = mp + 3 if mp < 10 else mp - 9;
    year = yoe + era * 400 + (1 if mm <= 2 else 0);
    return str(year).zfill(4) + "-" + str(mm).zfill(2) + "-" + str(dd).zfill(2);
}


# Sums over every project, as [tasks, done, seeded done].
def tally_totals(holder: Root) -> list[int] {
    total = 0;
    done = 0;
    seeded = 0;
    for p in projects_of(holder) {
        total = total + p.task_total;
        done = done + p.done_total;
        seeded = seeded + p.seeded_done_total;
    }
    return [total, done, seeded];
}


# The category list on the first Projects box; sorted for the client.
def categories_of(holder: Root) -> list[str] {
    boxes = [holder-->[?:Projects]];
    cats = list(boxes[0].categories) if boxes else [];
    cats.sort();
    return cats;
}


def note_category(holder: Root, said: str) {
    boxes = [holder-->[?:Projects]];
    if said and boxes and said not in boxes[0].categories {
        boxes[0].categories = boxes[0].categories + [said];
    }
}


# Drop `said` from the box unless a task other than `except_id` still
# carries it: two rows at most are read, never the history.
def forget_category(holder: Root, said: str, except_id: str) {
    boxes = [holder-->[?:Projects]];
    if not said or not boxes or said not in boxes[0].categories {
        return;
    }
    others = 0;
    for t in [boxes[0]-->[?:Project]-->[?:Task, category==said, created_at]][:2] {
        if jid(t) != except_id {
            others = others + 1;
        }
    }
    if others == 0 {
        boxes[0].categories = [
            c
            for c in boxes[0].categories
            if c != said
        ];
    }
}


# Move a task under another project: the container edge IS the project
# link, so the link field and both projects' tallies follow it.
def rehome_task(task: Task, target: Project) {
    for p in [task<--[?:Project]] {
        count_task(p, task, -1);
    }
    for e in [edge task<--] {
        del e;
    }
    target ++> task;
    task.project_id = jid(target);
    count_task(target, task, 1);
}


# Get-or-create, one per kind. A writer visits the box it returns and works
# there; a read looks the box up itself so a GET never writes.
def projects_box(holder: Root) -> Projects {
    found = [holder-->[?:Projects]];
    if found {
        return found[0];
    }
    box = holder ++> Projects();
    on_attached(holder, box);
    return box;
}


def members_box(holder: Root) -> Members {
    found = [holder-->[?:Members]];
    if found {
        return found[0];
    }
    box = holder ++> Members();
    on_attached(holder, box);
    return box;
}


def roles_box(holder: Root) -> Roles {
    found = [holder-->[?:Roles]];
    if found {
        return found[0];
    }
    box = holder ++> Roles();
    on_attached(holder, box);
    return box;
}


def iterations_box(holder: Root) -> Iterations {
    found = [holder-->[?:Iterations]];
    if found {
        return found[0];
    }
    box = holder ++> Iterations();
    on_attached(holder, box);
    return box;
}


def steps_box(holder: Root) -> WorkflowSteps {
    found = [holder-->[?:WorkflowSteps]];
    if found {
        return found[0];
    }
    box = holder ++> WorkflowSteps();
    on_attached(holder, box);
    return box;
}


def logs_box(holder: Root) -> Logs {
    found = [holder-->[?:Logs]];
    if found {
        return found[0];
    }
    box = holder ++> Logs();
    on_attached(holder, box);
    return box;
}


# The names a task row shows for its link fields: member and project names
# by jid, read once from the two roster-sized lists. No task is loaded.
obj TaskNames {
    has members: dict[str, str] = {},
        projects: dict[str, str] = {};

    # The assignee ids the roster still knows, in the task's own order.
    def ids_of(t: Task) -> list[str] {
        return [
            who
            for who in t.assignee_ids
            if who in self.members
        ];
    }

    def names_of(t: Task) -> list[str] {
        return [self.members[who] for who in self.ids_of(t)];
    }

    # Comma-joined assignee names for one task, "" when unassigned.
    def named(t: Task) -> str {
        return ", ".join(self.names_of(t));
    }

    # Project name for one task, "" when the task is unfiled.
    def project_of(t: Task) -> str {
        return self.projects[t.project_id] if t.project_id in self.projects else "";
    }
}

def task_names(holder: Root) -> TaskNames {
    names = TaskNames();
    for m in members_of(holder) {
        names.members[jid(m)] = m.full_name();
    }
    for p in projects_of(holder) {
        names.projects[jid(p)] = p.name;
    }
    return names;
}


# Rows for a page of tasks from names already gathered.
def rows_from(names: TaskNames, tasks: list[Task]) -> list[TaskRow] {
    rows: list[TaskRow] = [];
    for t in tasks {
        rows.append(
            t.row_with(
                names.ids_of(t), names.names_of(t), t.project_id, names.project_of(t)
            )
        );
    }
    return rows;
}


# Rows for a page of tasks, gathering the names itself. Use `rows_from`
# when the caller already holds a TaskNames.
def hydrate_rows(holder: Root, tasks: list[Task]) -> list[TaskRow] {
    return rows_from(task_names(holder), tasks);
}


# One step's view. `steps` is the whole flow line: incoming ids are read off
# the other steps' transitions, and a transition to a step that no longer
# exists is left out.
def step_view(s: WorkflowStep, steps: list[WorkflowStep]) -> StepView {
    me = jid(s);
    known: list[str] = [];
    prev_ids: list[str] = [];
    for o in steps {
        known.append(jid(o));
        for t in o.transitions {
            if t["to"] == me and jid(o) not in prev_ids {
                prev_ids.append(jid(o));
            }
        }
    }
    next_ids: list[str] = [];
    next_labels: list[str] = [];
    next_carries: list[str] = [];
    for t in s.transitions {
        if t["to"] in known {
            next_ids.append(t["to"]);
            next_labels.append(t["label"]);
            next_carries.append(t["carries"]);
        }
    }
    return StepView(
        id=jid(s),
        name=s.name,
        kind=s.kind,
        color=s.color,
        owner=s.owner,
        blurb=s.blurb,
        x=s.x,
        y=s.y,
        sort_order=s.sort_order,
        prev_ids=prev_ids,
        next_ids=next_ids,
        next_labels=next_labels,
        next_carries=next_carries
    );
}


# A member's role names, in the roles' own order.
def member_roles(m: Member) -> list[str] {
    held = [m->:HasRole:->];
    held.sort(key=lambda (r: Role) { r.sort_order; });
    return [r.name for r in held];
}


def member_view(m: Member) -> MemberView {
    ids: list[str] = [];
    names: list[str] = [];
    for p in [m->:OnProject:->] {
        ids.append(jid(p));
        names.append(p.name);
    }
    return MemberView(
        id=jid(m),
        name=m.full_name(),
        first_name=m.first_name,
        last_name=m.last_name,
        roles=member_roles(m),
        email=m.email,
        github_username=m.github_username,
        tags=m.tags,
        color=m.color,
        active=m.active,
        project_ids=ids,
        project_names=names
    );
}
