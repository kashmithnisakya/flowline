# Roadmap

The `/roadmap` page lays one project's tasks out on a timeline by their start
and due dates. Source: `services/roadmap/roadmap.jac`.
{ .fl-lede }

::: walker RoadmapSnapshot

**Reports** one [`RoadmapData`](types.md#roadmapdata) for the window
`from_date` to `to_date`. A missing, malformed or inverted window reads as two
weeks back to eight weeks ahead of today.

`project_id` is required: a missing, unknown or foreign project reports an
empty roadmap. The project's open tasks are loaded, plus the Done tasks whose
dates touch the window, never the whole history.

A task's span on the timeline:

| Edge of the bar | Taken from |
| --- | --- |
| Start | The task's `start_date`, else its `due_date` |
| End | The task's `due_date`, else its `start_date` |

Swapped dates are put back in order. A task appears when its span overlaps the
window, sorted by start; `starts` and `ends` hold each row's span, index-aligned
with `rows`. At most 400 rows are returned (`truncated` says when more matched,
`total` how many). Open tasks with no date are counted in `unscheduled`
instead.

```bash
curl -X POST $BASE/walker/RoadmapSnapshot -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"project_id": "<project-id>", "from_date": "2026-09-01", "to_date": "2026-11-23"}'
```

```json title="data.reports"
[
  {
    "from_date": "2026-09-01", "to_date": "2026-11-23",
    "rows": [ { "id": "<task-id>", "title": "Write the migration plan", "start_date": "2026-09-14", "due_date": "2026-09-18" } ],
    "starts": ["2026-09-14"],
    "ends": ["2026-09-18"],
    "unscheduled": 7, "total": 1, "truncated": false
  }
]
```

The row above is trimmed; see [`TaskRow`](types.md#taskrow) for every field.
