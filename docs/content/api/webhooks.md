# Webhooks

GitHub posts App events to a webhook walker. It is verified by signature, runs
as the runtime's system identity, and only queues; each workspace applies its
own queue. Source: `services/github/events.jac`.
{ .fl-lede }

::: walker GithubEvent

### The request

GitHub sends the delivery; you never call this endpoint yourself except in
tests.

```http
POST /webhook/GithubEvent
Content-Type: application/json
X-GitHub-Event: issues
X-GitHub-Delivery: 72d3162e-cc78-11e3-81ab-4c9367dc0958
X-Hub-Signature-256: sha256=<HMAC-SHA256 of the raw body, keyed by the webhook secret>

{"action": "closed", "installation": {"id": 12345678}, "repository": {...}, "issue": {...}, "sender": {...}}
```

The runtime copies `X-GitHub-Event` into `event` and `X-GitHub-Delivery` into
`delivery`, and the body's top-level keys into the matching fields. Keys the
walker does not declare are dropped.

### Runtime checks, before the walker runs

| Response | Cause |
| --- | --- |
| `401` | Missing or mismatched `X-Hub-Signature-256` |
| `413` | Body larger than `[scale.webhook] max_body_bytes` (2 MiB here) |
| `415` | Content type is not `application/json` |
| `500` | The walker raised |

### The walker's answer

The response body is what GitHub's delivery log shows:

```json
{ "ok": true, "outcome": "queued", "detail": "72d3162e-cc78-11e3-81ab-4c9367dc0958" }
```

| `outcome` | Meaning |
| --- | --- |
| `ping` | GitHub's ping when the webhook is saved |
| `unknown_installation` | No workspace has bound this installation id (`detail` is the id) |
| `echo` | Sent by the App itself (`<slug>[bot]`), dropped |
| `unsupported` | Not a handled event (`detail` is `event.action`) |
| `queued` | Inserted into `gh_deliveries` |
| `duplicate` | This delivery id is already queued (a redelivery) |
| `unavailable` | The docs store failed; `ok` is `false` but the status is still `200`, so use **Redeliver** |

Handled event kinds: `issues`, `pull_request`, `pull_request_review`,
`sub_issues`, `installation` and `installation_repositories`.

::: walker DrainGithubEvents

**Reports** `not_connected`, or:

```json
{ "ok": true, "drained": 3, "applied": 3, "added": 1, "moved": 0, "failed": 0 }
```

Applies up to 200 of this workspace's queued deliveries, oldest first, without
calling GitHub. An open, visible board calls it every 20 seconds while
deliveries are live and once a minute otherwise; the scheduled sync drains
too. When the
installation is bound to a different workspace, every count is 0. What each
event does is tabled in [GitHub sync](../concepts/github-sync.md#what-each-event-does).

### Testing locally

CI drives this endpoint against a GitHub stand-in
(`tests/smoke/github_stub.py`) with signed deliveries. To sign one by hand:

```bash
body='{"action":"opened","installation":{"id":1},"repository":{"full_name":"acme/docs"},"issue":{"number":7,"title":"Try it","state":"open","updated_at":"2026-09-15T08:00:00Z"},"sender":{"login":"octocat"}}'
sig=$(printf '%s' "$body" | openssl dgst -sha256 -hmac "$GITHUB_APP_WEBHOOK_SECRET" | sed 's/^.* //')
curl -X POST http://localhost:8000/webhook/GithubEvent \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: issues" \
  -H "X-GitHub-Delivery: local-$(date +%s)" \
  -H "X-Hub-Signature-256: sha256=$sig" \
  -d "$body"
```

An installation id no workspace has connected answers
`unknown_installation`, which is the expected result until you connect one.
