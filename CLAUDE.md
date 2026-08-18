# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

`AGENTS.md` covers the Jac CLI basics (`jac guide`, `jac check`, `jac browse`).
This file covers what is specific to *this* app. **Read `jac guide <name>` before
writing `.jac`** — the syntax looks like Python/JSX but is neither.

## Commands

```bash
jac check <file>                    # type-check + lint; run on every file you touch
jac fmt --lintfix <file>            # format + auto-fix lint; CI enforces this (see Verification)
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
  create dialog; an already mounted board listens for `standup:open-task` /
  `standup:new-task` instead (the palette uses both paths).
- **A log entry's `member_name` is every assignee comma-joined**, so split
  it before comparing to a member.
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
  `has zoom: float` compiles to `const [zoom, setZoom] = useState(...)`, so a
  `def setZoom` in the same component is a duplicate declaration and the
  whole Vite build fails with a 503 at request time (`jac check` passes —
  the clash only exists in the emitted JS). Name the method something else.
- **A docstring as the first statement of a plain `def` is a parse error** —
  use a `#` comment above the `def`.
- **On a full page load an app page mounts twice**: once bare, before the
  layout's `loggedIn` resolves, then again inside the chrome. Anything a
  page consumes in `can with entry` (a URL param, a one-shot flag) is gone
  for the second mount. Read it in entry, but consume it in the effect that
  acts on it (see `pendingTaskId` on the board).
- **`{if}` inside a `{for}` slot body takes no braces** (`if x { <li/> }`,
  not `{if x {…}}`): the compiler rejects the wrapped form (E2023).
- **A `has` list read after `await` is stale, and so is a `has` read inside a
  `setInterval` callback**: re-arm a `setTimeout` from an effect keyed on the
  value instead (see `HeroBoard`).
- **On jac 0.34.x a pure module imported by both sides can compile to an
  empty client file** (`"KIND_COLORS" is not exported by compiled/constants.js`).
  Each page's pre-scan reloads `constants.jac` when a component in its
  closure imports it, dropping the client stamps; only a page importing it
  directly re-stamps. `pages/layout.jac` is scanned last and imports
  `constants` for exactly that reason (`vocabPin`); before it existed the
  build only survived because `workflow.jac` sorted after `log.jac`.
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
- **A `useEffect` lambda must never `return None`.** React skips a cleanup
  that is `undefined`, but `None` compiles to `null`, which it happily calls:
  the page dies with "w is not a function" on the effect's next run. Give the
  early-exit path a real no-op cleanup (`timer = 0;` … `return lambda { if
  timer { window.clearTimeout(timer); }};`). `jac check` cannot see this and
  it only fires on the SECOND run, so it hides behind whatever condition
  takes the early exit.
- **A `has` you just assigned is still the OLD value for the rest of that
  handler.** Under the pinned 0.34.14 runtime `has fProject` compiles to
  `const [fProject, setFProject] = useState(...)`, so `fProject = v;
  refreshOlder();` sends the PREVIOUS filter — this is not only an
  after-`await` problem. Pass the new value as an argument, or keep it on a
  `Ref` (refs are live). Worth knowing: the 0.36.x dev build compiles `has`
  to a live external-store cell instead, so the same code behaves
  differently on the two binaries; write for the pinned one.
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
`main`/`dev`: `jac fmt --check --lintfix` over every tracked `.jac` except
`components/ui/` (registry copies get rewritten by `jac install --shadcn`),
`jac check --lint`, then a per-file `jac check`, all with the jac release
pinned in `jac.toml`. **Format with that exact version.** Release lines
disagree on line breaking (0.34.x and 0.36.x differ on 39 files here), so a
dev-build `jac` on PATH can produce output CI rejects. Get the pinned binary
with `curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash -s -- --version <pin>`
(lands in `~/.local/bin/jac`), then `~/.local/bin/jac fmt --lintfix <paths>`.
`jac check main.jac` does not surface errors in imported modules, which is why
CI checks each file; the type-check step runs twice on purpose (0.34.x reports
cold-cache E5082 false positives that a seeded `.jac/cache` clears; the
workflow comment explains).

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
