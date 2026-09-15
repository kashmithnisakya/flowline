# Deploy with jachammer

[jachammer](https://jachammer.ai) deploys Jac apps to a managed Kubernetes
cluster. Its CLI bundles the repo, uploads it, and follows the rollout until the
URL answers.
{ .fl-lede }

## 1. Install the CLI

```bash
curl -fsSL https://jachammer.ai/static/assets/cli/install.sh | bash
jachammer --version
```

The installer puts `jachammer` in `~/.local/bin` and installs the `jac`
runtime first if none is on your `PATH`. The CLI itself is a Jac program run by
that `jac`.

!!! warning "The CLI runs on the Jac 0.34 line"

    At the time of writing the CLI is written for Jac 0.34 and does not compile
    under 0.37, where `entry` became a reserved word. If `jachammer` stops with
    an error pointing at `entry`, keep a 0.34 binary beside the pinned one and
    put it first on `PATH` only for the CLI:

    ```bash
    # once: fetch a 0.34 binary under its own name, then restore the pin
    curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh \
      | bash -s -- --version 0.34.19
    mkdir -p ~/.jac-0.34/bin && mv ~/.local/bin/jac ~/.jac-0.34/bin/jac
    curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh \
      | bash -s -- --version {{ jac_version }}

    # every time
    PATH="$HOME/.jac-0.34/bin:$PATH" jachammer deploy
    ```

    The app still builds with its own pin: the CLI only bundles and uploads.

## 2. Log in

```console
$ jachammer login
logging in to https://jachammer.ai (default)

Open this URL in your browser and enter the code:

    https://jachammer.ai/auth/cli
    code: ABCD-EFGH
```

Approve the code in the jachammer dashboard you are already signed into. The
token is stored in `~/.jachammer/config.json` (mode `0600`). Over SSH or in a
container, add `--no-browser`; the URL and code print either way.

## 3. Link the project

Run everything from the repo root, the folder with `jac.toml`.

=== "An existing project"

    ```bash
    jachammer projects ls
    jachammer link "Flowline"
    ```

=== "A new project"

    ```bash
    jachammer deploy --create --name "My Flowline"
    ```

Either way the CLI writes the project's stable id into `jac.toml`:

```toml title="jac.toml"
[jachammer]
project_id = "prj_..."
```

Commit that table. A later deploy, a fresh clone and CI then resolve the same
project with no prompt, and renaming the project in the dashboard never splits
deploys across two projects.

!!! tip "Throwaway deploys"

    For a one-off experiment, create a separate project with `--create
    --name`, and afterwards `git checkout jac.toml` so its id is not
    committed. Always pass `--name` with `--create`; relying on the app's
    `[project] name` can attach a preview to the wrong project.

## 4. Set environment variables

The project's variables are applied to the pods as a Kubernetes Secret on the
next deploy, which is how `jac.toml`'s `${VAR}` references resolve in
production.

```bash
jachammer env add HOST=https://flowline.example.com
jachammer env add GITHUB_APP_WEBHOOK_SECRET=$(openssl rand -hex 32)
jachammer env add OPENAI_API_KEY=sk-...
jachammer env ls              # values masked; --reveal to print them
jachammer env rm OPENAI_API_KEY
```

A change is live only after a deploy or `jachammer redeploy` carries it.
[Production configuration](production.md#environment) lists every variable.
`jachammer pull` links a fresh clone and writes the project's variables into
`.env`.

## 5. Deploy a preview

```bash
jachammer deploy
```

This bundles the tracked files (`git ls-files`, so `.gitignore` applies, plus
`.jacignore`), uploads them, and starts a **preview** in the project's
`<slug>-preview` namespace with a generated URL. It never touches production,
and each project has one rolling preview: the next preview replaces it.

Progress streams to the terminal and the command prints `deployed: <url>` once
the URL answers (`--ready-timeout`, 90 seconds by default). It exits non-zero on
failure.

!!! note "What is uploaded"

    Only tracked files, capped at about 10 MB zipped. `docs/` is listed in
    `.jacignore` so this site never ships inside the app. A later deploy syncs
    the tree exactly: files deleted locally are deleted on the platform too,
    except `.env`.

## 6. Deploy to production

```bash
jachammer deploy --prod
```

A production deploy uses the same flow as the dashboard: the plan's deploy
quota, the project's vanity subdomain or custom domain, and a deploy record you
can list with `jachammer ls --deployments`.

```bash
jachammer domains check flowline      # is the subdomain free?
jachammer domains add flowline        # served on the next prod deploy
jachammer domains ls
```

## Day two

| Task | Command |
| --- | --- |
| Pods and recent Kubernetes events | `jachammer inspect [--prod]` |
| Live CPU and memory per pod | `jachammer top [--prod]` |
| Pod logs | `jachammer logs [-f] [--prod]` |
| Redeploy the last upload without re-bundling (for example after `env add`) | `jachammer redeploy [--prod]` |
| Restore an earlier version and redeploy it to production | `jachammer rollback [commit]` (`--list` shows versions) |
| Tear a deployment down | `jachammer destroy [--prod]` |
| Who am I, which remote | `jachammer whoami`, `jachammer set-remote` |

!!! danger "`destroy` is irreversible"

    Without `--prod` it removes the preview; with `--prod`, production.
    In unattended use it needs both `--yes` and `--project <id>`, and
    `jachammer destroy --dry-run` prints the id without removing anything.

## Deploy from CI

CI has no browser, so it authenticates with a token. Print yours with
`jachammer token` and store it as a repository secret.

```yaml title=".github/workflows/deploy.yml"
name: Deploy
on:
  workflow_dispatch:
  push:
    branches: [main]

concurrency:
  group: deploy-prod
  cancel-in-progress: false

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    env:
      JACHAMMER_URL: https://jachammer.ai
      JACHAMMER_TOKEN: ${{ secrets.JACHAMMER_TOKEN }}
      JACHAMMER_NO_UPDATE_CHECK: "1"
      GITHUB_TOKEN: ${{ github.token }}
    steps:
      - uses: actions/checkout@v7
      - name: Install jac 0.34 for the CLI
        run: |
          curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh \
            | bash -s -- --version 0.34.19
          echo "$HOME/.local/bin" >> "$GITHUB_PATH"
      - name: Install the jachammer CLI
        run: curl -fsSL https://jachammer.ai/static/assets/cli/install.sh | bash
      - name: Deploy
        run: |
          jachammer deploy --prod --non-interactive --json \
            --idempotency-key "prod-${{ github.run_id }}" --timeout 20m
```

- `--non-interactive` turns any prompt into a usage error (exit `2`) instead of
  a hang.
- `--idempotency-key` makes a retry of the same run follow the original rollout
  instead of starting a second deploy.
- Under `--json` the output is a stream of progress lines ending in one
  envelope: `{"schema":"jachammer.v1","ok":true,"command":"deploy","data":{"url":...}}`.
  Branch on `error.code`, never on the message.

| Exit | Code | Means |
| --- | --- | --- |
| `0` | | Success |
| `2` | `USAGE` | Bad invocation, or a prompt that cannot be answered |
| `3` | `UNHEALTHY` | The command worked; the deployment is not serving |
| `4` | `UNAUTHORIZED` | No session, or the token was rejected |
| `5` | `UNREACHABLE` | The platform could not be reached |
| `6` | `QUOTA_EXCEEDED` | A plan limit refused the deploy |
| `7` | `CONFIG_INVALID` | Local config missing, or the CLI is too old for the server |
| `8` | `TIMEOUT` | `--timeout` ran out; the deploy may still be rolling out |

## Troubleshooting a deploy

| Symptom | Cause |
| --- | --- |
| `/` returns a JSON 404 while the API works | The deploy skipped the client bundle. Make sure there is no `[apps.*]` table in `jac.toml`; see [Production configuration](production.md#rules-that-keep-deploys-healthy). |
| Load fails on `entry-point` | Jac 0.37.12+ needs the dotted module name: `entry-point = "main"`. |
| The board crashes with "X is not iterable" only on the deployed build | `[placement] default` was changed from `"server"`, and the client build compiled `constants.jac` to wasm. |
| `503` with `transport_error` on long calls | The gateway's forward timeout. `[scale.gateway] http_forward_timeout = 120.0` raises the platform's 30 second default. |
| The old build still answers after `deployed:` | A rolling update: old pods serve for a few minutes, and a browser that saw the old bundle caches it. Verify with a cache-busting query string. |
| Replicas sit at the maximum while idle | The HPA also scales on memory at 80% of the request. Keep `memory_request` above the idle footprint. |
| Every GitHub delivery fails with `401` | The project's `GITHUB_APP_WEBHOOK_SECRET` differs from the App's webhook secret. |
