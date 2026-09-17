# Production configuration

What a production deployment needs set, and the `jac.toml` rules that each
cost a broken deploy to learn.
{ .fl-lede }

## Environment

Set these on the jachammer project (`jachammer env add KEY=VALUE`) or in your
cluster's Secret.

| Variable | Required | Notes |
| --- | --- | --- |
| `HOST` | Yes | The public origin **with scheme**, for example `https://flowline.jachammer.app`. SSO redirects and `/auth/callback` are built from it. |
| `GITHUB_APP_WEBHOOK_SECRET` | Yes | The pods refuse to boot without it. Must equal the GitHub App's webhook secret. |
| `OPENAI_API_KEY` | For the assistant | Without it the assistant reports "not available". |
| `LLM_MODEL` | No | Defaults to `gpt-4o-mini`. |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | For Google sign-in | Register `<HOST>/sso/google/callback`. |
| `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET` | For GitHub sign-in | Register `<HOST>/sso/github/callback`. |
| `GITHUB_APP_ID`, `GITHUB_APP_SLUG`, `GITHUB_APP_CLIENT_ID`, `GITHUB_APP_CLIENT_SECRET`, `GITHUB_APP_PRIVATE_KEY` | For the GitHub integration | A GitHub App per environment is simplest: its callback, setup and webhook URLs all name one `HOST`. |
| `GRAFANA_ADMIN_PASSWORD` | With monitoring | Otherwise Grafana keeps a well-known default password. |

!!! warning "One GitHub App per environment"

    The App's **Callback URL**, **Setup URL** and **Webhook URL** each hold one
    origin. Give dev and production separate Apps (and separate webhook
    secrets), or deliveries for one environment land on the other.

## Rules that keep deploys healthy

!!! danger "Keep the app under `[project]`"

    Declaring the app as `[apps.flowline]` makes `jac scale deploy` skip the
    client bundle: pods come up API-only and `/` is a JSON 404, while `jac run`
    still serves the app locally. This took the dev deployment down on
    2026-09-08. The dry run's third line saying "The served app has no client
    target" is the tell.

`entry-point = "main"`
:   The dotted module name. Jac 0.37.12+ refuses `"main.jac"`.

`[serve.workers] count = "2"`
:   Becomes `JAC_SERVE_WORKERS=2` on the app pod and the gateway pod. Keep it
    equal to the cores in `cpu_limit`. Never write `"auto"`: it resolves on the
    machine running the deploy, not in the pod (a laptop renders 10).

`[placement] default = "server"`
:   At the `"native"` default, the client build compiles pure `constants.jac`
    to wasm and the browser reads `STATUSES` through lazy stubs, so the board
    crashes on the deployed bundle only. Verify placement changes with
    `jac build --as client main.jac`.

## Sizing

```toml title="jac.toml"
[serve.workers]
count = "2"

[scale.kubernetes]
cpu_request = "1000m"
cpu_limit = "2000m"
memory_request = "4Gi"
memory_limit = "6Gi"
min_replicas = 2
max_replicas = 6
cpu_utilization_target = 70

[scale.gateway]
http_forward_timeout = 120.0
cpu_request = "100m"
memory_request = "1Gi"
memory_limit = "2Gi"

[scale.gateway.hpa]
min = 1
max = 2
```

| Setting | Why this value |
| --- | --- |
| `memory_request = "4Gi"` | Every HPA the runtime renders also scales on memory at 80% of the request, and memory does not spread across replicas. One worker idles around 2.4 GiB, so a request below the two-worker footprint pins the deployment at `max_replicas` with no load. |
| `cpu_limit = "2000m"` | Two worker processes, each able to use a core. |
| `[scale.gateway.hpa]` | Without it the gateway inherits the app's 2 to 6 bounds (four idle gateway pods on dev). The gateway only proxies. |
| Gateway `memory_request = "1Gi"` | `[serve.workers]` gives the gateway two processes too, and a 512 MiB request made its memory metric scale it out. |
| `http_forward_timeout = 120.0` | Long calls (a first GitHub back-fill) outlast the default 30 seconds and surface as `503 transport_error`. |
| `k8s_metrics_enabled = false`, `[scale.gateway.logs] enabled = false` | Each adds a per-node DaemonSet (node-exporter, Alloy) on the shared cluster, and Alloy reads every namespace's logs. |

## Render before you ship

The dry run renders the manifests locally with the pinned runtime. It needs a
placeholder RWX storage class, which a real deploy satisfies on the platform,
so add it to a scratch copy only:

```bash
cp jac.toml /tmp/jac.toml.orig
python3 - <<'PY'
s = open("jac.toml").read()
s = s.replace("[scale.kubernetes]\n", '[scale.kubernetes]\nbundle_storage_class = "placeholder"\n', 1)
open("jac.toml", "w").write(s)
PY
jac scale deploy --dry-run --show-yaml main.jac > manifests.yaml
mv /tmp/jac.toml.orig jac.toml
python3 tests/smoke/deploy_gate.py manifests.yaml
```

`tests/smoke/deploy_gate.py` is what CI runs: it asserts the manifests build a
client bundle, run two workers, and keep the gateway inside its bounds.

## Data safety

- **Archetypes never move.** A node's identity includes its module path, so
  relocating a declaration out of `models.jac` orphans every stored row. Add
  fields with defaults instead; old rows read the default.
- **Changing a Jac release changes the store's reader.** Bump the pin on dev
  first and verify with real walker calls. See
  [Operations](operations.md#upgrading-jac-on-a-live-deployment).
