# Activity log

Read the activity trail task events write. Nothing writes an entry by hand:
creating, moving and checking off tasks, and GitHub imports, add the lines;
see [The activity log](../concepts/activity-log.md). Source:
`services/log/log.jac`.
{ .fl-lede }

::: walker ListLogEntries

**Reports** one [`LogPage`](types.md#logpage) of raw
[`LogEntry`](../concepts/data-graph.md#logentry) nodes for the inclusive date
range: `page_size` defaults to 200 and is capped at 500. Rows are ordered by
date (newest first), then stamp (newest first), then id, so a page fetched behind the first only adds rows below
what is on screen. The page is cut in the store, so a request loads its own
rows, not the whole range, and `total` comes from the days' counts. An empty
or inverted range, or a workspace with no log, reports an empty page.

`task_id` (optional) keeps only that task's entries before paging, in one
store query across the range's days (so a range of years costs the same as a
week), and `total` and `has_more` count that task alone. The task sheet's **Travel so far** reads
a task's history this way. An empty `task_id` returns every entry.

```bash
curl -X POST $BASE/walker/ListLogEntries -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"from_date": "2026-09-08", "to_date": "2026-09-14"}'
```

```json title="data.reports"
[
  {
    "rows": [
      {
        "_jac_id": "<entry-id>", "date": "2026-09-14", "at": "2026-09-14T09:41:07.512004Z",
        "activity": "Moved to Review & merge · Priya Raman", "task_id": "<task-id>",
        "task_title": "Write the migration plan", "category": "Docs", "repo": "",
        "issue_link": "", "pr_link": "https://github.com/acme/docs/pull/42",
        "status": "Review", "notes": "", "member_name": "Priya Raman",
        "tags": "backend", "project_name": "Docs site"
      }
    ],
    "page": 1, "page_size": 200, "has_more": false, "total": 1
  }
]
```

The Overview's log numbers (entries per week, per weekday and per person)
come from `logs` inside [`OverviewSnapshot`](insights.md#overviewsnapshot),
which reads the days' tallies rather than the entries.
