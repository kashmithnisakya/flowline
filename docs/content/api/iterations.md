# Iterations and roadmap

Iterations are the time boxes a team plans in. A task points at one through its
`iteration_id` field, and the `/roadmap` page lays tasks out on a timeline by
their dates or their iteration. Source: `services/iterations/iterations.jac`.
{ .fl-lede }

## Iterations

An `Iteration` is a name and an inclusive span of ISO days under the
`Iterations` box. A task plans into one with `iteration_id` on
[`CreateTask`](tasks.md#createtask) or [`UpdateTask`](tasks.md#updatetask) (an
id that is not an owned iteration stores `""`), and
[`ListTasks`](tasks.md#listtasks) filters by it: an iteration id, `"none"` for
tasks in no iteration, or `""` for any.

::: walker ListIterations

**Reports** one list of [`IterationView`](types.md#iterationview), earliest
start first. With no iterations yet, `[]` (a read never creates the box).

::: walker SaveIteration

An empty `iteration_id` creates an iteration; otherwise the addressed one is
updated.

**Reports** `{"ok": true, "iteration": IterationView}`, or one of:

```json
{ "ok": false, "error": "invalid", "message": "An iteration needs a name, a start and an end." }
```

```json
{ "ok": false, "error": "invalid", "message": "An iteration cannot end before it starts." }
```

```json
{ "ok": false, "error": "not_found", "message": "Unknown iteration." }
```

The name is trimmed and capped at 80 characters; both dates must parse as ISO
days (anything longer is cut to the day).

```bash
curl -X POST $BASE/walker/SaveIteration -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Sprint 14", "start_date": "2026-09-14", "end_date": "2026-09-25"}'
```

::: walker DeleteIteration

**Reports** `{"ok": true, "deleted": "<iteration id>", "cleared": <tasks>}`, or
`not_found`. Every task planned into the iteration has its `iteration_id`
cleared; the tasks themselves stay.

## Roadmap

::: walker RoadmapSnapshot

**Reports** one [`RoadmapData`](types.md#roadmapdata) for the window
`from_date` to `to_date`. A missing, malformed or inverted window reads as two
weeks back to eight weeks ahead of today.

A task's span on the timeline, in order of preference:

| Edge of the bar | Taken from |
| --- | --- |
| Start | The task's `start_date`, else its iteration's start, else its `due_date` |
| End | The task's `due_date`, else its iteration's end, else its `start_date` |

Swapped dates are put back in order. A task appears when its span overlaps the
window, sorted by start; `starts` and `ends` hold each row's span, index-aligned
with `rows`. At most 400 rows are returned (`truncated` says when more matched,
`total` how many). Open tasks with no date and no iteration are counted in
`unscheduled` instead. `project_id` narrows everything to one project; a
foreign id reports an empty roadmap.

```bash
curl -X POST $BASE/walker/RoadmapSnapshot -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"from_date": "2026-09-01", "to_date": "2026-11-23"}'
```

```json title="data.reports"
[
  {
    "from_date": "2026-09-01", "to_date": "2026-11-23",
    "iterations": [
      { "id": "<iteration-id>", "name": "Sprint 14", "start_date": "2026-09-14", "end_date": "2026-09-25" }
    ],
    "rows": [ { "id": "<task-id>", "title": "Write the migration plan", "iteration_id": "<iteration-id>", "start_date": "", "due_date": "2026-09-18" } ],
    "starts": ["2026-09-14"],
    "ends": ["2026-09-18"],
    "unscheduled": 7, "total": 1, "truncated": false
  }
]
```

The row above is trimmed; see [`TaskView`](types.md#taskview) for every field.
