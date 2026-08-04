# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

`AGENTS.md` covers the Jac CLI basics (`jac guide`, `jac check`, `jac browse`).
This file covers what is specific to *this* app. **Read `jac guide <name>` before
writing `.jac`** — the syntax looks like Python/JSX but is neither.

## Commands

```bash
jac check <file>                    # type-check + lint; run on every file you touch
jac start main.jac                  # production mode — app and API share one origin
jac start --dev main.jac            # dev mode with HMR (see caveats below)
jac run brand/logo.jac              # regenerate the logo into assets/brand/
jac install --shadcn <name>         # add a UI primitive (writes components/ui/<name>.jac)
```

There is no test runner. Verification is a **hand-written API gate suite** plus
**browser QA** (see below).

### Running with SSO credentials

`.env` (gitignored) holds `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET` and the
`GITHUB_*` pair; `jac.toml` reads them via `${VAR}` interpolation.

```bash
set -a; . ./.env; set +a
unset DATABASE_HOST MONGODB_URI     # a stale mongo URI in the shell env aborts startup
jac start main.jac
```

### Server hygiene — do this before every restart

A lingering `_bun/bun` child holds the API port, `jac start` then silently
**drifts to the next port pair** (8002/8001 → 8005/8004 …), and every walker
call from the browser hangs. Always:

```bash
pkill -f "jac start"; pkill -f "runtimelib/client/_bun/bun"; sleep 3
for p in 8000 8001 8002 8003 8004 8005; do lsof -ti :$p | xargs kill -9 2>/dev/null; done
```

Then read the actual port out of the startup log rather than assuming 8000.

## Architecture

Multi-tenant kanban + daily-log tracker. **The account is the organization** —
there is no `Organization` node. Org details (`org_name`, `full_name`) live in
the account profile at `GET`/`PATCH /user/me`, written at signup through
`jacSignup`'s third `profile` argument.

### Server

- **`models.jac`** — every `node`/`edge`/`obj` archetype **and nothing else**.
  Archetype identity includes the module path, so **moving a declaration
  orphans persisted data**. It must also stay free of Python imports (see
  gotchas). Everything hangs off the caller's `root`: `root ++> Project /
  Member / Repo / Task / LogDay`, with typed edges `AssignedTo`, `ForProject`,
  `OnProject`, `Logged`, `By`.
- **`walkers/`** — the API, one module per domain (`projects`, `roster`,
  `tasks`, `log`) plus `util.jac` for server-only helpers. Walkers are **bare
  (JWT-required)**; there are no `:pub` walkers.
- **`constants.jac`** — `STATUSES`, `CATEGORIES`, `PRIORITIES`, `SECTIONS` as
  `glob` lists shared by client dropdowns and server validation.
- **`main.jac`** — entry point. **A walker missing from its import list 404s**,
  and the entry module cannot use relative imports (`import from models {…}`,
  not `.models`); modules under `walkers/` likewise import bare.

### Security model — the one thing not to regress

Isolation is structural: authenticated walkers run on the caller's own root, so
`[root --> …]` cannot reach another tenant. **But `jobj(id)` resolves any node
id regardless of owner — resolution is not authorization.** Every jid-addressed
mutation must call `owned(holder, target)` (or go through the `find_task` /
`find_log_entry` lookup bases) before touching anything.

Watch the container variable inside abilities: in a `Task`/`LogDay` entry
ability `here` is the *task or day*, not the root, so ownership checks use the
holder reached via `[here<--]`. Getting this wrong silently drops assignee and
project links rather than erroring.

### Client

File-based routing with route groups:

| Path | File | Access |
| --- | --- | --- |
| `/` | `pages/(public)/index.jac` | public landing page |
| `/login` | `pages/(public)/login.jac` | public; `?mode=signup` opens the signup tab |
| `/auth/callback` | `pages/(public)/auth/callback.jac` | receives `?token=` from SSO |
| `/board`, `/log`, `/workspace`, `/roadmap`, `/setup` | `pages/(auth)/…` | auto-guarded |

- **`pages/layout.jac` is path-aware**: app chrome renders only for
  authenticated, non-public paths (`PUBLIC_PATHS`), otherwise the landing page
  would show two navs. Do not add a `layout.jac` inside `(auth)/` — it
  collides with the root layout.
- Pages are **thin stateful shells**: they own `has` state and handlers (bodies
  in `.impl.jac` annexes under `pages/(auth)/impl/`) and compose presentational
  components from `components/{board,log,roster,projects,auth,landing}/`.
- Form-heavy dialogs take a `dict` plus one `onField(key, value)` callback
  rather than a dozen props.
- **`components/ui/`** is jac-shadcn — import only, never edit.
- **`lib/session.jac`** wraps `/user/me` (the runtime exports no helper).
- **`brand/logo.jac`** generates every logo variant into `assets/brand/`; edit
  the generator, not the SVGs. Reference brand assets as **`/static/...`**, not
  `/assets/...` — Vite owns `/assets/*` at build time.

## Jac gotchas that have already cost real debugging time

- **A computed key does not survive a dict-literal spread.** `{**form, key: v}`
  compiles to JS `{...form, key: v}` — a *literal* `"key"` property — so bound
  inputs freeze. Use `updated = {**form}; updated[key] = v; form = updated;`.
- **Never name a module after an npm package it imports.**
  `components/ui/sonner.jac` importing `"sonner"` resolved to itself → infinite
  React mount loop that pinned the main thread. It lives in `toaster.jac`.
- **No Python imports in modules the client imports types from.** A stray
  `import datetime` in `models.jac` dragged `@jac/wasm_host` into the browser
  bundle and broke the build; that helper lives in `walkers/util.jac`.
- **Elements directly inside `{if …}` slots need explicit `key` props.**
- **A docstring as the first statement of a plain `def` is a parse error** —
  use a `#` comment above the `def`.
- **`.jac/cache` can serve a stale build after editing an `.impl.jac`.** If a
  fix does not appear under `/compiled/…`, delete `.jac/cache` and
  `.jac/client/compiled`, then restart.
- **`max()`/`min()` over a list compiles to JS `Math.max(array)`, which is
  `NaN`.** Any guard like `max(xs) > 0` then silently fails. Compute peaks
  with an explicit loop in client code.
- **`len()` on a dict compiles to `.length`**, which is `undefined` on a plain
  JS object, so `len(d) > 0` is silently always false (it type-checks). Track
  emptiness with a separate `bool` field. `len()` on a list is fine.
- **A name first assigned inside an `if` is block-scoped in the compiled JS**
  and is `ReferenceError` after the branch. Initialise it before the branch.
- Client-side: `is None` misses `undefined`; `params["id"]`, never `.get()`;
  rebind state rather than mutating; a `has` read after `await` is a stale
  render-time snapshot. That last one bites hardest when a handler appends to
  a list twice around a walker call: the second `xs = xs + [...]` re-reads the
  pre-call value and silently drops the first append. Build the new list in a
  local and assign once.

## Verification

**API gates** — the suite lives in the scratchpad, not the repo; it signs up two
accounts and asserts CRUD plus tenant isolation: cross-account reads return
nothing, and foreign-jid `UpdateTask` / `MoveTask` / `DeleteTask` /
`AssignToProject` / `UpdateLogEntry` / `SaveProject` / `ArchiveMember` are all
no-ops. Re-run something equivalent after touching walkers or `owned()`.

**Browser QA** — use `agent-browser`, and note that **`agent-browser type` does
not reliably trigger React onChange** (it sets the value in a way React's
tracker ignores, making working inputs look broken). Use `agent-browser
keyboard type` for real key events. Assert on rendered text, not just
coordinates — a stale `@eN` ref can produce a phantom pass.

**SSO** — `jac start --dev` does **not** proxy `/sso` to the API (only
`/walker`, `/user`, `/function`, `/graph`, `/admin`, `/static`, `/assets`,
`/docs`, `/introspect`), so exercise SSO with a plain `jac start`. The initiate
endpoint requires a `client_callback` query param, which `jacSsoLogin` does not
send — `components/auth/SsoButtons.jac` builds the URL itself.

## Repo conventions

- **`main` is protected**: branch → PR → merge. Direct pushes are rejected for
  everyone, including admins. Merged branches auto-delete.
- **No `Co-Authored-By: Claude` trailers** in commits.
- `PLAN.md` (current working plan) is gitignored; shipped plans are archived in
  `plan-archive/`.
- Product copy must describe what the app actually does. The source design mock
  carries invented testimonials, usage metrics, pricing and integrations
  (Slack/Teams, blocker alerts, a 14-day trial) — none of that shipped, and the
  FAQ states the honest "not yet" answers instead.
