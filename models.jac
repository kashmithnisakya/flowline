"""flowline - persisted graph model and shared helpers. EVERY node/edge/obj
archetype lives HERE and must not move: archetype identity includes the module
path, so relocating a declaration orphans persisted data.
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

# Parentage check: does this node hang directly off the caller's root?
# jobj/jid resolution is NOT authorization — every jid-addressed mutation
# calls this first, or a guessed/leaked jid from another account would be
# mutable. The account IS the organization, so "my root" is the tenant line.
def owned(holder: any, target: any) -> bool {
    for owner in [target<--] {
        if jid(owner) == jid(holder) {
            return True;
        }
    }
    return False;
}

# ---------------------------------------------------------------- archetypes

node Project {
    has name: str,
        description: str = "",
        active: bool = True;
}

node Member {
    has name: str,
        roles: list[str] = [],
        email: str = "",
        github_username: str = "",
        tags: list[str] = [],
        active: bool = True;
}

node Repo {
    has full_name: str,
        # Auto-file new issues onto the entry step on every GitHub sync.
        # The cursor is the newest `updated_at` seen, so each sync asks
        # GitHub only for what changed since; empty means backfill.
        auto_sync: bool = False,
        issue_cursor: str = "";
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
        # GitHub identity. issue_link/pr_link stay the human URLs anyone can
        # paste by hand; these are the machine key the API syncs against.
        # gh_issue_number == 0 means "not linked to a real issue".
        gh_repo: str = "",
        gh_issue_number: int = 0,
        gh_issue_state: str = "",
        gh_synced_at: str = "",
        # GitHub sub-issue family, stamped by the sync. A parent carries its
        # summary counts; a child carries its parent's identity. Fields, not
        # edges: an edge would cost a traversal per row in every list.
        gh_parent_repo: str = "",
        gh_parent_number: int = 0,
        gh_sub_total: int = 0,
        gh_sub_done: int = 0,
        pr_number: int = 0,
        pr_state: str = "";

    # One task's view, hopping its own edges. Fine for a single task; for a
    # list use hydrate_views, which gets the same links in a few traversals
    # instead of three per row.
    def to_view -> TaskView {
        assignee_ids: list[str] = [];
        assignee_names: list[str] = [];
        for a in [self->:AssignedTo:->] {
            assignee_ids.append(jid(a));
            assignee_names.append(a.name);
        }
        project_id = "";
        project_name = "";
        projects = [self->:ForProject:->];
        if projects {
            project_id = jid(projects[0]);
            project_name = projects[0].name;
        }
        milestone_id = "";
        milestone_name = "";
        stones = [self->:InMilestone:->];
        if stones {
            milestone_id = jid(stones[0]);
            milestone_name = stones[0].title;
        }
        return self.view_with(
            assignee_ids,
            assignee_names,
            project_id,
            project_name,
            milestone_id,
            milestone_name
        );
    }

    # The view given links the caller already has. The field list lives here
    # once, so to_view and hydrate_views cannot drift apart.
    def view_with(
        assignee_ids: list[str],
        assignee_names: list[str],
        project_id: str,
        project_name: str,
        milestone_id: str,
        milestone_name: str
    ) -> TaskView {
        return TaskView(
            id=jid(self),
            title=self.title,
            category=self.category,
            priority=self.priority,
            status=self.status,
            step_id=self.step_id,
            due_date=self.due_date,
            notes=self.notes,
            created_at=self.created_at,
            updated_at=self.updated_at,
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
            milestone_id=milestone_id,
            milestone_name=milestone_name,
            gh_repo=self.gh_repo,
            gh_issue_number=self.gh_issue_number,
            gh_issue_state=self.gh_issue_state,
            gh_synced_at=self.gh_synced_at,
            gh_parent_repo=self.gh_parent_repo,
            gh_parent_number=self.gh_parent_number,
            gh_sub_total=self.gh_sub_total,
            gh_sub_done=self.gh_sub_done,
            pr_number=self.pr_number,
            pr_state=self.pr_state
        );
    }
}

node LogDay {
    has date: str;
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
        project_name: str = "";
}

# An org-defined vocabulary term (kind: "category" or "tag"), seeded in
# the setup wizard and managed on the Workspace tab.
node VocabTerm {
    has kind: str,
        value: str;
}

# A phase on a project's roadmap. Dates are optional: an undated milestone
# is a named bucket of work that has not been scheduled yet, and the
# timeline lists those separately rather than guessing a position.
node Milestone {
    has title: str,
        description: str = "",
        start_date: str = "",
        due_date: str = "",
        status: str = "Planned",
        color: str = "",
        sort_order: float = 0.0,
        created_at: str = "",
        updated_at: str = "";
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
# Roles tab. Members and step owners hold role NAMES, so rename/delete
# walkers propagate by name rather than anything holding a jid to this node.
node Role {
    has name: str,
        blurb: str = "",
        color: str = "",
        sort_order: float = 0.0;
}

# `WorkflowStep` and `WorkflowMeta` keep their pre-rename names: an
# archetype's name is its identity, so renaming them orphans persisted data.

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
        created_at: str = "",
        updated_at: str = "";
}

# The flow line's own record: singleton per root, get-or-created. Steps stay
# flat off the root; this carries only what the graph itself cannot — the
# display name.
node WorkflowMeta {
    has name: str = "Flow line",
        # Which template seeded this flow line; "" means drawn from scratch
        # (or seeded before this field existed). The Roles tab keys on it: a
        # template with a `roles` list brings fixed roles, "" means
        # free-text roles.
        template_key: str = "";
}

edge HasRepo: Project --> Repo {}
edge AssignedTo: Task --> Member {}
edge Logged: LogDay --> LogEntry {}
edge By: LogEntry --> Member {}
edge ForProject: Task --> Project {}
edge OnProject: Member --> Project {}
edge OnRoadmap: Milestone --> Project {}
edge InMilestone: Task --> Milestone {}
# The arrow on the roadmap: this step leads to that one. The graph must stay
# acyclic (LinkSteps refuses anything that would close a loop), because both
# the layout and the "ready to start" signal are derived from depth.
edge LeadsTo: Milestone --> Milestone {}
# A flow line transition. Cycles are ALLOWED by design (review looping back
# to development is the point); only self-loops are refused, at link time.
# `label` is what has to be true to cross; empty on older transitions.
# `carries` is what moves across it, "issue" or "pr" (see CARRY_KINDS);
# empty means untagged and is what every pre-existing transition reads as.
edge FlowsTo: WorkflowStep --> WorkflowStep {
    has label: str = "",
        carries: str = "";
}

obj TaskView {
    has id: str,
        title: str,
        category: str,
        priority: str,
        status: str,
        due_date: str,
        notes: str,
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
        milestone_id: str = "",
        milestone_name: str = "",
        gh_repo: str = "",
        gh_issue_number: int = 0,
        gh_issue_state: str = "",
        gh_synced_at: str = "",
        gh_parent_repo: str = "",
        gh_parent_number: int = 0,
        gh_sub_total: int = 0,
        gh_sub_done: int = 0,
        pr_number: int = 0,
        pr_state: str = "";
}

# One page of tasks. `total` counts every row that matched the filters, not
# just this page, so a caller can say "50 of 1,417" without a second call.
obj TaskPage {
    has rows: list[TaskView] = [],
        page: int = 1,
        page_size: int = 50,
        has_more: bool = False,
        total: int = 0,
        # Working scope only: Done rows older than the cutoff, same filters.
        older: int = 0;
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
        roles: list[str],
        email: str,
        github_username: str,
        tags: list[str],
        active: bool,
        project_ids: list[str],
        project_names: list[str];
}

obj RepoView {
    has id: str,
        full_name: str,
        project_id: str,
        project_name: str,
        auto_sync: bool = False;
}

obj RoleView {
    has id: str,
        name: str,
        blurb: str,
        color: str,
        sort_order: float;
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
        # Index-aligned with next_ids: one FlowsTo traversal builds all three.
        next_labels: list[str] = [],
        next_carries: list[str] = [],
        # How much work is sitting here, counted per request in GetFlowLine
        # because it depends on the project filter the caller asked for.
        task_count: int = 0;
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
        auto_sync=r.auto_sync
    );
}


# Views for a page of tasks, with the assignee and project links gathered by
# walking IN from each Member and Project once. A per-task hop is a separate
# traversal and they dominate everything at list sizes: 50 rows cost three
# traversals each, while this costs one per member plus one per project no
# matter how long the page is.
def hydrate_views(holder: Root, rows: list[Task]) -> list[TaskView] {
    wanted: list[str] = [];
    for t in rows {
        wanted.append(jid(t));
    }
    ids: dict[str, list[str]] = {};
    names: dict[str, list[str]] = {};
    for m in [holder-->[?:Member]] {
        who = jid(m);
        for t in [m<-:AssignedTo:<-] {
            key = jid(t);
            if key not in ids {
                ids[key] = [];
                names[key] = [];
            }
            ids[key].append(who);
            names[key].append(m.name);
        }
    }
    proj_id: dict[str, str] = {};
    proj_name: dict[str, str] = {};
    for p in [holder-->[?:Project]] {
        pid = jid(p);
        for t in [p<-:ForProject:<-] {
            key = jid(t);
            proj_id[key] = pid;
            proj_name[key] = p.name;
        }
    }
    stone_id: dict[str, str] = {};
    stone_name: dict[str, str] = {};
    for ms in [holder-->[?:Milestone]] {
        sid = jid(ms);
        for t in [ms<-:InMilestone:<-] {
            key = jid(t);
            stone_id[key] = sid;
            stone_name[key] = ms.title;
        }
    }
    views: list[TaskView] = [];
    for t in rows {
        key = jid(t);
        views.append(
            t.view_with(
                ids[key] if key in ids else [],
                names[key] if key in names else [],
                proj_id[key] if key in proj_id else "",
                proj_name[key] if key in proj_name else "",
                stone_id[key] if key in stone_id else "",
                stone_name[key] if key in stone_name else ""
            )
        );
    }
    return views;
}


def step_view(s: WorkflowStep) -> StepView {
    prev_ids: list[str] = [];
    for p in [s<-:FlowsTo:<-] {
        prev_ids.append(jid(p));
    }
    next_ids: list[str] = [];
    for n in [s->:FlowsTo:->] {
        next_ids.append(jid(n));
    }
    # `[edge ...]` is how an edge's own fields are read.
    next_labels: list[str] = [];
    next_carries: list[str] = [];
    for e in [edge s->:FlowsTo:->] {
        next_labels.append(e.label);
        next_carries.append(e.carries);
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


def member_view(m: Member) -> MemberView {
    ids: list[str] = [];
    names: list[str] = [];
    for p in [m->:OnProject:->] {
        ids.append(jid(p));
        names.append(p.name);
    }
    return MemberView(
        id=jid(m),
        name=m.name,
        roles=m.roles,
        email=m.email,
        github_username=m.github_username,
        tags=m.tags,
        active=m.active,
        project_ids=ids,
        project_names=names
    );
}
