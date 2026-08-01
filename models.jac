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
        sort_order: float = 0.0;

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
            project_id=project_id, project_name=project_name
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
        tags: str = "",
        project_name: str = "";
}

# An org-defined vocabulary term (kind: "category" or "tag"), seeded in
# the setup wizard and managed on the Workspace tab.
node VocabTerm {
    has kind: str,
        value: str;
}

edge HasRepo: Project --> Repo {}
edge AssignedTo: Task --> Member {}
edge Logged: LogDay --> LogEntry {}
edge By: LogEntry --> Member {}
edge ForProject: Task --> Project {}
edge OnProject: Member --> Project {}

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
        project_name: str;
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

