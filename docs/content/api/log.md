# Daily log

Read, count, add, edit and delete log entries. Most entries are
written by the board as tasks move; see [The
daily log](../concepts/daily-log.md) for how. Source: `services/log/log.jac`.
{ .fl-lede }

::: walker ListLogEntries

**Reports** one [`LogPage`](types.md#logpage) of raw
[`LogEntry`](../concepts/data-graph.md#logentry) nodes for the inclusive date
range: `page_size` defaults to 200 and is capped at 500. Rows are ordered by
date (newest first), then stamp (newest first), then id, which is the order
the log page shows, so a page fetched behind the first only adds rows below
what is on screen. The page is cut in the store, so a request loads its own
rows, not the whole range, and `total` comes from the days' counts. An empty
or inverted range, or a workspace with no log, reports an empty page.

`task_id` (optional) keeps only that task's entries before paging, filtered in
the store's query, so `total` and `has_more` count that task alone. The task sheet's **Travel so far** reads
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

::: walker LogCounts

**Reports** one [`LogTotals`](types.md#logtotals): entries per week for the four
weeks ending in `monday`'s week (oldest first), per day for that week, and per
person for that week. `member_name` is split on commas, so an entry with two
assignees counts for both. An empty `monday` starts the week today.

::: walker LogActivity

A hand-written entry.

**Reports** the new `LogEntry` node.
**No-op when** `date` is empty, or `member_id` is not an owned member
(archived members are allowed).
**Side effects** creates the `Logs` box and the day on first use, snapshots the
member's full name and tags and the project's name onto the entry, and links
the entry to the member with a `By` edge. The project id itself is not stored;
an unknown project leaves `project_name` empty.

::: walker UpdateLogEntry

**Reports** the updated `LogEntry` node.

!!! warning "Every editable field is overwritten"

    `activity`, `category`, `repo`, `issue_link`, `pr_link`, `status` and
    `notes` are all written, so an omitted field is blanked. Send the whole
    entry back. The date, time, author, tags, project and task link never
    change. Automatic entries can be edited too.

::: walker DeleteLogEntries

**Reports** `{"deleted": [<ids actually deleted>]}`. Unknown and foreign ids are
skipped silently, and an emptied day is left in place.

## Lookup base

The base the jid-addressed walkers above extend: it resolves the id, checks ownership and only then visits. It is not an HTTP endpoint.

::: walker find_log_entry h3
