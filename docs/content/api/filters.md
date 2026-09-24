# Saved filters

The board's filters are kept on the account, so the board opens on them in any
browser, and a set of filters can be saved under a name and picked again from
the menu beside the page title, on the board and on `/tasks`. Source:
`services/filters/filters.jac`.
{ .fl-lede }

## Stored filters

A filter dict, on the account or on a saved set, keeps only the keys the page
knows, and only those set to something other than their default. Each page's
keys and defaults are a glob, shared by the client and the server's
validation. The board:

::: glob BOARD_FILTERS

| Key | Value |
| --- | --- |
| `project` | A project id |
| `assignee` | A member id |
| `priority` | `High`, `Medium` or `Low` |
| `category`, `tag` | The category or tag text |
| `estimate` | `yes` (estimated) or `no` (unestimated) |
| `iteration` | An iteration id, `current` or `none` |
| `done` | `hide` hides the Done column's recent tasks |

The tasks table stores its URL's keys, less the page number:

::: glob TASKS_FILTERS

| Key | Value |
| --- | --- |
| `scope` | `done`, `all` or `attention` |
| `project`, `assignee`, `step` | A project, member or step id |
| `priority`, `category`, `tag`, `estimate` | As on the board |
| `q` | The title search |
| `sort` | `title`, `step`, `priority`, `due` or `updated` |
| `dir` | `asc` or `desc` |

`/tasks?view=<set id>` opens a saved tasks set; the table keeps no view on the
account, since its URL already carries one.

A key the page does not know, a value equal to the default, or a value outside
the listed words is dropped, and every value is trimmed and capped at 200
characters. Ids are not checked: an id that names nothing filters out every
card, and the board drops a project, member or iteration that is no longer
there when it opens. The title search is never stored.

The sets ride on [`GetWorkspace`](board.md#getworkspace) as `filter_sets`, and
[`BoardSnapshot`](board.md#boardsnapshot) with `with_workspace` also carries
the account's `board_filters`, the set they came from (`board_set`) and
whether they were ever saved (`board_saved`). These walkers only write.

## Walkers

::: walker SetBoardFilters

The board calls this after every filter change, once the picking pauses.

**Reports** `{"ok": true, "filters": {...}, "set_id": "<set id or empty>"}`
with the filters as stored. `set_id` is kept only when it names one of this
account's board sets; anything else stores `""`.

```bash
curl -X POST $BASE/walker/SetBoardFilters -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"filters": {"project": "<project-id>", "priority": "High"}, "set_id": ""}'
```

::: walker SaveFilterSet

An empty `set_id` creates a set on `page` (`board` or `tasks`); otherwise the
addressed set takes the name and the filters. A rename sends the set's own
filters back.

**Reports** `{"ok": true, "set": FilterSetView}`, or one of:

| `error` | When |
| --- | --- |
| `invalid` | The name is empty once trimmed, or `page` is unknown |
| `empty` | Nothing is left to filter on once the filters are cleaned |
| `duplicate` | Another set on the page has the name, ignoring case (the two pages keep separate names) |
| `full` | The page already holds 50 sets |
| `not_found` | `set_id` is not one of this account's sets |

Runs of whitespace in the name collapse to one space, and the name is capped at
60 characters. Sets are listed by name.

::: walker DeleteFilterSet

**Reports** `{"ok": true, "deleted": "<set id>"}`, or `not_found`. The board's
stored filters stay; if they came from this set, `board_set` is cleared.
