# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

`AGENTS.md` covers the Jac CLI basics (`jac guide`, `jac check`, `jac browse`).
This file covers what is specific to *this* app. **Read `jac guide <name>` before
writing `.jac`** — the syntax looks like Python/JSX but is neither.

## Commands

```bash
jac check <file>                    # type-check + lint; run on every file you touch
jac fmt --lintfix <file>            # format + auto-fix lint; CI enforces this (see Verification)
jac run --no-dev main.jac           # production mode — app and API share one origin (:8000)
jac run -w 1 main.jac               # dev mode with HMR: app on :8000, API on :8001 (see caveats below)
jac run brand/logo.jac              # regenerate the logo into assets/brand/
jac install --shadcn <name>         # add a UI primitive (writes components/ui/<name>.jac)
jac scale deploy --dry-run --show-yaml main.jac   # render the k8s manifests (see Deploy sizing)
```

There is no test runner. Verification is a **hand-written API gate suite** plus
**browser QA** (see below).

### Running with SSO credentials

`.env` (gitignored) holds `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET` and the
`GITHUB_*` pair; `jac.toml` reads them via `${VAR}` interpolation.

```bash
set -a; . ./.env; set +a
unset DATABASE_HOST MONGODB_URI     # a stale mongo URI in the shell env aborts startup
jac run --no-dev main.jac
```

`jac start` and `jac dev` were removed in jac 0.37: both hard-error with the
`jac run` spelling. Serve flags go before the file (`jac run --port 3000 main.jac`).
`[serve.workers] count = "2"` sizes the deployed pods, and dev mode (HMR) is
single-process, so it refuses to start without `-w 1` or `JAC_SERVE_WORKERS=1`
(`.env.example` carries it; CLI beats env beats jac.toml).

### Server hygiene — do this before every restart

A lingering `_bun/bun` child holds the API port, `jac run` then silently
**drifts to the next port pair** (8002/8001 → 8005/8004 …), and every walker
call from the browser hangs. Always:

```bash
pkill -f "jac run"; pkill -f "_bun/bun"; sleep 3
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
  Member / Repo / Task / LogDay / WorkflowStep`, with typed edges
  `AssignedTo`, `ForProject`, `OnProject`, `Logged`, `By`, `FlowsTo`.
  `Milestone`, `VocabTerm` and their edges remain declared although the
  roadmap and vocabulary features were removed: deleting an archetype
  orphans whatever production still has.
- **`walkers/`** — the API, one module per domain (`projects`, `roster`,
  `tasks`, `log`, `flowlines`) plus `util.jac` for server-only helpers.
  Walkers are **bare (JWT-required)**; there are no `:pub` walkers.
- **A per-task edge hop is a separate traversal; one traversal yielding many
  edges is not.** `Task.to_view()` hops three times (assignees, project,
  milestone), and at 2,000 tasks on the pinned runtime that measured ~113ms
  PER ROW: a 500-row page took 56s. Walking IN from each Member and Project
  once costs a handful of traversals no matter how long the page is, and the
  same page then takes 0.56s. `hydrate_views(holder, rows)` in `models.jac`
  is that path and is what every list walker uses; `to_view()` is for a
  single task. `walkers/insights.jac` does the same thing for the snapshot
  (`_hydrate`). Never build a list by calling `to_view()` in a loop.
- **List walkers page, and build their rows in a local.** A walker's public
  `has` fields are serialised into the response beside `reports`, so an
  accumulator field (`has results`) ships every row a second time; the
  runtime already ships `walker.reports` a third. Rows go in a local and
  are reported once. Anything that grows with history (`ListTasks`,
  `ListStepTasks`, `ListLogEntries`, the GitHub walkers) takes `page` /
  `page_size` (1-based, clamped by `page_bounds` in `walkers/util.jac`) and
  reports one page object (`TaskPage`, `LogPage`, or the GitHub dict) with
  `rows`, `has_more` and `total`. Filter and sort on node fields first, run
  `to_view()` (three edge hops) for the page alone. Roster-sized lists
  (members, projects, roles, repos, steps) stay whole. `ListTasks` has a
  `scope`: `working` (open plus Done in the last `done_days`, what the board
  renders, `older` counting what the cutoff left out), `older`, `done`,
  `all`; `q` is a server-side title search ranked exact, prefix, contains.
  The Overview adds up history through `TaskCounts` / `LogCounts` rather
  than loading it. Every ordering ends in the jid, so a row cannot swap
  pages between two requests (sorts are stable, so a `jid` pass first and
  the real key second gives a deterministic tiebreak).
- **`constants.jac`** — `STATUSES`, `PRIORITIES`, `STEP_KINDS`, `KIND_COLORS`,
  `KIND_STATUS`, `STATUS_KIND` and `FLOW_LINE_TEMPLATES` as `glob`s shared by
  client dropdowns and server validation.
- **`main.jac`** — entry point. **A walker missing from its import list 404s**,
  and the entry module cannot use relative imports (`import from models {…}`,
  not `.models`); modules under `walkers/` likewise import bare.

### The flow line drives the board

An org designs its own steps on `/flowlines` (`WorkflowStep` nodes, `FlowsTo`
edges, cycles allowed on purpose). **The board's columns ARE those steps**, in
`sort_order`, so the two views cannot disagree. The feature was called
"workflow" until Aug 2026; `WorkflowStep` / `WorkflowMeta` keep that name
because renaming an archetype orphans persisted data, and `GetFlowLineMeta`
reads the old default name `"Workflow"` as `"Flow line"` for the same reason.
`/workflow` redirects to `/flowlines` for old links.

Each step carries a semantic `kind` (`start` / `active` / `handoff` /
`blocked` / `done`) behind the user's chosen name. **Roughly thirty places key
behavior on what a status MEANS** (`Done` is terminal, `Blocked` needs
attention, `Review` is a handoff), so every task write sets `step_id` *and*
the mapped legacy `status` via `KIND_STATUS`. Insights, GitHub sync, the
assistant and the log therefore never learn what a step is — keep it that way
rather than teaching them.

Tasks with an empty `step_id` (written before flow lines existed, or whose step
was deleted) fall back to `STATUS_KIND[status]` and render in the first column
of that kind; an org with no flow line at all falls back to `STATUSES`. Both
fallbacks are load-bearing — do not assume a task has a step.

### Security model — the one thing not to regress

Isolation is structural: authenticated walkers run on the caller's own root, so
`[root --> …]` cannot reach another tenant. **But `jobj(id)` resolves any node
id regardless of owner — resolution is not authorization.** Every jid-addressed
mutation must call `owned(holder, target)` (or go through the `find_task` /
`find_log_entry` lookup bases) before touching anything.

**An uncaught walker exception is returned to the browser with its Python
traceback** (the runtime sets `include_traceback` unconditionally, no config
switch). Anything that can fail outside our control (the LLM, GitHub) is
caught inside the walker, logged server-side with the operator hint, and
reported as an empty or `{"ok": False, ...}` result; the client shows a plain
"not available right now". See `_llm_failed` in `walkers/assistant.jac` and
`gh_request` in `walkers/ghutil.jac`.

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
| `/flowlines`, `/board`, `/overview`, `/log`, `/workspace`, `/settings`, `/setup` | `pages/(auth)/…` | auto-guarded |

- **`pages/layout.jac` is path-aware**: app chrome renders only for
  authenticated, non-public paths (`PUBLIC_PATHS`), otherwise the landing page
  would show two navs. Do not add a `layout.jac` inside `(auth)/` — it
  collides with the root layout.
- Pages are **thin stateful shells**: they own `has` state and handlers (bodies
  in `.impl.jac` annexes under `pages/(auth)/impl/`) and compose presentational
  components from `components/{flowlines,board,log,roster,projects,auth,landing}/`.
- Form-heavy dialogs take a `dict` plus one `onField(key, value)` callback
  rather than a dozen props.
- **`components/ui/`** is jac-shadcn — import only, never edit. When a
  registry component ships broken, keep the fixed copy under a name
  `jac install --shadcn <name>` cannot write to, or the next install
  silently restores the bug: `toaster.jac` (not `sonner.jac`). The
  Checkbox once needed the same treatment (`tickbox.jac`, for a stray
  `# noqa` text node); the registry copy at jac 0.34.14 is clean, so
  `checkbox.jac` is imported directly again.
- **`lib/session.jac`** wraps `/user/me` (the runtime exports no helper).
  **`lib/dates.jac`** owns the calendar rules (`todayIso`, `daysUntil`,
  `dueTone`, `dueLabel`): the card, the lane header and the overview all
  derive "overdue" from it, so change it there or nowhere.
- **`components/common/`** holds the shared bits: `Avatar.jac` (initials
  avatars, hue hashed from the name, `AvatarStack` for assignees),
  `CommandPalette.jac` (⌘K), `glyphs`, `Markdown`, `KineticGrid`.
- **Step colours are tokens.** `--step-<key>`, `-ink` (text) and `-wash`
  (opaque canvas fill) in `styles/global.css` for both palettes; the tables
  in `components/flowlines/kinds.jac` only name them (`bg-step-sky`). A new
  colour key needs tokens in both palettes, and its key is what persists.
- **The flow line page's step panel opens the board's dialog.** Clicking a step
  in view mode docks `StepTasksPanel` in the slot the editor's inspector uses,
  and a row opens `components/board/TaskDialog` on the same form dict and the
  same `UpdateTask` / `DeleteTask` walkers the board drives it with.
- **Board deep links**: `/board?task=<id>` opens a card, `/board?new=1` the
  create dialog; an already mounted board listens for `flowline:open-task` /
  `flowline:new-task` instead (the palette uses both paths).
- **A log entry's `member_name` is every assignee comma-joined**, so split
  it before comparing to a member.
- **`brand/logo.jac`** generates every logo variant into `assets/brand/`; edit
  the generator, not the SVGs. Reference brand assets as **`/static/...`**, not
  `/assets/...` — Vite owns `/assets/*` at build time.

### Deploy sizing

The app stays declared as `[project] kind/entry-point`, and the app pod is
sized in `[scale.kubernetes]` (`cpu_request`, `cpu_limit`, `memory_request`,
`memory_limit` are all honoured there; the gateway pod is sized in
`[scale.gateway]`). **Do not move it to `[apps.flowline]`.** On jac 0.37.7 an
`[apps]` table makes `jac scale deploy` skip the client bundle build (the
dry run's third line says "The served app has no client target"), so the
pods come up API-only and `/` is a JSON 404 while `jac run` still serves
the app locally (this took flowline-dev down on 2026-09-08, PR #176). That
table is also the only home of `workers = "auto"`, so the worker count is
fixed instead: `[serve.workers] count = "2"` becomes `JAC_SERVE_WORKERS=2`
on the app pod (and on the gateway pod, which has no override of its own);
keep it equal to the cores in `cpu_limit` (#140). Never write `"auto"`
there: the manifest builder resolves it on the deploying machine, not in
the pod (this Mac renders 10). The HPA scales on memory too (80% of the
request), so a request below the idle footprint pins the deployment at
`max_replicas`. The dry-run command above renders the manifests locally
once `bundle_storage_class` is set to any name (a placeholder for the RWX
check that a real deploy satisfies on the platform); `tests/smoke/
deploy_gate.py` asserts its transcript in CI.

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
- **`xs and xs[0].field` is not a safe guard.** A bare `and` compiles to a
  JS `&&`, and an empty array is truthy in JS, so the guard passes and the
  index throws at render time. Guard with `len(xs) > 0`. (A plain
  `xs[0] if xs else ...` ternary does get the truthiness helper; only the
  `and` form loses it.)
- **`jac check` does not catch a missing import inside a walker.** A `glob`
  or edge name that was never imported (`STATUS_KIND`, `ForProject`) still
  type-checks clean, then raises `name '...' is not defined` at request time
  and 500s the walker. Only running the endpoint finds it, which is what the
  API gate suite is for.
- **A `#` comment among JSX children renders as visible text.** Comments are
  only comments outside the JSX tree; inside it they become a text node and
  ship to the page. Keep notes in the docstring or above the `return`.
- **A page method named `set<Field>` collides with the state setter.** A
  `has zoom: float` compiles to a state cell plus a `setZoom` binding, so a
  `def setZoom` in the same component is a duplicate declaration and the
  whole Vite build fails with a 503 at request time (`jac check` passes —
  the clash only exists in the emitted JS). Name the method something else.
  Worse, an **imported function** named `set<Field>` doesn't even fail the
  build: the generated setter shadows the import silently, so every call
  updates React state instead of doing its job (issue #131, `setThemePref`
  vs `has themePref`). Never declare a `has` whose setter name an import uses.
- **A docstring as the first statement of a plain `def` is a parse error** —
  use a `#` comment above the `def`.
- **On a full page load an app page mounts twice**: once bare, before the
  layout's `loggedIn` resolves, then again inside the chrome. Anything a
  page consumes in `can with entry` (a URL param, a one-shot flag) is gone
  for the second mount. Read it in entry, but consume it in the effect that
  acts on it (see `pendingTaskId` on the board).
- **`{if}` inside a `{for}` slot body takes no braces** (`if x { <li/> }`,
  not `{if x {…}}`): the compiler rejects the wrapped form (E2023).
- **Placement is inferred and pinned in `jac.toml`, never in source.** Since
  jac 0.35 the `cl`/`sv` markers are syntax errors; `[placement.pins]` is the
  override. `models` and every `walkers/*` module carry a module-level
  `"server"` pin: without it a page's plain import of a walker pulls the
  whole walker module (abilities included) into the browser bundle and the
  build dies with "Client pathway failed to lower this edge reference shape".
  **A new walker module needs its own pin line.** The three `lib/utils`
  helpers are pinned `"client"` because an evidence-free `def:pub` in a
  web-app is otherwise a server endpoint. `jac check <page> --placements`
  prints every verdict with its evidence.
- **`[placement] default = "server"` is load-bearing for deploys.** At the
  `"native"` default, `jac build --as client` (the path a jachammer deploy
  runs) compiles pure `constants.jac` to wasm and the browser reads
  `STATUSES` through lazy stubs: the board dies with "X is not iterable"
  on the deployed bundle only. `jac run` never reproduces it, so verify a
  placement change with `jac build --as client main.jac` too.
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
- **A `has` flag cannot arbitrate a shared Escape.** A Radix dialog flips its
  own open state during the same keydown that reaches a page-level listener, so
  the listener reads the flag as already closed and dismisses its own surface
  too. Ask the DOM instead (`[role=dialog][data-state=open]`).
- **Nothing reachable from a `useEffect` body may `return None`.** React
  skips a cleanup that is `undefined`, but `None` compiles to `null`, which
  it happily calls: the page dies with "w is not a function" on the effect's
  NEXT run, so it hides behind whatever condition takes the early exit and
  `jac check` never sees it. Give an early exit a real no-op cleanup
  (`timer: any = 0;` … `return lambda { if timer { window.clearTimeout(timer);
  }};`). The trap is that this is not only about `return` written inside the
  effect: a ONE-STATEMENT effect lambda compiles to an expression-bodied
  arrow (`useLayoutEffect(lambda { fitZoom(); }, …)` emits `() => fitZoom()`),
  which is transparent to its callee's return value. `fitZoom` is safe today
  only because its own returns are bare; a `return None` added anywhere in a
  function an effect calls turns into that effect's cleanup, with no `return`
  visible at the effect at all.
- **`has` state is a live cell on jac 0.37.** `has fProject` compiles to
  `useJacState(...)` read through `.val`, so a write is visible to the next
  statement, inside helpers and after `await`. Most handlers were written
  for the 0.34.x runtime, where the same field was a `useState` snapshot
  that stayed stale for the rest of the handler; they pass the new value as
  an argument or keep it on a `Ref`, which is still correct and stays.
  Keep the habit of building a new list in a local and assigning once
  rather than appending twice around a walker call.
- Client-side: `is None` misses `undefined`; `params["id"]`, never `.get()`;
  rebind state rather than mutating.

## Verification

**API gates** — the suite lives in the scratchpad, not the repo; it signs up two
accounts and asserts CRUD plus tenant isolation: cross-account reads return
nothing, and foreign-jid `UpdateTask` / `MoveTask` / `DeleteTask` /
`AssignToProject` / `UpdateLogEntry` / `SaveProject` / `ArchiveMember` are all
no-ops, and every list filter (`project_id`, `assignee_id`, `step_id`,
`task_id`) yields nothing for a foreign id. Paging gates: pages partition
the set with no repeats, `total` is stable across pages, a page past the end
is empty, `page_size` clamps. Re-run something equivalent after touching
walkers or `owned()`.

**Browser QA** — use `agent-browser`, and note that **`agent-browser type` does
not reliably trigger React onChange** (it sets the value in a way React's
tracker ignores, making working inputs look broken). Use `agent-browser
keyboard type` for real key events. Assert on rendered text, not just
coordinates — a stale `@eN` ref can produce a phantom pass.

**CI** (`.github/workflows/ci.yml`) runs on every PR and on pushes to
`main`/`dev`. The `serve` job installs the pinned jac, runs `jac install`,
asserts the deploy dry run would build the client bundle with two workers
(`tests/smoke/deploy_gate.py`), boots `jac run --no-dev` and drives it:
`tests/smoke/api_gate.py` (shell, bundle, register, login, walkers, a
concurrent burst) and `tests/smoke/browser_gate.py` (Playwright: sign up,
create a task from the board, see the card). The `jac` job runs
`jac fmt --check --lintfix` over every tracked `.jac` except
`components/ui/` (registry copies get rewritten by `jac install --shadcn`),
`jac check --lint`, then a per-file `jac check`, all with the jac release
pinned in `jac.toml`. **Format with that exact version.** Release lines
disagree on line breaking, so a dev-build `jac` on PATH can produce output CI
rejects. Get the pinned binary
with `curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash -s -- --version <pin>`
(lands in `~/.local/bin/jac`), then `~/.local/bin/jac fmt --lintfix <paths>`.
`jac check main.jac` does not surface errors in imported modules, which is why
CI checks each file; the type-check step runs twice on purpose (0.34.x reported
cold-cache E5082 false positives that a seeded `.jac/cache` cleared; the
warm-up is kept as cheap insurance). `jac check` cannot see client codegen
failures either: only `jac run` (the bundle build) reports a walker module
that lowered into the client, so boot the app after touching imports or pins.

**SSO** — the HMR dev server (`jac run main.jac`) has not proxied `/sso` to
the API (only `/walker`, `/user`, `/function`, `/graph`, `/admin`, `/static`,
`/assets`, `/docs`, `/introspect`), so exercise SSO with `jac run --no-dev`. The initiate
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
