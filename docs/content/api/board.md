# Board

One call gives the `/board` page everything it renders: one project's work,
as the flow line's steps stacked top to bottom, each a group of task rows. Source: `services/board/board.jac`.
{ .fl-lede }

::: walker BoardSnapshot

**Reports** exactly one [`BoardData`](types.md#boarddata), also for an empty
workspace.

The page calls it two ways:

| Call | `with_workspace` | What comes back |
| --- | --- | --- |
| Boot | `true` on the first page | Tasks plus members, projects, steps, repos, roles, the [saved filter sets](filters.md) and the board's stored filters, and whether GitHub is connected |
| Poll | `false` | Tasks and categories only; the workspace lists are `[]` and `github_connected` is `false` |

- `project_id` picks the project. An empty, unknown, foreign or archived id
  falls back to the caller's default project (the earliest created), and the
  report's `project_id` says which one was used. A workspace with no project
  reports no rows.
- `rows` is one page of that project's **working set**: open tasks plus Done
  tasks that reached Done in the last `done_days` (default 7), ordered by
  `sort_order`. Only the working set is loaded.
- `older` counts the project's Done tasks the cutoff left out (its Done tally
  less the rows kept); `done_days <= 0` trims nothing. The Done group's footer
  pages through them with [`ListTasks`](tasks.md#listtasks).
- `categories` covers **every** task, older ones included, so a category filter
  built from it does not lose categories only old Done tasks carry. It is
  the list the projects' box keeps on every category write.
- There is no `total`, `page` or `page_size` in the report. Loop on
  `has_more`:

```jac
page_no = 1;
more = True;
while more {
    result = root spawn BoardSnapshot(page=page_no, page_size=500, with_workspace=page_no == 1);
    data = result.reports[0] if result.reports else None;
    more = data.has_more if data else False;
    page_no = page_no + 1;
}
```

!!! note "`page_size` defaults to 500"

    Omitting `page_size` gives the declared default of 500. An explicit `0`
    asks for the shared fallback of 50, and anything above 500 is clamped.

**Step groups** come from `steps` (a [`StepView`](types.md#stepview) list in
`sort_order`); with no steps the board falls back to the legacy statuses. A
strip of the same steps with their counts sits on top. A task moves by its
row's Move menu, by a drag onto a step group, or with M on a focused row. See
[Where a task sits on the board](../concepts/flow-lines.md#where-a-task-sits-on-the-board).

`github_connected` is true whenever an installation is stored, even one marked
invalid; the full view is `github` on [`GetWorkspace`](#getworkspace) or
[`GithubStatus`](github.md#githubstatus).

## The workspace

::: walker GetWorkspace

**Reports** exactly one [`WorkspaceView`](types.md#workspaceview): the six
lists `BoardSnapshot` carries with `with_workspace` (the saved filter sets
among them), in the same order, plus
the flow line's `flow_name` and `template_key` (what
[`GetFlowLineMeta`](flow-lines.md#getflowlinemeta) reports) and the connection
view `github` (what [`GithubStatus`](github.md#githubstatus) reports, no GitHub
call). Every page other than the board opens with it, fired together with its
own read, so a page never waits for one roster list after another.

## Deep links

| URL | Opens |
| --- | --- |
| `/board?task=<task id>` | That task in the task sheet (fetched with [`GetTask`](tasks.md#gettask) when it is not in the working set) |
| `/board?new=1` | The task sheet for a new task (setup lands here after applying a template) |

An already mounted board listens for the `flowline:open-task` and
`flowline:new-task` browser events instead; the command palette uses both.
