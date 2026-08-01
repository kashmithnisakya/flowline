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

# v3 hook: when multi-PM orgs land, grant `fresh` to every root in
# org.pm_root_ids here. Deliberately a no-op in v2.
def on_attached(org: Organization, fresh: any) -> None {
    return;
}

# Parentage check: does this node hang directly under the caller's org?
# jobj/jid resolution is NOT authorization — every jid-addressed mutation
# calls this before touching anything.
def owned(org: any, target: any) -> bool {
    owners = [target<--[?:Organization]];
    return bool(owners) and jid(owners[0]) == jid(org);
}

# ---------------------------------------------------------------- archetypes

node Organization {
    has name: str,
        created_at: str = "",
        pm_root_ids: list[str] = [];
}

node Project {
    has name: str,
        description: str = "",
        active: bool = True;
}

node Member {
    has name: str,
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
            assignee_id=assignee_id, assignee_name=assignee_name,
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
        section: str = "",
        project_name: str = "";
}

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
        assignee_id: str,
        assignee_name: str,
        project_id: str,
        project_name: str;
}

obj MemberView {
    has id: str,
        name: str,
        role: str,
        email: str,
        github_username: str,
        section: str,
        active: bool,
        project_ids: list[str],
        project_names: list[str];
}

def member_view(m: Member) -> MemberView {
    ids: list[str] = [];
    names: list[str] = [];
    for p in [m ->:OnProject:->] {
        ids.append(jid(p));
        names.append(p.name);
    }
    return MemberView(
        id=jid(m), name=m.name, role=m.role, email=m.email,
        github_username=m.github_username, section=m.section,
        active=m.active, project_ids=ids, project_names=names
    );
}

