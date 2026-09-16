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
admin authentication. On Jac 0.37.14 with more than one worker it can answer
`200` with an empty body, because the collector is created before the worker
supervisor configures multi-process mode (jaseci-labs/jac#9190); prefer
`jachammer top` until that ships.

**Application logs.** The app logs to named loggers:

| Logger | What it reports |
| --- | --- |
| `flowline.github` | Unbound installations, docs store failures, deliveries that raised, skipped issue state write-backs |
| `flowline.assistant` | LLM failures, with the hint to check `OPENAI_API_KEY`, `LLM_MODEL` and the model account's credit |

**GitHub deliveries.** The App's **Advanced** tab lists every delivery with its
status, response body (`queued`, `echo`, `unknown_installation`...) and a
**Redeliver** button. GitHub never retries on its own.

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
| Board shows a reconnect banner | A GitHub call returned 401 or 404 and marked the connection invalid. Reconnect on the GitHub tab. |
| GitHub changes stopped arriving | The delivery log: `401` (secret mismatch), `415` (content type), `unknown_installation` (reconnect the workspace), or no deliveries at all (webhook URL). |
| The assistant is "not available" | `flowline.assistant` in the logs. |
| `500` from a walker with a traceback in the response | An uncaught exception; usually a name missing from an import. `jac check` does not catch those, so reproduce with the API gate locally. |
| High replica count with low traffic | Memory requests versus idle usage (`jachammer top`). |
| `503 transport_error` | A call outlasting the gateway's forward timeout. |
