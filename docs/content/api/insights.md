# Insights

Deterministic numbers and queues computed where the data lives:
the Overview page in one call, and the workspace snapshot the assistant reads.
No LLM is involved. Source: `services/insights/insights.jac`.
{ .fl-lede }

::: walker OverviewSnapshot

Everything `/overview` renders, in one call.

**Reports** one [`OverviewData`](types.md#overviewdata):

| Field | Holds |
| --- | --- |
| `counts` | [`TaskTotals`](types.md#tasktotals), the same numbers as [`TaskCounts`](tasks.md#taskcounts) |
| `logs` | [`LogTotals`](types.md#logtotals), the same numbers as [`LogCounts`](log.md#logcounts) |
| `attention` | The first `attention_size` open tasks that are Blocked or past due, Blocked first, then soonest due |
| `attention_total` | How many tasks need attention in all |
| `members` | Every member (archived included), by name |
| `projects` | Every project node (archived included), by name |
| `review_queue` | Tasks in Review, longest waiting first |
| `aging` | Open tasks untouched for 7 days or more, oldest first |
| `blocked` | Blocked tasks with the reason from their latest Blocked log entry since `from_date` (or the task notes) |

`monday` anchors the week (today when empty). "Today" is the server's UTC day.
The burn-up and throughput charts come from a separate call,
[`TaskHistory`](tasks.md#taskhistory).

::: walker Digest

**Reports** one [`Snapshot`](types.md#snapshot) for the period `from_date` to
`to_date` (both default to today): headline counts, blocked and review queues,
aging and overdue work, per-person and per-project stats, and every log entry
in the period as an activity line. This is exactly the object the
[assistant](assistant.md) is given.

!!! info "How the snapshot counts"

    - `done_in_period` counts tasks that moved to Done on or after `from_date`
      (by `done_at`); a task created straight into Done counts nowhere, and
      an imported closed issue counts on the day GitHub closed it.
    - People are matched to tasks and log entries by name, on the
      comma-joined assignee names.
    - Project stats cover active projects and match tasks by project name.
    - Only active members appear under `people`.
