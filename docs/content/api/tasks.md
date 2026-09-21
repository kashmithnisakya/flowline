# Tasks

Tasks are the cards on the board. Every write keeps the task's
flow line step and its legacy status in step, and every column change lands in
the daily log. Source: `services/tasks/tasks.jac`.
{ .fl-lede }

## Reading

::: walker ListTasks h3

**Reports** one [`TaskPage`](types.md#taskpage): `page_size` defaults to 50 and is
capped at 500.

| `scope` | Rows | Order |
| --- | --- | --- |
| `working` (default) | Open tasks plus Done tasks that reached Done in the last `done_days` | Board order (`sort_order`) |
| `older` | Done tasks that reached Done before that cutoff | Newest update first |
| `done` | Every Done task | Newest update first |
| `attention` | Open tasks that are Blocked or past due | Blocked first, then soonest due date |
| `all` | Everything | Board order |

- `q` matches titles case-insensitively, ranked exact match, then prefix, then
  anywhere (newest update breaks ties).
- `iteration_id` keeps tasks planned into that iteration; `"none"` keeps
  tasks in no iteration.
- `sort` (`title`, `priority`, `step`, `category`, `estimate`, `due`,
  `created`, `updated`) with `sort_dir` (`asc`/`desc`) overrides the scope's
  order; the table view uses it. `step` follows the board: column order
  (canvas `x`, then `sort_order`, with the same placement fallbacks), then
  board order within a column.
- `older` is only filled on an unfiltered `working` page: it counts the Done
  rows the cutoff left out (the Done tally less the rows the page kept), so
  a view can say how many it is not showing without a second call. Any
  filter, `project_id` and `assignee_id` included, reports 0.
- `scope_total` is the scope's count with no filter on (what `total` would
  be on an unfiltered page), on every page, so a filtered view can say
  "12 of 210" without a second call. It is the pool's size when the page
  loaded the whole scope; under a `project_id` or `category` filter it is a
  tally (`done`, `all`, `older`) or one more pushed read of the live scope.
- The scope and a `category` filter run in the store's query, so a working
  page loads the working set alone. An unfiltered `older`, `done` or `all`
  page in updated order, newest first (the table's default) is cut in the
  store too: it loads the rows up to the page's end, and `total` comes from
  the tallies. Any other sort, a search or a filter loads the history the
  page is taken from.
- A foreign or unknown `project_id` or `assignee_id` matches nothing.

```bash
curl -X POST $BASE/walker/ListTasks -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"scope": "all", "q": "migration", "page_size": 20}'
```

```json title="data.reports"
[
  {
    "rows": [
      {
        "id": "<task-id>", "title": "Write the migration plan", "category": "Docs",
        "priority": "High", "status": "In Progress", "step_id": "<step-id>",
        "due_date": "2026-09-18", "assignee_ids": ["<member-id>"],
        "assignee_names": ["Priya Raman"], "project_id": "<project-id>",
        "project_name": "Docs site", "tags": ["q3"], "estimate": 3.0,
        "iteration_id": "<iteration-id>", "start_date": "2026-09-15",
        "note_lead": "Rollback first, then the schema.", "checklist_done": 1, "checklist_total": 3,
        "gh_repo": "", "gh_issue_number": 0, "pr_state": ""
      }
    ],
    "page": 1, "page_size": 20, "has_more": false, "total": 1, "older": 0
  }
]
```

The row above is trimmed; see [`TaskRow`](types.md#taskrow) for every field.
A list row carries no `notes` and no `checklist` items: the note's first line
(`note_lead`, at most 200 characters) and the checklist counts ride instead,
and [`GetTask`](#gettask) has the rest.

::: walker GetTask h3

The task in full: what the task sheet loads when it opens, and a deep link to a
card the board's working set does not hold (older history or a search hit).

**Reports** one [`TaskView`](types.md#taskview), every `TaskRow` field plus
`notes`, the `checklist` items and the GitHub-only fields (`gh_assignees`,
`gh_synced_at`, `pr_review_state`), or nothing for an unknown or foreign id.

::: walker ListTaskTitles h3

The assistant's citation lookup: the working set as `id` and `title` only.

**Reports** one list of [`TaskTitle`](types.md#tasktitle): the rows and order of
`ListTasks(scope="working")` for the same `done_days`, at most `limit` (capped
at 500).

::: walker TaskCounts h3

**Reports** one [`TaskTotals`](types.md#tasktotals) over the whole history: open,
overdue and blocked counts, Done per week for the four weeks ending in
`monday`'s week (oldest first), per-project and per-member tallies, and every
category in use. An empty `monday` counts from today. Only the open tasks and
those four weeks of Done are loaded; each project's `total` and `done` are the
tallies it keeps on write, and `categories` is the list the projects' box
keeps.

::: walker TaskHistory h3

The Overview's charts over time.

**Reports** one [`WeeklyHistory`](types.md#weeklyhistory): for `weeks` weeks
(clamped to 4..52) ending in `monday`'s week, oldest first, the Monday of each
week, tasks `added` and `finished` that week, and running `scope` and `done`
totals at each week's end (tasks from before the window seed the totals).
`project_id` narrows it to one project; a foreign id reports empty history.
It reads each project's weekly counts, kept on every task write, so it costs
the same whatever the window; a project's first call fills them from one
full load, once. An empty `monday` means this week.
Only the window's rows are loaded (created or reached Done since its first
Monday); what came before is the project tallies less those rows.

!!! info "What counts as finished"

    A task's done day is `done_at`, the moment it last entered Done (older rows
    fall back to `updated_at`). A task **created** already Done, such as a
    closed issue filed by a GitHub back-fill, is history rather than
    throughput and counts nowhere. `TaskCounts` and the assistant's snapshot
    use the same rule, so every Done number agrees.

## Writing

::: walker CreateTask h3

**Reports** the new [`TaskView`](types.md#taskview).
**No-op when** the title is blank, or `project_id` is empty, unknown, foreign or
archived. Every task needs a project.

- With a valid `step_id`, the task goes on that step and `status` is set from
  the step's kind; otherwise `status` (default `Backlog`) is used with no step.
- `start_date` is stored as an ISO day (or `""`), and `iteration_id` only when
  it names an owned iteration.
- The card is appended to the end of its column.
- Assignees that are not owned members are skipped.
- Logs `Added to <status>`.

```bash
curl -X POST $BASE/walker/CreateTask -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title": "Write the migration plan", "project_id": "<project-id>",
       "priority": "High", "step_id": "<step-id>", "assignee_ids": ["<member-id>"],
       "due_date": "2026-09-18", "start_date": "2026-09-15",
       "iteration_id": "<iteration-id>", "tags": ["q3"], "estimate": 3}'
```

::: walker UpdateTask h3

The task sheet's save. **It replaces every editable field**, so send the full
form, not a patch: a caller that omits `start_date` or `iteration_id` clears
them. The checklist is the exception; only the [checklist walkers](#checklist)
write it.

**Reports** the updated [`TaskView`](types.md#taskview).

- A valid `step_id` sets the step and the mapped status; an invalid one keeps
  the current step and uses `status` as given.
- `assignee_ids` replaces all assignees. A `reviewer_id` that is not an owned
  member clears the reviewer.
- A different owned `project_id` moves the card to that project; an empty or
  foreign one leaves it where it is.
- A status change logs `Moved to <status>`. A change that crosses Done keeps a
  linked GitHub issue in step on repos with `auto_close` on: landing on
  Done closes it, leaving Done reopens it.

::: walker MoveTask h3

The endpoint behind a board drag and drop and the Move menu. The server
decides where the card lands.

**Reports** the moved [`TaskView`](types.md#taskview).
**No-op when** `step_id` is set but is not an owned step.

- With `step_id`, the card moves onto that step and gets its mapped status;
  `step_name` is only the label written to the log. Without it, a legacy
  status-only move clears the card's step.
- `before_id` or `after_id` places the card beside that card in the target
  column; a stale anchor appends to the end.
- A positioned drop in the card's **own** column is a pure reorder: no status
  write, no handoff, no log entry, no `updated_at` bump.
- Moving onto a different step whose owner role has exactly one holder on the
  task's project hands the card to that person.
- Crossing Done keeps a linked issue in step on `auto_close` repos:
  landing closes it (`· closed org/repo #12` on the log line), leaving reopens
  it (`· reopened org/repo #12`).

```bash
curl -X POST $BASE/walker/MoveTask -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"task_id": "<task-id>", "step_id": "<review-step-id>", "step_name": "Review & merge",
       "before_id": "<anchor-task-id>"}'
```

::: walker SetMoveInfo h3

The optional details a move to a handoff or blocked step asks for. Partial by
design: anything empty stays untouched.

**Reports** the updated [`TaskView`](types.md#taskview).

- `note` is **prepended** to the task's notes as `**YYYY-MM-DD:** note`, so a
  blocked card's excerpt leads with the reason; resubmitting the same line is a
  no-op.
- The same day's move entry in the log is patched with the new links and note.

::: walker DeleteTask h3

**Reports** `{"deleted": "<task id>"}`. Nothing is written to the log.

## Checklist

A task's checklist is a list of `{"id", "text", "done"}` items in display
order, stored on the task itself. Each change is applied at once by its own
walker and none of them touch the other task fields, so a sheet save cannot
clobber a checklist and a checklist edit cannot clobber the form. Every one
reports the task's [`TaskView`](types.md#taskview), changed or not, and nothing
for an unknown or foreign `task_id`.

::: walker AddChecklistItem h3

Appends an item with a new id. Text is trimmed and capped at 200 characters;
blank text, or a checklist already holding 50 items, adds nothing.

::: walker SetChecklistItem h3

`done` is `"yes"`, `"no"` or `""` (leave it); a non-blank `text` renames the
item. **Checking an item off writes a log entry** with the progress, such as
`Checked off: Draft the rollback steps (2/5)`. Unchecking and renaming do not.

```bash
curl -X POST $BASE/walker/SetChecklistItem -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"task_id": "<task-id>", "item_id": "3f9c1a2b7d4e", "done": "yes"}'
```

::: walker RemoveChecklistItem h3

Drops the item with that id; an unknown id removes nothing.

## Lookup base

The base the jid-addressed walkers above extend: it resolves the id, checks ownership and only then visits. It is not an HTTP endpoint.

::: walker find_task h3
