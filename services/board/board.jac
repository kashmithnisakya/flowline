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
    working_tasks,
    tally_totals,
    categories_of
}
import from services.util { page_bounds, done_cutoff, order_working, ensure_tallies }
import from services.workspace.workspace { workspace_view }

obj BoardData {
    """One page of the board's working set, plus the workspace lists it
    renders. The workspace fields are filled only when `with_workspace` asks:
    they are edited on other pages, so the poll has no reason to refetch them."""
    has rows: list[TaskRow],
        has_more: bool,
        older: int,
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
    """The board in one call. `with_workspace` adds the roster, flow line,
    GitHub state and saved filters the boot needs; the poll leaves it off and
    pays for the working set alone. Only the working set is loaded: `older` is the Done
    tally less the Done rows the cutoff kept, and `categories` is the list
    the projects' box keeps on write."""
    has page: int = 1,
        page_size: int = 500,
        done_days: int = 7,
        with_workspace: bool = False,
        reports: list[BoardData] = [];

    can gather with Root entry {
        ensure_tallies(here);
        (p, size, start, end) = page_bounds(self.page, self.page_size, 50, 500);
        cutoff = done_cutoff(self.done_days);
        picked = working_tasks(here, cutoff);
        older = 0;
        if cutoff {
            recent_done = 0;
            for t in picked {
                if t.status == "Done" {
                    recent_done = recent_done + 1;
                }
            }
            older = tally_totals(here)[1] - recent_done;
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
