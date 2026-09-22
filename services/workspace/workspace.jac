"""The workspace read: the roster, projects, flow line, repos, roles,
iterations, saved filter sets and GitHub connection every page renders
beside its own rows,
in one call. BoardSnapshot fills its workspace fields from the same helper,
so the board and the other pages never disagree on a sort."""

import from jaclang.lib.effects { effects }
import from models {
    Project,
    Repo,
    WorkflowSteps,
    MemberView,
    RepoView,
    RoleView,
    StepView,
    IterationView,
    FilterSetView,
    GithubConnectionView,
    iteration_view,
    iterations_of,
    filter_set_view,
    filter_sets_of,
    member_view,
    repo_view,
    role_view,
    step_view,
    projects_of,
    members_of,
    roles_of,
    steps_of
}
import from services.github.github {
    connection_of,
    connection_view,
    ensure_bound,
    LIVE_WINDOW_MINUTES
}
import from services.util { minutes_since, ensure_tallies }

obj WorkspaceView {
    """The workspace part of BoardData plus the flow line's own record
    (GetFlowLineMeta) and the full connection view (GithubStatus), so a page
    needs no second call for either."""
    has members: list[MemberView],
        projects: list[Project],
        steps: list[StepView],
        repos: list[RepoView],
        roles: list[RoleView],
        iterations: list[IterationView],
        # Every page's saved filter sets, by name.
        filter_sets: list[FilterSetView],
        github_connected: bool,
        flow_name: str,
        template_key: str,
        github: GithubConnectionView,
        # A delivery reached the receiver inside the server's live window,
        # so the board polls its queue every 20 s; otherwise once per poll.
        webhook_live: bool;
}


# The one definition of the workspace lists and their order. `ensure_bound`
# rides along as it does on GithubStatus: a connected workspace with no index
# row claims its installation on its next read.
def workspace_view(holder: Root) -> WorkspaceView {
    members: list[MemberView] = [];
    for m in members_of(holder) {
        members.append(member_view(m));
    }
    members.sort(key=lambda (m: MemberView) { m.name; });
    projects = projects_of(holder);
    projects.sort(key=lambda (pr: Project) { pr.name; });
    steps: list[StepView] = [];
    line_steps = steps_of(holder);
    for st in line_steps {
        steps.append(step_view(st, line_steps));
    }
    steps.sort(key=lambda (s: StepView) { s.sort_order; });
    repos: list[RepoView] = [];
    for r in [holder-->[?:Repo]] {
        repos.append(repo_view(r));
    }
    repos.sort(key=lambda (rv: RepoView) { rv.full_name; });
    roles: list[RoleView] = [];
    for ro in roles_of(holder) {
        roles.append(role_view(ro));
    }
    roles.sort(key=lambda (rl: RoleView) { rl.sort_order; });
    iterations: list[IterationView] = [];
    for it in iterations_of(holder) {
        iterations.append(iteration_view(it));
    }
    iterations.sort(key=lambda (iv: IterationView) { iv.start_date; });
    filter_sets: list[FilterSetView] = [
        filter_set_view(fs) for fs in filter_sets_of(holder)
    ];
    filter_sets.sort(key=lambda (fv: FilterSetView) { fv.id; });
    filter_sets.sort(key=lambda (fv: FilterSetView) { fv.name.lower(); });
    # A read never makes the box: no box, the defaults.
    flow_name = "Flow line";
    template_key = "";
    for box in [holder-->[?:WorkflowSteps]] {
        flow_name = box.name;
        template_key = box.template_key;
    }
    c = connection_of(holder);
    ensure_bound(holder, c);
    github = connection_view(c);
    return WorkspaceView(
        members=members,
        projects=projects,
        steps=steps,
        repos=repos,
        roles=roles,
        iterations=iterations,
        filter_sets=filter_sets,
        github_connected=github.connected,
        flow_name=flow_name,
        template_key=template_key,
        github=github,
        webhook_live=github.connected
            and minutes_since(github.webhook_seen_at) < LIVE_WINDOW_MINUTES
    );
}


# The declared read GetWorkspace reports through, so the browser caches it;
# a write anywhere invalidates it. Its own helper on purpose: the effect
# pass did not see the decorator on workspace_view, which board.jac also
# imports, and the API gate pins this walker as cacheable per build.
@effects(
    reads=[
        "Member",
        "Project",
        "Role",
        "WorkflowSteps",
        "WorkflowStep",
        "Repo",
        "Iteration",
        "FilterSets",
        "FilterSet",
        "GithubConnection"
    ],
    writes=[]
)
def read_workspace(holder: Root) -> WorkspaceView {
    # The projects ride with their tallies (the Projects tab's open counts),
    # so a project from before the tallies existed is filled here, once.
    ensure_tallies(holder);
    return workspace_view(holder);
}


walker GetWorkspace {
    """Everything a page needs beside its own data, in one read: the lists
    BoardSnapshot carries with `with_workspace`, the flow line's name and
    template key, and the GitHub connection view. No GitHub call."""
    has reports: list[WorkspaceView] = [];

    can gather with Root entry {
        report read_workspace(here);
    }
}
