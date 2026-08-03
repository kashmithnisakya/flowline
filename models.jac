"""standup - persisted graph model and shared helpers.

EVERY node/edge/obj archetype lives HERE and must not move: archetype
identity includes the module path, so relocating a declaration orphans
persisted data. Walkers live in walkers/ and import from this module.
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

# "org/repo" and nothing else. Repo names are interpolated straight into
# api.github.com paths, so a name carrying `..`, `?` or `#` could redirect a
# request to a different endpoint. Pure string work, so it lives here rather
# than in the Python-importing helpers and both the storage path and every
# API call can share one definition.
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
    has full_name: str;
}

node Task {
    has title: str,
        category: str,
        priority: str,
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
        pr_number: int = 0,
        pr_state: str = "";

    def to_view -> TaskView {
        assignee_ids: list[str] = [];
        assignee_names: list[str] = [];
        for a in [self ->:AssignedTo:->] {
            assignee_ids.append(jid(a));
            assignee_names.append(a.name);
        }
        project_id = "";
        project_name = "";
        projects = [self ->:ForProject:->];
        if projects {
            project_id = jid(projects[0]);
            project_name = projects[0].name;
        }
        milestone_id = "";
        milestone_name = "";
        stones = [self ->:InMilestone:->];
        if stones {
            milestone_id = jid(stones[0]);
            milestone_name = stones[0].title;
        }
        return TaskView(
            id=jid(self), title=self.title, category=self.category,
            priority=self.priority, status=self.status,
            due_date=self.due_date, notes=self.notes,
            created_at=self.created_at, updated_at=self.updated_at,
            sort_order=self.sort_order,
            assignee_ids=assignee_ids, assignee_names=assignee_names,
            issue_link=self.issue_link, pr_link=self.pr_link,
            reviewer_id=self.reviewer_id, reviewer_name=self.reviewer_name,
            review_due=self.review_due,
            project_id=project_id, project_name=project_name,
            milestone_id=milestone_id, milestone_name=milestone_name,
            gh_repo=self.gh_repo, gh_issue_number=self.gh_issue_number,
            gh_issue_state=self.gh_issue_state, gh_synced_at=self.gh_synced_at,
            pr_number=self.pr_number, pr_state=self.pr_state
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

# The org's GitHub App installation. Singleton per root, get-or-created.
#
# It stores an installation id, NOT a credential: API calls mint a one-hour
# installation token on demand (walkers/ghutil.jac) and keep it in process
# memory. `pending_state` is the one-shot CSRF nonce for an install round
# trip — without it, a forged callback could bind someone else's
# installation to this workspace.
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
        milestone_id: str = "",
        milestone_name: str = "",
        gh_repo: str = "",
        gh_issue_number: int = 0,
        gh_issue_state: str = "",
        gh_synced_at: str = "",
        pr_number: int = 0,
        pr_state: str = "";
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
        project_name: str;
}

obj MilestoneView {
    has id: str,
        title: str,
        description: str,
        start_date: str,
        due_date: str,
        status: str,
        color: str,
        sort_order: float,
        project_id: str,
        project_name: str,
        task_count: int = 0,
        done_count: int = 0,
        # Graph shape, computed per request in ListMilestones where every
        # step is in hand. `depth` is the row (longest path from a step with
        # no predecessor); `lane` is 0 on the spine and alternates -1, 1, -2,
        # 2 outward for branches. `ready` means every predecessor is Done, so
        # this is startable now.
        depth: int = 0,
        lane: int = 0,
        component: int = 0,
        ready: bool = False,
        blocked_by: int = 0,
        prev_ids: list[str] = [],
        next_ids: list[str] = [];
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
        id=jid(r), full_name=r.full_name,
        project_id=project_id, project_name=project_name
    );
}


def milestone_view(m: Milestone) -> MilestoneView {
    project_id = "";
    project_name = "";
    for p in [m ->:OnRoadmap:->] {
        project_id = jid(p);
        project_name = p.name;
    }
    total = 0;
    done = 0;
    for t in [m<-:InMilestone:<-] {
        total = total + 1;
        if t.status == "Done" {
            done = done + 1;
        }
    }
    prev_ids: list[str] = [];
    for p in [m<-:LeadsTo:<-] {
        prev_ids.append(jid(p));
    }
    next_ids: list[str] = [];
    for n in [m ->:LeadsTo:->] {
        next_ids.append(jid(n));
    }
    return MilestoneView(
        id=jid(m), title=m.title, description=m.description,
        start_date=m.start_date, due_date=m.due_date, status=m.status,
        color=m.color, sort_order=m.sort_order,
        project_id=project_id, project_name=project_name,
        task_count=total, done_count=done,
        prev_ids=prev_ids, next_ids=next_ids
    );
}


def member_view(m: Member) -> MemberView {
    ids: list[str] = [];
    names: list[str] = [];
    for p in [m ->:OnProject:->] {
        ids.append(jid(p));
        names.append(p.name);
    }
    return MemberView(
        id=jid(m), name=m.name, roles=m.roles, email=m.email,
        github_username=m.github_username, tags=m.tags,
        active=m.active, project_ids=ids, project_names=names
    );
}

