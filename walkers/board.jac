"""The Board's API: one walker for everything the page renders. NEVER nest
`root spawn` here -- a nested walker's reports come back EMPTY (see
walkers/insights.jac). Everything traverses the caller's root directly."""

import from models {
    Project,
    Member,
    Task,
    Repo,
    Role,
    WorkflowStep,
    TaskView,
    MemberView,
    RepoView,
    RoleView,
    StepView,
    member_view,
    repo_view,
    role_view,
    step_view,
    task_links,
    views_from,
    all_tasks,
    projects_of,
    members_of,
    roles_of
}
import from walkers.util { page_bounds, done_cutoff, is_older, order_working }
import from walkers.github { connection_of, connection_view }

obj BoardData {
    """One page of the board's working set, plus the workspace lists it
    renders. The workspace fields are filled only when `with_workspace` asks:
    they are edited on other pages, so the poll has no reason to refetch them."""
    has rows: list[TaskView],
        has_more: bool,
        older: int,
        categories: list[str],
        members: list[MemberView],
        projects: list[Project],
        steps: list[StepView],
        repos: list[RepoView],
        roles: list[RoleView],
        github_connected: bool;
}


walker BoardSnapshot {
    """The board in one call. `with_workspace` adds the roster, flow line and
    GitHub state the boot needs; the poll leaves it off and pays for the task
    walk alone."""
    has page: int = 1,
        page_size: int = 500,
        done_days: int = 7,
        with_workspace: bool = False,
        reports: list[BoardData] = [];

    can gather with Root entry {
        (p, size, start, end) = page_bounds(self.page, self.page_size, 50, 500);
        cutoff = done_cutoff(self.done_days);
        picked: list[Task] = [];
        older = 0;
        cats: list[str] = [];
        # Categories come out of the same walk that picks the page. The board
        # only ever read `categories` off TaskCounts, whose project and member
        # tallies it discarded.
        for t in all_tasks(here) {
            if t.category and t.category not in cats {
                cats.append(t.category);
            }
            if is_older(t, cutoff) {
                older = older + 1;
                continue;
            }
            picked.append(t);
        }
        cats.sort();
        # Sorts are stable, so the jid pass underneath the real key is what
        # keeps a row from swapping pages between two requests.
        picked.sort(key=lambda (t: Task) { jid(t); });
        order_working(picked);
        links = task_links(here);
        members: list[MemberView] = [];
        projects: list[Project] = [];
        steps: list[StepView] = [];
        repos: list[RepoView] = [];
        roles: list[RoleView] = [];
        connected = False;
        if self.with_workspace {
            for m in members_of(here) {
                members.append(member_view(m));
            }
            members.sort(key=lambda (m: MemberView) { m.name; });
            projects = projects_of(here);
            projects.sort(key=lambda (pr: Project) { pr.name; });
            for st in [here-->[?:WorkflowStep]] {
                steps.append(step_view(st));
            }
            steps.sort(key=lambda (s: StepView) { s.sort_order; });
            for r in [here-->[?:Repo]] {
                repos.append(repo_view(r));
            }
            repos.sort(key=lambda (rv: RepoView) { rv.full_name; });
            for ro in roles_of(here) {
                roles.append(role_view(ro));
            }
            roles.sort(key=lambda (rl: RoleView) { rl.sort_order; });
            connected = connection_view(connection_of(here)).connected;
        }
        report BoardData(
            rows=views_from(links, picked[start:end]),
            has_more=len(picked) > end,
            older=older,
            categories=cats,
            members=members,
            projects=projects,
            steps=steps,
            repos=repos,
            roles=roles,
            github_connected=connected
        );
    }
}
