# Run locally

Two ways to serve the app, what each one listens on, where the
data goes, and the habits that keep a local server honest.
{ .fl-lede }

## Install dependencies

```bash
jac install
```

`jac install` reads `[dependencies]` (Python packages such as `requests`,
`pyjwt` and `cryptography`) and `[dependencies.npm]` (React, Radix, Tailwind and
friends) from `jac.toml`. Run it again whenever those tables change.

## Load the environment

`jac.toml` reads secrets with `${VAR}` interpolation, and interpolation reads
the **process** environment, not the `.env` file. Export it into the shell
before starting the server:

```bash
cp .env.example .env                                            # once
echo "GITHUB_APP_WEBHOOK_SECRET=$(openssl rand -hex 32)" >> .env  # once
set -a; . ./.env; set +a
unset DATABASE_HOST MONGODB_URI
```

Every value in `.env.example` is optional **except the webhook secret**. The
GitHub webhook walker verifies deliveries against it, so the runtime refuses to
boot when `[scale.webhook].github_secret` resolves to an empty string, and
sourcing the untouched template exports exactly that. A random local value is
fine until you [connect a real GitHub App](github-app.md).

!!! warning "Unset stale database variables"

    A leftover `DATABASE_HOST` or `MONGODB_URI` from another project aborts
    startup. The `unset` line above is cheap insurance.

## Choose a mode

=== "Production mode"

    ```bash
    jac run --no-dev main.jac
    ```

    The client bundle is built once and the client and API share one origin,
    `http://localhost:8000`. This is the mode to use for sign-in (SSO), for
    the smoke gates, and for anything you want to see the way users will.

    `[serve.workers] count = "2"` in `jac.toml` runs two worker processes,
    the same as a deployed pod.

=== "Hot reload"

    ```bash
    jac run -w 1 main.jac
    ```

    The app is served on `:8000` with hot module replacement and the API on
    `:8001`. Client edits appear without a restart; server (walker) edits need
    one.

    Hot reload is single-process, so it refuses to start with two workers.
    `-w 1` overrides `jac.toml`, and so does `JAC_SERVE_WORKERS=1` (which
    `.env.example` already sets). The CLI flag beats the environment, which
    beats `jac.toml`.

!!! note "Sign-in needs production mode"

    The hot-reload dev server proxies `/walker`, `/user`, `/function`,
    `/graph`, `/admin`, `/static`, `/assets`, `/docs` and `/introspect` to the
    API, but not `/sso`. Exercise Google or GitHub sign-in with
    `jac run --no-dev main.jac`.

## First run

1. Open <http://localhost:8000> and choose **Sign up** (or go straight to
   `/login?mode=signup`).
2. **Name your workspace** and its first project. The account **is** the
   organization: there is no separate organization record, and every task
   belongs to a project.
3. **Add people** to the roster, or skip. They are assignees, not accounts:
   nobody gets an email or a login.
4. **Pick how work moves**: Simple (To do, Doing, Review, Done; recommended),
   Software team (seven steps and four roles), or Draw my own. A template
   opens the board with a new task ready to type (`/board?new=1`); Draw my own
   goes to the flow line page to draw the steps yourself. The board's step
   groups are the steps you end up with. See
   [Flow lines](../concepts/flow-lines.md).

Setup resumes at the first unfinished step, and once a flow line exists
`/setup` sends you to the board.

## Useful local URLs

| URL | What is there |
| --- | --- |
| `/` | The public landing page |
| `/login` | Sign in; `?mode=signup` opens the sign-up tab |
| `/flowlines`, `/board`, `/roadmap`, `/overview`, `/workspace` | The app (signed in) |
| `/setup` | The setup wizard |
| `/workspace?tab=github` | The GitHub connection (`/github`, the App's callback, renders the same section) |
| `/workspace?tab=preferences` | The theme |
| `/docs` | The runtime's Swagger UI for every walker, unless `[serve] docs_enabled = false` |
| `/healthz/live`, `/healthz/ready` | Liveness and readiness probes |

## Where the data lives

Locally, Jac persists to an **embedded Postgres** cluster that boots on first
use under the machine-wide cache (`~/.cache/jac/pg`), with one database per
project path. Nothing needs to be installed or configured. Set `JAC_DB_URL` to
point at an external Postgres instead.

!!! tip "A clean database for an experiment"

    The database is keyed by the project's path, so a
    [git worktree](https://git-scm.com/docs/git-worktree) gets a fresh one.
    Run `jac install` inside the worktree and serve from there rather than
    deleting a store you may still want.

## Server hygiene

Do this before every restart:

```bash
pkill -f "jac run"; pkill -f "_bun/bun"; sleep 3
for p in 8000 8001 8002 8003 8004 8005; do lsof -ti :$p | xargs kill -9 2>/dev/null; done
```

A lingering `_bun/bun` child can keep the API port busy. `jac run` then
silently **moves to the next free port pair** (`8002/8001`, then `8005/8004`, and
so on) and every walker call from the browser hangs. After starting, read the
real port out of the startup log instead of assuming `8000`.

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| Every walker call hangs in the browser | The server moved ports. Run the hygiene commands above and restart. |
| A fix to an `.impl.jac` file does not show up | A stale build cache. Delete `.jac/cache` and `.jac/client/compiled`, then restart. |
| `jac check` passes but the page is a 503 | A client codegen failure only the bundle build sees. Watch the `jac run` log. |
| Login works but walkers return 500 with `unregistered class Root` | The local store was written by a different Jac build. Serve from a fresh worktree. |
| Startup aborts mentioning a database URI | A stale `DATABASE_HOST` or `MONGODB_URI` in the shell. `unset` them. |
| Startup fails about `[scale.webhook].github_secret` | The GitHub webhook walker needs `GITHUB_APP_WEBHOOK_SECRET` exported. Any value works locally. See [Connect GitHub](github-app.md). |
| The assistant says it is not available | `OPENAI_API_KEY` is not set, or the model account is out of credit. The server log names the cause. |
