# API overview

Every server feature is a Jac **walker**, and the
runtime serves each one as an HTTP endpoint. There are {{ walker_count }} of
them. This section documents each: its request fields (generated from the
source), what it reports, and how it behaves on bad input.
{ .fl-lede }

## Calling a walker

Every walker is `POST /walker/<Name>` with a JSON body whose keys are the
walker's fields, and a Bearer token from [`/user/login`](authentication.md).
Omitted fields take their defaults.

=== "curl"

    ```bash
    curl -X POST http://localhost:8000/walker/ListTasks \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d '{"scope": "working", "page": 1, "page_size": 50}'
    ```

=== "JavaScript"

    ```js
    const res = await fetch("/walker/ListTasks", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ scope: "working", page: 1, page_size: 50 }),
    });
    const body = await res.json();
    const page = body.data.reports[0]; // a TaskPage
    ```

=== "Python"

    ```python
    import requests

    res = requests.post(
        "http://localhost:8000/walker/ListTasks",
        headers={"Authorization": f"Bearer {token}"},
        json={"scope": "working", "page": 1, "page_size": 50},
        timeout=30,
    )
    page = res.json()["data"]["reports"][0]  # a TaskPage
    ```

=== "Jac (inside the app)"

    ```jac
    result = root spawn ListTasks(scope="working", page=1, page_size=50);
    page = result.reports[0] if result.reports else None;
    ```

    Client code imports the walker from its `services` module and spawns it;
    the generated stub makes the HTTP call and unwraps the envelope.

## The response envelope

```json
{
  "ok": true,
  "type": "response",
  "data": {
    "result": null,
    "reports": [
      { "rows": [], "page": 1, "page_size": 50, "has_more": false, "total": 0, "older": 0 }
    ]
  },
  "error": null,
  "meta": {}
}
```

**Read `data.reports`.** It holds whatever the walker `report`ed, in order.
Every page in this reference says what that is:

| The reference says | `data.reports` looks like |
| --- | --- |
| Reports one `TaskView` | `[ {...} ]` |
| Reports one `list[MemberView]` | `[ [ {...}, {...} ] ]`, the whole list as the first report |
| Reports one dict | `[ {"ok": true, ...} ]` |
| Reports nothing | `[]` |

The runtime can also echo the walker's own fields into the envelope; do not
rely on anything outside `data.reports`.

## Nothing reported means "no-op"

Walkers do not answer bad ids with an error. An empty, malformed, unknown or
**foreign** id visits nothing, and the call returns HTTP 200 with
`reports: []`. The same happens when validation refuses a write, such as a
blank title. This is deliberate: "does not exist" and "belongs to someone else"
look identical. See [Tenancy and security](../concepts/security.md#resolution-is-not-authorization).

Walkers that talk to something outside the app (GitHub, the flow line editor's
guard rails) report a result dict instead, so the client can explain:

```json
{ "ok": false, "error": "last_of_kind", "message": "This is the only done step. Give another step that kind first, then delete this one." }
```

## Errors

| Status | When |
| --- | --- |
| `200` with `reports: []` | A no-op: bad or foreign id, refused validation |
| `200` with `{"ok": false, ...}` | A handled failure (GitHub unreachable, flow line guard) |
| `401` | Missing, invalid or expired token |
| `404` | A walker that `main.jac` does not import |
| `422` | The body does not match the walker's field types (for example a string for an `int` field) |
| `500` | An uncaught exception. The envelope carries `ok: false` and an `error` object, and the runtime includes the Python traceback. |

A runtime error keeps the envelope and fills `error` with a `code` and a
`message`, for example `{"code": "UNAUTHORIZED", "message": "..."}`.

## Conventions

Ids
:   Every row id is a jid string; treat it as opaque. View objects carry it as
    `id`, and walkers take it as `task_id`, `project_id`, `member_id` and so on.
    Raw nodes (`Project`, `LogEntry`) have no `id` field: their jid is the
    runtime's `_jac_id`.

Wire bookkeeping
:   Reported nodes and objects can carry `_jac_type`, `_jac_id` and
    `_jac_archetype` keys, which the Jac client uses to rebuild typed
    instances. On a view object (`TaskView`, `MemberView` and so on) `_jac_id`
    is fresh on every response; use its `id` field instead.

Dates
:   Plain ISO strings. Days are `YYYY-MM-DD`; timestamps are UTC with a `Z`
    suffix (`2026-09-15T08:12:33.123456Z`). Due dates and ranges are compared
    as strings.

Paging
:   List walkers that grow with history take a 1-based `page` and a
    `page_size`, where `0` asks for the walker's default and larger values are
    clamped to its cap. They report one page object with `rows`, `has_more`
    and `total` (the count of every matching row, not just the page). Every
    ordering ends in the jid, so a row never moves between pages across two
    requests. Roster-sized lists (members, projects, roles, repos, steps) are
    reported whole.

Statuses
:   `Backlog`, `In Progress`, `Review`, `Changes Requested`, `Done`, `Blocked`.
    Priorities are `High`, `Medium`, `Low`. See [Flow lines](../concepts/flow-lines.md)
    for how steps map onto statuses.

Webhooks
:   `GithubEvent` is served at `/webhook/GithubEvent`, never `/walker/`, and
    is authenticated by GitHub's signature instead of a JWT. See
    [Webhooks](webhooks.md).

## Try it in the browser

A running server exposes the runtime's **Swagger UI at `/docs`** (unless
`[serve] docs_enabled = false`), listing every walker with its request schema.
Authorize with the token from `/user/login` and call walkers directly.

## Every endpoint

::: endpoints
