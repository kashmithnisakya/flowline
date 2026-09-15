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
| `working` (default) | Open tasks plus Done tasks updated in the last `done_days` | Board order (`sort_order`) |
| `older` | Done tasks updated before that cutoff | Newest update first |
| `done` | Every Done task | Newest update first |
| `attention` | Open tasks that are Blocked or past due | Blocked first, then soonest due date |
| `all` | Everything | Board order |

- `q` matches titles case-insensitively, ranked exact match, then prefix, then
  anywhere (newest update breaks ties).
- `sort` (`title`, `priority`, `status`, `category`, `estimate`, `due`,
  `created`, `updated`) with `sort_dir` (`asc`/`desc`) overrides the scope's
  order; the table view uses it.
- `older` is only filled on an unfiltered `working` page: it counts the Done
  rows the cutoff left out, so the board can show "+N older" without a second
  call.
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
        "gh_repo": "", "gh_issue_number": 0, "pr_state": ""
      }
    ],
    "page": 1, "page_size": 20, "has_more": false, "total": 1, "older": 0
  }
]
```

The row above is trimmed; see [`TaskView`](types.md#taskview) for every field.

::: walker GetTask h3

For a deep link to a card the board's working set does not hold (older history
or a search hit).

**Reports** one [`TaskView`](types.md#taskview), or nothing for an unknown or
foreign id.

::: walker TaskCounts h3

**Reports** one [`TaskTotals`](types.md#tasktotals) over the whole history: open,
overdue and blocked counts, Done per week for the four weeks ending in
`monday`'s week (oldest first), per-project and per-member tallies, and every
category in use. An empty `monday` counts from today.

## Writing

::: walker CreateTask h3

**Reports** the new [`TaskView`](types.md#taskview).
**No-op when** the title is blank, or `project_id` is empty, unknown, foreign or
archived. Every task needs a project.

- With a valid `step_id`, the task goes on that step and `status` is set from
  the step's kind; otherwise `status` (default `Backlog`) is used with no step.
- The card is appended to the end of its column.
- Assignees that are not owned members are skipped.
- Logs `Added to <status>`.

```bash
curl -X POST $BASE/walker/CreateTask -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title": "Write the migration plan", "project_id": "<project-id>",
       "priority": "High", "step_id": "<step-id>", "assignee_ids": ["<member-id>"],
       "due_date": "2026-09-18", "tags": ["q3"], "estimate": 3}'
```

::: walker UpdateTask h3

The task dialog's save. **It replaces every editable field**, so send the full
form, not a patch.

**Reports** the updated [`TaskView`](types.md#taskview).

- A valid `step_id` sets the step and the mapped status; an invalid one keeps
  the current step and uses `status` as given.
- `assignee_ids` replaces all assignees. A `reviewer_id` that is not an owned
  member clears the reviewer.
- A different owned `project_id` moves the card to that project; an empty or
  foreign one leaves it where it is.
- A status change logs `Moved to <status>`. Landing on Done closes the linked
  GitHub issue when the repo has close-on-done on.

::: walker MoveTask h3

The drag-and-drop and arrow-move endpoint. The server decides where the card
lands.

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
- Landing on Done closes the linked issue on close-on-done repos.

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

## Lookup base

The base the jid-addressed walkers above extend: it resolves the id, checks ownership and only then visits. It is not an HTTP endpoint.

::: walker find_task h3
