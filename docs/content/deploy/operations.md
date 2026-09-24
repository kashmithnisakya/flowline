# Operations

Checking a running deployment, reading its signals, and changing it safely.
{ .fl-lede }

## Health

| Endpoint | Use |
| --- | --- |
| `GET /healthz/live` | Liveness: the process is up |
| `GET /healthz/ready` | Readiness: the app can serve. CI waits on it before the smoke gates. |
| `GET /` with `Accept: text/html` | The app shell. A JSON 404 here means the deploy has no client bundle. |

Client routes such as `/board` return the app shell to a browser and a JSON 404
to `curl` without an HTML `Accept` header. That is expected.

## Signals

**Pods and resources.** `jachammer inspect [--prod]` lists pods and recent
Kubernetes events; `jachammer top [--prod] --json` reports CPU and memory per
pod.

**Metrics.** `/metrics` (Prometheus format, with per-walker metrics) requires
admin authentication. Through Jac 0.37.21, with more than one worker, it answers
`200` with an empty body, because the collector is created before the worker
supervisor configures multi-process mode (jaseci-labs/jac#9190); prefer
`jachammer top` until that ships.

**Application logs.** The app logs to named loggers:

| Logger | What it reports |
| --- | --- |
| `flowline.github` | The scheduled sync's line per workspace, unbound installations, docs store failures, deliveries that raised, skipped issue state write-backs |
| `flowline.assistant` | LLM failures, with the hint to check `OPENAI_API_KEY`, `LLM_MODEL` and the model account's credit |

**GitHub deliveries.** The App's **Advanced** tab lists every delivery with its
status, response body (`queued`, `echo`, `unknown_installation`...) and a
**Redeliver** button. GitHub never retries on its own.

## The scheduled GitHub sync

No page load calls GitHub. The reconcile poll runs on a server schedule,
`sync_connected_workspaces` in `services/github/schedule.jac`:

| Setting | Value | Where |
| --- | --- | --- |
| Interval | every 5 minutes (`SYNC_INTERVAL_SECONDS`, 300) | one worker per tick across workers and pods, through the runtime's `sched:` lease on the Postgres store |
| Per-workspace lease | `SYNC_LEASE_SECONDS`, 240 s | `sync:<root jid>` in the store's `kv_state`; a pass that finds it held skips the workspace |
| Grace after connect | one interval | a workspace bound inside the last interval is left to its GitHub page; its first pass is the next tick |

Each tick walks the `gh_installations` index (installation id to workspace
root) and runs one `SyncGithub(auto=True)` pass in each workspace's own root:
drain the webhook queue, then poll unless the workspace synced inside its
cooldown (1 minute, or 15 while deliveries are flowing), then rewrite the open
issue and pull request pages the GitHub page renders. The pass is bounded (5
pages, 8 seconds); what is left carries to the next tick as `has_more`.

A row whose workspace no longer exists, or no longer holds that installation,
is dropped by the tick that finds it, along with its queued deliveries
(`installation 1234 unbound: the workspace no longer holds it`). The delete
names the root it read, so a workspace that took the installation over in the
meantime keeps its row. An invalid connection (a suspended or revoked
installation) keeps its row, so an `unsuspend` delivery still reaches it.

The log carries one `flowline.github` line per workspace visited
(`github sync: installation 1234: drained 0, added 1, ... lists 2`) and one
warning per failure. **Sync now** and **Re-sync history** in Workspace's GitHub section still
run the walker by hand, ignore the cooldown, and hold the workspace's lease for
`SYNC_LEASE_SECONDS`, so the schedule stays out of a workspace someone is
syncing. `FLOWLINE_SYNC_INTERVAL_SECONDS` in the pod environment overrides the
interval (the CI serve job sets 30 to observe a pass); a deployment leaves it
unset.

## Changing a running deployment

| Change | How |
| --- | --- |
| An environment variable | `jachammer env add KEY=VALUE`, then `jachammer redeploy --prod` |
| Code | Merge to the environment's branch, then `jachammer deploy --prod` from it |
| Roll back | `jachammer rollback --list`, then `jachammer rollback <commit>` (a redeploy of an earlier version, not an instant traffic switch) |
| Restart pods | `jachammer redeploy --prod` |

A redeploy restarts pods and reseeds the bundle. During the rollout the old
pods keep answering some requests for a few minutes, so check a new build with
a cache-busting query string.

## Upgrading Jac on a live deployment

Persisted anchors embed each archetype's module path, and the runtime reads
them through its own class registry. Treat a pin bump as a data migration:

1. Bump `jac-version` on a branch, reformat with the new binary, and get CI
   green (the serve job boots the new runtime against a fresh store).
2. Deploy to **dev** and exercise it with real walker calls (list tasks, move a
   card, drain GitHub). A page returning `200` proves nothing: a store written
   by a different build can let login succeed while every walker fails with
   `unregistered class Root`.
3. Only then deploy production, and keep `jachammer rollback` ready.

## Troubleshooting

| Symptom | Look at |
| --- | --- |
| The GitHub page shows a reconnect banner | A GitHub call returned 401 or 404 and marked the connection invalid. Reconnect from that banner. |
| GitHub changes stopped arriving | The delivery log: `401` (secret mismatch), `415` (content type), `unknown_installation` (reconnect the workspace), or no deliveries at all (webhook URL). |
| The assistant is "not available" | `flowline.assistant` in the logs. |
| `500` `EXECUTION_ERROR` from a walker | An uncaught exception, with its traceback in the server log; usually a name missing from an import. `jac check` does not catch those, so reproduce with the API gate locally. |
| High replica count with low traffic | Memory requests versus idle usage (`jachammer top`). |
| `503 transport_error` | A call outlasting the gateway's forward timeout. |
