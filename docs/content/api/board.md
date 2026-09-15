# Board

One call gives the `/board` page everything it
renders. Source: `services/board/board.jac`.
{ .fl-lede }

::: walker BoardSnapshot

**Reports** exactly one [`BoardData`](types.md#boarddata), also for an empty
workspace.

The page calls it two ways:

| Call | `with_workspace` | What comes back |
| --- | --- | --- |
| Boot | `true` on the first page | Tasks plus members, projects, steps, repos, roles, iterations and whether GitHub is connected |
| Poll | `false` | Tasks and categories only; the workspace lists are `[]` and `github_connected` is `false` |

- `rows` is one page of the **working set**: open tasks plus Done tasks updated
  in the last `done_days` (default 7), ordered by `sort_order`. Tasks of
  archived projects are included.
- `older` counts the Done tasks the cutoff left out; `done_days <= 0` trims
  nothing.
- `categories` covers **every** task, older ones included, so a category filter
  built from it does not lose categories only old Done tasks carry.
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

**Columns** come from `steps` (a [`StepView`](types.md#stepview) list in
`sort_order`); with no steps the board falls back to the legacy statuses. See
[Where a task sits on the board](../concepts/flow-lines.md#where-a-task-sits-on-the-board).

`github_connected` is true whenever an installation is stored, even one marked
invalid; call [`GithubStatus`](github.md#githubstatus) for the detail.

## Deep links

| URL | Opens |
| --- | --- |
| `/board?task=<task id>` | That card's dialog (fetched with [`GetTask`](tasks.md#gettask) when it is not in the working set) |
| `/board?new=1` | The create-task dialog |

An already mounted board listens for the `flowline:open-task` and
`flowline:new-task` browser events instead; the command palette uses both.
