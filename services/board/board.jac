"""The Board's API: one walker for everything the page renders. NEVER nest
`root spawn` here -- a nested walker's reports come back EMPTY (see
services/insights/insights.jac). Everything traverses the caller's root directly."""

import from models {
    Project,
    Task,
    TaskRow,
    MemberView,
    RepoView,
    RoleView,
    StepView,
    IterationView,
    FilterSetView,
    FilterSets,
    GithubConnectionView,
    hydrate_rows,
    project_working,
    default_project,
    categories_of,
    resolve,
    owned
}
import from services.util { page_bounds, done_cutoff, order_working, ensure_tallies }
import from services.workspace.workspace { workspace_view }

obj BoardData {
    """One page of one project's working set, plus the workspace lists the
    board renders. `project_id` is the project the page was scoped to (the
    default when the request named none). The workspace fields are filled
    only when `with_workspace` asks: the poll has no reason to refetch them."""
    has rows: list[TaskRow],
        has_more: bool,
        older: int,
        project_id: str,
        categories: list[str],
        members: list[MemberView],
        projects: list[Project],
        steps: list[StepView],
        repos: list[RepoView],
        roles: list[RoleView],
        iterations: list[IterationView],
        github_connected: bool,
        webhook_live: bool,
        # The rest of WorkspaceView, so the board can prime the client's
        # workspace cache from its own result.
        flow_name: str,
        template_key: str,
        github: GithubConnectionView,
        filter_sets: list[FilterSetView],
        # The board's filters as the account left them (FilterSets.board),
        # the saved set they came from, and whether they were ever saved.
        board_filters: dict[str, str],
        board_set: str,
        board_saved: bool;
}


walker BoardSnapshot {
    """One project's board in one call. `project_id` picks the project; an
    empty, foreign, archived or unknown id falls back to the caller's own
    default project (the earliest created), and the report says which was
    used. `with_workspace` adds the roster, flow line, GitHub state and saved
    filters the boot needs; the poll leaves it off and pays for the working
    set alone. Only that set is loaded: `older` is the project's Done tally
    less the Done rows the cutoff kept, and `categories` is the workspace
    list the projects' box keeps on write."""
    has page: int = 1,
        page_size: int = 500,
        done_days: int = 7,
        project_id: str = "",
        with_workspace: bool = False,
        reports: list[BoardData] = [];

    can gather with Root entry {
        ensure_tallies(here);
        (p, size, start, end) = page_bounds(self.page, self.page_size, 50, 500);
        cutoff = done_cutoff(self.done_days);
        scoped: Project | None = None;
        if self.project_id {
            found = resolve(self.project_id);
            if isinstance(found, Project) and owned(here, found) and found.active {
                scoped = found;
            }
        }
        if scoped is None {
            scoped = default_project(here);
        }
        picked: list[Task] = [];
        older = 0;
        if scoped is not None {
            picked = project_working(scoped, cutoff);
            if cutoff {
                recent_done = 0;
                for t in picked {
                    if t.status == "Done" {
                        recent_done = recent_done + 1;
                    }
                }
                older = scoped.done_total - recent_done;
            }
        }
        # Sorts are stable, so the jid pass underneath the real key is what
        # keeps a row from swapping pages between two requests.
        picked.sort(key=lambda (t: Task) { jid(t); });
        order_working(picked);
        members: list[MemberView] = [];
        projects: list[Project] = [];
        steps: list[StepView] = [];
        repos: list[RepoView] = [];
        roles: list[RoleView] = [];
        iterations: list[IterationView] = [];
        connected = False;
        live = False;
        flow_name = "";
        template_key = "";
        github = GithubConnectionView();
        filter_sets: list[FilterSetView] = [];
        board_filters: dict[str, str] = {};
        board_set = "";
        board_saved = False;
        # One definition of the lists and their order, shared with
        # GetWorkspace, which the other pages read on their own.
        if self.with_workspace {
            ws = workspace_view(here);
            members = ws.members;
            projects = ws.projects;
            steps = ws.steps;
            repos = ws.repos;
            roles = ws.roles;
            iterations = ws.iterations;
            connected = ws.github_connected;
            live = ws.webhook_live;
            flow_name = ws.flow_name;
            template_key = ws.template_key;
            github = ws.github;
            filter_sets = ws.filter_sets;
            # A read never makes the box; writers take the first one.
            for box in [here-->[?:FilterSets]][:1] {
                board_filters = dict(box.board);
                board_set = box.board_set;
                board_saved = bool(box.board_at);
            }
        }
        report BoardData(
            rows=hydrate_rows(here, picked[start:end]),
            has_more=len(picked) > end,
            older=older,
            project_id=jid(scoped) if scoped is not None else "",
            categories=categories_of(here),
            members=members,
            projects=projects,
            steps=steps,
            repos=repos,
            roles=roles,
            iterations=iterations,
            github_connected=connected,
            webhook_live=live,
            flow_name=flow_name,
            template_key=template_key,
            github=github,
            filter_sets=filter_sets,
            board_filters=board_filters,
            board_set=board_set,
            board_saved=board_saved
        );
    }
}
