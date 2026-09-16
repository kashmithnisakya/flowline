# Configuration

flowline is configured in two places: environment variables for
anything secret or per-deployment, and `jac.toml` for everything
else. `jac.toml` pulls the variables in with `${VAR}`
interpolation.
{ .fl-lede }

## How interpolation works

`jac.toml` references variables such as `${GOOGLE_CLIENT_ID}` or
`${HOST:-http://localhost:8000}`. The runtime resolves them from the process
environment when it loads the file:

| Reference | Variable set (even to `""`) | Variable not set |
| --- | --- | --- |
| `${VAR}` | its value | the literal text `${VAR}` stays in place |
| `${VAR:-fallback}` | its value | `fallback` |

Three consequences worth remembering:

- The `.env` file is **not** read by the runtime. Export it first:
  `set -a; . ./.env; set +a`. On jachammer, the project's environment
  variables play the same role.
- An exported empty value really is empty. That is what makes the webhook
  secret [refuse to boot](run-locally.md#load-the-environment) when the
  template is sourced unchanged.
- A deploy refuses a bare `${VAR}` that the pods will not receive (Jac
  0.37.18+). On jachammer every key in the project's environment reaches the
  pods, so set it there; optional values such as the SSO pairs use `${VAR:-}`.

## Environment variables

| Variable | Needed for | If empty or missing |
| --- | --- | --- |
| `HOST` | The public origin, **including the scheme** (`https://flowline.example.com`). Becomes the SSO host and the `/auth/callback` URL. | Falls back to `http://localhost:8000`. A value without a scheme breaks the sign-in round trip. |
| `OPENAI_API_KEY` | The [assistant](../api/assistant.md) (byLLM reads it from the environment) | The app runs; the assistant answers "not available right now" and the server log says why. |
| `LLM_MODEL` | Choosing the assistant's model | `gpt-4o-mini` |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | [Google sign-in](sso.md) | Clicking the Google button explains that it is not configured. |
| `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET` | [GitHub sign-in](sso.md) (an OAuth app, not the GitHub App) | Same as Google. |
| `GITHUB_APP_ID`, `GITHUB_APP_SLUG`, `GITHUB_APP_CLIENT_ID`, `GITHUB_APP_CLIENT_SECRET`, `GITHUB_APP_PRIVATE_KEY` | The [GitHub integration](github-app.md) | The GitHub tab lists exactly which of these are missing instead of failing. |
| `GITHUB_APP_WEBHOOK_SECRET` | Verifying signed webhook deliveries | **Required.** Set but empty, the server refuses to boot. |
| `GRAFANA_ADMIN_PASSWORD` | The Grafana admin in a Kubernetes deploy with monitoring | The monitoring stack falls back to a well-known default password. |
| `JAC_SERVE_WORKERS` | Worker processes for `jac run` | `jac.toml` says `2`; hot-reload mode needs `1`. |
| `GITHUB_API_BASE`, `GITHUB_WEB_BASE` | Pointing the integration at a stand-in (the CI stub) | `https://api.github.com` and `https://github.com` |
| `JAC_DB_URL` | An external Postgres instead of the embedded one | The embedded local store |

??? example "The full `.env.example` template"

    ```bash
    --8<-- ".env.example"
    ```

## `jac.toml`, table by table

`[project]`
:   `name = "flowline"`, `kind = "web-app"`, `entry-point = "main"` (the dotted
    module name; Jac 0.37.12+ refuses `"main.jac"`) and the exact
    `jac-version` pin. Keep the app declared here: an `[apps.<name>]` table
    makes deploys skip the client bundle. See [Production configuration](../deploy/production.md).

`[dependencies]`, `[dependencies.npm]`
:   Python and npm packages that `jac install` fetches.

`[jac-shadcn]`, `[client.vite]`, `[client.app_meta_data]`
:   The UI kit's style and theme, the Tailwind Vite plugin, and the page title,
    description, theme colour and icon the client shell ships with.

`[byllm]`, `[byllm.model]`, `[byllm.call_params]`
:   The assistant's system prompt (answer only from the snapshot, never invent
    people or dates), the model (`${LLM_MODEL:-gpt-4o-mini}`), and a low
    temperature with output retries.

`[serve.workers]`
:   `count = "2"` worker processes per app pod. Keep it equal to the cores in
    `cpu_limit`, and never `"auto"` (it resolves on the deploying machine).

`[scale.sso]`, `[scale.sso.google]`, `[scale.sso.github]`
:   The SSO host and client callback (both from `HOST`) and each provider's
    client id and secret.

`[scale.monitoring]`
:   `/metrics`, per-walker metrics and a Prometheus plus Grafana pair in the
    namespace. `k8s_metrics_enabled = false` keeps a node-exporter DaemonSet
    off the shared cluster.

`[scale.kubernetes]`
:   App pod sizing and autoscaling: CPU `1000m` to `2000m`, memory `4Gi` to
    `6Gi`, 2 to 6 replicas at 70% CPU.

`[scale.gateway]`, `[scale.gateway.hpa]`, `[scale.gateway.logs]`
:   The gateway pod in front of the app: a 120 second forward timeout, its own
    smaller sizing, 1 to 2 replicas, and log shipping off.

`[scale.webhook]`
:   `github_secret` (from `GITHUB_APP_WEBHOOK_SECRET`) and a 2 MiB body cap
    for GitHub deliveries.

`[placement]`, `[placement.pins]`
:   `default = "server"`, plus a `"server"` pin for `models` and every
    `services.*` module and three `"client"` pins for `lib.utils` helpers.
    **A new service module needs its own pin line.** See
    [Jac gotchas](../contributing/jac-gotchas.md#placement).

!!! warning "Something may rewrite `jac.toml` behind you"

    A workspace tool (most likely an editor's Jac language server) has been
    seen rewriting `jac.toml` minutes after an edit and stripping its
    comments. Commit a `jac.toml` change promptly and re-check the diff before
    you push.
