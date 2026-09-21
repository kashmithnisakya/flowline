# GitHub

Connect a GitHub App installation, browse and import issues, watch pull
requests and run the reconcile poll. [GitHub sync](../concepts/github-sync.md)
explains the pipeline; [Connect GitHub](../get-started/github-app.md) covers
setup. Source: `services/github/github.jac`.
{ .fl-lede }

## Result shapes

Apart from `GithubStatus`, every walker here reports one dict with `ok`.

```json title="Not connected"
{ "ok": false, "error": "not_connected", "message": "Connect the GitHub App first." }
```

```json title="A GitHub call failed"
{ "ok": false, "status": 404, "error": "not_found", "message": "Not Found" }
```

| `error` | `status` | When |
| --- | --- | --- |
| `not_connected` | `0` | No installation token could be minted |
| `network` | `0` | GitHub could not be reached |
| `rate_limited` | `403` | GitHub's rate limit is exhausted |
| `unauthorized` | `401` | The installation token was refused. Marks the connection invalid. |
| `forbidden` | `403` | Any other 403 |
| `not_found` | `404` | Missing, or not visible to the installation. Marks the connection invalid. |
| `invalid` | `422` | GitHub rejected the request |
| `request_failed` | other | Any other non-2xx response |

`message` is GitHub's own message where it sent one. Exception text, headers
and raw bodies never cross back.

## Connection

::: walker GithubStatus h3

**Reports** one [`GithubConnectionView`](types.md#githubconnectionview), with no
GitHub call. Pages open with the same view on
[`GetWorkspace`](board.md#getworkspace); this is the read after a disconnect
or a sync.

- `configured` and `missing_config` say whether the server has the five App
  variables, and which are missing.
- `status` is `ok` or `invalid` (a reconnect is needed).
- `webhook_seen_at` is when a delivery for this installation last arrived;
  the `/github` connection strip shows "Live · last event N ago" from it.

It also re-binds a valid connection whose `gh_installations` row is missing.

::: walker StartGithubInstall h3

**Reports** `{"ok": true, "url": "https://github.com/apps/<slug>/installations/new?state=<nonce>"}`,
or `{"ok": false, "error": "not_configured", "message": "...", "missing": [...]}`.

Stores a one-shot nonce on the workspace's `GithubConnection` (creating it on
first use). Calling it again replaces the nonce, so only the newest link works.

::: walker CompleteGithubInstall h3

Called by the page when GitHub redirects back with `installation_id`, `code` and
`state`. Call it **once** per redirect: the OAuth code is single-use.

**Reports** `{"ok": true, "connection": GithubConnectionView}` or one of these
errors, checked in this order (the nonce is burned before the first check):

| `error` | Meaning |
| --- | --- |
| `no_pending_install` | No install was started from this workspace |
| `bad_state` | `state` does not match the stored nonce |
| `expired` | More than 15 minutes since `StartGithubInstall` |
| `invalid` | No installation id |
| `exchange_failed` | GitHub would not exchange the OAuth code (usually: OAuth during installation is off) |
| `not_yours` | The authorizing GitHub user cannot see that installation |

On success it binds the installation to this workspace, replacing any other
workspace's binding, and unbinds a previous installation this workspace held.

::: walker DisconnectGithub h3

**Reports** `{"ok": true, "disconnected": true}`, also when nothing was
connected. Forgets the installation, its cached token, its index row and its
queued deliveries. Repos, their flags, tasks and task links stay.

## Browsing GitHub

::: walker ListGithubRepos h3

**Reports** `{"ok": true, "rows": [GhRepoRow], "page": n, "has_more": bool}`.
One GitHub page (100 repos) granted to the installation, sorted by name.
`query` filters that page by substring after the fetch, so a filtered page can
be short. `attached` marks repos already added to a project.

::: walker ListRepoIssues h3

**Reports** `{"ok": true, "rows": [GhIssueRow], "page": n, "has_more": bool,
"synced_at": "...", "stale": bool}`, 50 per page. `state` is `open`, `closed`
or `all`. Page 1 is the page the [scheduled sync](../concepts/github-sync.md#what-the-github-page-reads)
stored for that state (`synced_at` is empty when none is stored yet, `stale`
past 20 minutes) and makes no GitHub call; `refresh: true` or `page > 1` reads
GitHub, and page 1 then replaces the stored one. Pull requests are dropped
from GitHub's issues list, so pages can be short. `already_imported` and
`imported_task_id` point at the task that holds the issue. A foreign `repo_id`
reports an empty page without calling GitHub.

::: walker ListRepoPulls h3

**Reports** the same shape with `[GhPrRow]` rows and the same stored-page
rule. `state` on each row is `open`, `draft`, `closed` or `merged`, and
`linked_task_id` finds a task by PR number or by a pasted PR link.

::: walker SearchRepoItems h3

GitHub search scoped to one repo, returning the same row shapes as the two list
walkers. `kind` is `issues` or `pulls`.

**Reports** `{"ok": true, "rows": [...], "page": n, "has_more": bool}`. A blank
`query` or foreign repo reports an empty page with no GitHub call. GitHub allows
about 30 searches a minute, so the client only searches on an explicit action.

## Importing and writing

::: walker ImportIssues h3

Turns chosen issues into tasks, once each (the repo and issue number are the
identity).

**Reports** `{"ok": true, "imported": [TaskView], "skipped": [n], "failed": [n]}`,
or `{"ok": false, "error": "not_found" | "project_required" | "not_connected", ...}`.

- Up to 25 numbers per call.
- The task goes under `project_id` if given, otherwise the repo's project.
- Open issues land on `step_id` (or `status`, default `Backlog`); closed issues
  land on the done step.
- Title, body (first 2,000 characters), labels as tags, and assignees matched
  to members by `github_username` are copied. The log records
  `Imported from GitHub org/repo #n` for a single issue, or grows the day's
  `Imported N issues from org/repo` line for more.
- `skipped` numbers are already held by a task; `failed` ones errored or are
  pull requests.

```bash
curl -X POST $BASE/walker/ImportIssues -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"repo_id": "<repo-id>", "numbers": [41, 42, 57], "status": "Backlog"}'
```

::: walker CreateIssueFromTask h3

Opens a GitHub issue for a task. One way: later task edits do not touch the
issue.

**Reports** `{"ok": true, "task": TaskView}`, or an error dict
(`already_linked`, `not_found`, `not_connected`, `invalid`, or a GitHub
failure). Nothing is reported for an unknown or foreign `task_id`.
The issue body is the task's notes plus a "Tracked in Flowline." footer; the
task gets the issue number, state and link, and the log records
`Opened GitHub issue org/repo #n`.

## Per-repo policy

::: walker SetRepoAutoSync h3

**Reports** `{"ok": true, "repo": RepoView}` or
`{"ok": false, "error": "not_found", "message": "Unknown repo."}`.
Turning `auto_sync` on ("Import issues into *project*" on `/github`) clears the
repo's cursor, so the next sync back-fills its issue history.

::: walker SetRepoAutoDone h3

**Reports** `{"ok": true, "repo": RepoView}` or `not_found`. With `auto_done`
on ("Move a card to Done when its issue closes or its pull request merges"), a
closed issue or a merged PR (on a card In Progress or in Review) moves the card
to the done step.

::: walker SetRepoAutoClose h3

**Reports** `{"ok": true, "repo": RepoView}` or `not_found`. With `auto_close`
on ("Close the issue when its card moves to Done" on `/github`), `MoveTask` and
`UpdateTask` close the linked issue when a card lands on Done and reopen it when
the card leaves Done.

## Reconcile

::: walker SyncGithub h3

One bounded increment of the reconcile poll: drain the webhook queue, then read
each tracked repo's issues and pull requests updated since its cursor. The
server [schedule](../deploy/operations.md#the-scheduled-github-sync) runs it
with `auto: true` every 5 minutes per connected workspace; the Sync buttons run
it by hand, which also holds the workspace's sync lease for 4 minutes so the
schedule stays out of the way.

**Reports** `not_connected`, or:

```json
{
  "ok": true, "linked": 12, "refreshed": 3, "auto_added": 1, "auto_done": 1,
  "scanned": 140, "pages": 2, "drained": 4, "unfiled": 0, "lists": 2,
  "cooldown_minutes": 15.0, "has_more": false, "failure": "",
  "last_sync_at": "2026-09-15T08:12:33.123456Z"
}
```

| Field | Meaning |
| --- | --- |
| `linked` | Linked tasks the pass looked at: issues and PRs on the pages it read and in the deliveries it drained (it looks tasks up per page, never the whole workspace) |
| `refreshed` | State, assignee and PR changes applied |
| `auto_added` | Issues filed as new tasks (`auto_sync` repos) |
| `auto_done` | Cards moved to done |
| `scanned`, `pages` | GitHub items read and list requests made |
| `drained` | Queued webhook deliveries applied |
| `unfiled` | New issues on `auto_sync` repos that have no project |
| `lists` | Tracked repos whose stored open issue and pull request pages were rewritten (a pass that reached the end of every stream) |
| `cooldown_minutes` | 15 while deliveries are flowing, otherwise 1 |
| `has_more` | The page budget (5 by default, `page_budget` lowers it) or the 8 second clock ran out: call again |
| `failure` | GitHub's message when a request failed, else empty |

With `auto: true`, a call inside the cooldown reports all zeros and the
previous `last_sync_at`, and mints no token. A manual sync (`auto: false`)
ignores the cooldown. An invalid connection reports `{"ok": false, "error":
"invalid"}`.
