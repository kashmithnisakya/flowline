# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

`AGENTS.md` covers the Jac CLI basics (`jac guide`, `jac check`, `jac browse`).
This file covers what is specific to *this* app. **Read `jac guide <name>` before
writing `.jac`**: the syntax looks like Python/JSX but is neither.

## Commands

```bash
jac check <file>                    # type-check + lint; run on every file you touch
jac fmt --lintfix <file>            # format + auto-fix lint; CI enforces this (see Verification)
jac run --no-dev main.jac           # production mode: app and API share one origin (:8000)
jac run -w 1 main.jac               # dev mode with HMR: app on :8000, API on :8001 (see caveats below)
jac run --no-takeover brand/logo.jac     # regenerate the logo into assets/brand/ (plain `jac run` fails on 0.37.14)
jac run --no-takeover brand/social.jac   # draw the link preview card, assets/brand/og-image.png
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

### Server hygiene: do this before every restart

A lingering `_bun/bun` child holds the API port, `jac run` then silently
**drifts to the next port pair** (8002/8001 → 8005/8004 …), and every walker
call from the browser hangs. Always:

```bash
pkill -f "jac run"; pkill -f "_bun/bun"; sleep 3
for p in 8000 8001 8002 8003 8004 8005; do lsof -ti :$p | xargs kill -9 2>/dev/null; done
```

Then read the actual port out of the startup log rather than assuming 8000.

## Architecture

Multi-tenant kanban + daily-log tracker. **The account is the organization**:
there is no `Organization` node. The organization's name (`org_name`) lives in
the account profile at `GET`/`PATCH /user/me`: signup sends an empty profile
and the setup wizard writes the name. The app asks for no personal name; the
people it tracks are roster members.

### Server

- **`models.jac`**: every `node`/`edge`/`obj` archetype **and nothing else**.
  Archetype identity includes the module path, so **moving a declaration
  orphans persisted data**. It must also stay free of Python imports (see
  gotchas). The graph is boxed: `root ++> Projects ++> Project ++> Task`,
  `root ++> Members ++> Member`, `root ++> Roles ++> Role` and
  `root ++> WorkflowSteps ++> WorkflowStep` (that box also carries the flow
  line's name and template key) and `root ++> Logs ++> LogDay ++> LogEntry`
  (an entry hangs under its day; `days_between(root, since, until)` reads
  the days in a date range, filtered in the store's query) and
  `root ++> Iterations ++> Iteration` (time boxes; a task points at one
  through its `iteration_id` field, like `step_id`, and `DeleteIteration`
  clears it); `Repo` and `GithubConnection` hang off the root directly.
  Typed edges: `AssignedTo`, `OnProject`, `HasRole` (a member's roles are
  edges to `Role` nodes; `MemberView.roles` and the `SaveMember` /
  `SetMemberRoles` inputs are still names), `HasRepo`, `By` (a log entry to
  its member).
  There is no edge between steps: a step keeps its outgoing transitions in
  its own `transitions` field (`{to, label, carries}`), so `DeleteStep`
  strips the removed step's id from every other step's list, and
  `step_view(s, steps)` reads incoming ids off the whole flow line and
  drops a transition to a step that is gone. **A task's project is its
  container** (no project edge), so every task has exactly one project and `CreateTask` refuses to create
  without an owned, active one; `AddRepo` needs a project for the same
  reason (the sync files issues under the repo's project). A box is made
  on first write by its get-or-create helper (`projects_box(root)` and
  friends); the cross-kind readers `projects_of`, `members_of`, `roles_of`
  and `steps_of` serve the walkers that aggregate from the root, and the
  task readers below serve every task walker. A `Member` stores
  `first_name` and `last_name`; `full_name()` is the display name.
- **`services/`**: the API, one folder per section (`projects`, `roster`,
  `tasks`, `board`, `log`, `flowlines`, `insights`, `assistant`,
  `iterations` (iteration CRUD and `RoadmapSnapshot`),
  `workspace` (`GetWorkspace`: the roster, projects, flow line, repos,
  roles, iterations, flow line meta and GitHub connection in one read;
  `BoardSnapshot` fills its workspace fields from the same
  `workspace_view` helper, so there is one definition of those lists), and
  `github` with `github.jac`, `events.jac`, `schedule.jac` (the scheduled
  sync, a function, not a walker) and `util.jac`) plus
  `services/util.jac` for shared server-only helpers. Walkers are **bare
  (JWT-required)**; there are no `:pub` walkers. **Keep walker ability
  bodies inline, not in an `.impl.jac` annex**, still on jac 0.37.18: the endpoint
  effect pass does not follow an ability body into an annex, so an annexed
  walker is classified as a pure read, the client caches it, and a save no
  longer invalidates anything (every write-then-refetch shows stale data;
  `jac run` gives no error, only the browser gate catches it). Compare the
  `endpointEffects` in the `/board` shell's `__jac_init__` to verify.
  Filed as jaseci-labs/jac#9189; annex the bodies once a release carries
  the fix and the pin moves.
  **A box-scoped walker visits, it does not read from the root.** Its
  `Root entry` ability only decides where to go: `visit [here-->[?:Members]]
  else { report []; }` for a read (a GET never makes a box), `visit
  members_box(here)` for a write, `visit [target]` after `resolve` +
  `owned` for a jid-addressed row (the `find_task` / `find_step` /
  `find_project` / `find_member` lookup bases). The work happens in a
  `with <Box> entry` or `with <Row> entry` ability, where the traversal from
  the caller's root is the isolation and `root` is the caller's root when a
  sibling box is needed. Only the aggregators that page or sort across
  kinds (`BoardSnapshot`, `OverviewSnapshot`, `TaskCounts`, `ListTasks`
  without a project, `SyncGithub`) stay on the root with the `*_of`
  readers: carrying rows between abilities means walker `has` fields, and
  those ship in the response. The one
  exception is `services/github/events.jac`: `GithubEvent` is a webhook-protocol
  walker (`/webhook/GithubEvent`, never `/walker/`) whose caller is GitHub,
  authenticated by the runtime's signature check before the walker exists.
  It runs as the system identity and only queues the delivery in the shared
  docs store; `DrainGithubEvents` (and every `SyncGithub`) applies the queue
  in the workspace's own session, so no walker ever writes a foreign root.
- **No aggregator loads the task history.** A predicate inside a graph
  reference (`[box-->[?:Project]-->[?:Task, status != "Done"]]`) compiles
  to one SQL statement and loads only the matching rows (pushed: `==`,
  `!=`, `<`, `<=`, `>`, `>=`, a comma is AND, a trailing field name or
  `-field` orders, `[:n]` bounds; no OR, and a left side must be a declared
  field name, else E5094). The readers in `models.jac` are those queries:
  `open_tasks`, `done_since`, `done_before`, `working_tasks` (the board's
  working set), their `project_*` twins, the per-step and
  per-iteration lookups, the column readers (`step_column_peak` and
  friends, for the drag order) and the GitHub lookups (`tasks_by_issue`,
  `tasks_by_pr`, `children_of`, `status_peak`). Only `all_tasks`,
  `done_tasks` and `done_before` load history, and only the explicit
  history scopes of `ListTasks` (`older`, `done`, `all`, the palette's
  search) call them, and not for an unfiltered page in updated order,
  newest first (the table's default): `history_page` cuts that one in the
  store (`recent_tasks` and friends, `-updated_at` with `[:end]`) and adds
  every row stamped like the prefix's last (`tasks_stamped`), because a sync
  pass stamps many rows alike and the store orders ties arbitrarily. All-time totals are tallies kept on write:
  `Project.task_total`, `done_total`, `seeded_done_total` (created already
  Done: history, not throughput), the Overview's weekly history
  (`Project.week_added` / `week_finished`, keyed by the week's Monday from
  `history_days` and `week_start`, filled once per project by
  `ensure_history`, which only `TaskHistory` calls, and moved by
  `shift_history` on the same writes plus the sync's `reseed`) and
  `Projects.categories` (exact: `note_category` adds, `forget_category`
  drops after a two-row lookup).
  `count_task`, `rehome_task` and `Task.set_status` move them; `CreateTask`,
  `DeleteTask`, `UpdateTask` (category, re-parent), `file_issue_item` and
  the sync's date corrections (`reseed`) are the write points. A task
  carries `project_id` and `assignee_ids` (written wherever an `AssignedTo`
  edge or the container changes: `link_assignees`, `rehome_task`,
  `file_issue_item`, `ArchiveMember`), so `hydrate_rows` / `rows_from`
  build a page from fields plus `task_names` (two roster lists), never a
  hop; `to_view()` still hops and is for a single task. **A list reports
  `TaskRow`**, what the card, the table row, the roadmap bar, the step
  panel and the Overview's queues render: the note's first line as
  `note_lead` (200 characters) and `checklist_done` / `checklist_total`
  instead of the notes and the items, and no `gh_assignees`,
  `gh_synced_at` or `pr_review_state`. `TaskView` is a `TaskRow` plus
  those (`obj TaskView(TaskRow)`, built as `TaskView(**vars(row), ...)`),
  reported by `GetTask` and every task write, so a page splices a reported
  view straight into its rows. The assistant's citations read
  `ListTaskTitles` (ids and titles of the working set), never a task page.
  `ensure_tallies(holder)` in `services/util.jac` fills tallies, link
  fields and a missing `done_at` for a project whose `tallies_at` is empty
  (one full load, once; `SaveProject` stamps a new project) and every
  counting or listing walker calls it first. Two runtime facts shape this
  (jac 0.37.18, verified in scratch apps): a field write is not visible to
  a pushed query later in the same request, only to the next one, so a
  walker that writes and then looks the same row up keeps it in a local
  (the sync's lookup caches, `others()` in `MoveTask`, the `except_id` in
  `forget_category`); and `jac fmt` collapses `field in list` inside a
  filter into one name (`ninwanted`), so there is no pushed `in`: short
  lists loop one query per value, a GitHub page over `LOOKUP_ONE_BY_ONE`
  numbers runs one range query kept to the page in Python. Loading costs
  about 0.2 ms per Task row locally plus 1 to 2 ms per query, so a walker's
  time is its working set: 209 rows at 1,500 tasks is about 60 ms.
- **The browser caches a declared reader for 60 s; the task lists are
  never cached.** The runtime caches a walker call (key: walker plus fields,
  in-flight dedupe, cleared by `jacSetToken`/`jacLogout`) only when the
  served effects table (`endpointEffects` in the shell's `__jac_init__`)
  says `unknown: false, writes: []`; any other call invalidates every cached
  reader before and after it. The compiler's effect pass marks a body
  unknown on any call it cannot classify (`len`, `sorted`, `.sort`,
  `.append`, `str`, an `obj` constructor) and a writer on `++>`, `del` or an
  attribute assignment, so a cacheable reader keeps its abilities to
  `visit` and `report` and does the work in a same-module `def` under
  `@effects(reads=[...], writes=[])` (`import from jaclang.lib.effects
  { effects }`): a decorated body is not scanned, its declaration is
  merged, a decorator on the walker itself is ignored, and a helper that
  another module imports is not recognised (`workspace_view`, imported by
  `board.jac`, lost its decorator; `GetWorkspace` reports through its own
  `read_workspace`), so a reader's helper is its own. Declared: `GetWorkspace`,
  `ListMembers`, `ListProjects`, `ListRoles`, `ListIterations`,
  `GetFlowLine`, `GetFlowLineMeta`, `ListRepos`, `GithubStatus`. Never
  declare a task list (`BoardSnapshot`, `ListTasks`, `OverviewSnapshot`,
  `ListLogEntries`, `TaskCounts`, `TaskHistory`, `RoadmapSnapshot`,
  `ListStepTasks`): a colleague's move, a webhook drain applied on the
  server or a sync from another tab would be invisible for up to 60 s.
  The flip side: an unknown call flushes every cached reader before and
  after it (a walker's `reads` is always `["*"]`, so nothing narrows it), and
  every page fires a task list in the same batch as `GetWorkspace`, so the
  runtime's cache alone never serves the workspace on those pages. That is
  why `lib/workspace.jac` keeps its own: `loadWorkspace` answers the last
  view while it is younger than 60 s and shares one in-flight read,
  `rememberWorkspace(view)` lets the board prime it from `BoardSnapshot`
  (`BoardData` carries the whole `WorkspaceView`), `forgetWorkspace()`
  drops it and `forgetSession` drops it too. **Every client call site that
  writes roster data calls `forgetWorkspace()` right after the write, before
  its refetch** (members, projects, roles, iterations, steps and
  transitions, the template and flow line name, repos and their switches,
  the GitHub connection, a sync, an assignment to a project, the org
  rename through `patchProfile`); a new writer must do the same or the
  next page shows the old roster for a minute. Recognition can vary between
  builds, so `tests/smoke/api_gate.py` asserts the served table per build
  (the readers cacheable, the task lists not, the mutators writing) and
  `browser_gate.py` counts the requests (board, tasks, roadmap, board make
  one `/user/me` and no `GetWorkspace`; a People-tab save then tasks makes
  exactly one). The trap that hid the cache
  until Sep 2026: a server `def:pub` in a module the client imports
  (`statusChip` in `components/flowlines/kinds.jac`) makes that module
  register a partial effects table at load, which the runtime uses instead
  of the served one, so every walker took the writer path. No server
  `def:pub` in a client-imported module, ever; `kinds` is pinned client and
  exports with `:pub` (the browser gate's first check is this table).
- **List walkers page, and build their rows in a local.** A walker's public
  `has` fields are serialised into the response (`data.result`) beside
  `data.reports`, so an accumulator field (`has results`) ships every row a
  second time. Rows go in a local and are reported once. Anything that grows with history (`ListTasks`,
  `ListStepTasks`, `ListLogEntries`, the GitHub walkers) takes `page` /
  `page_size` (1-based, clamped by `page_bounds` in `services/util.jac`) and
  reports one page object (`TaskPage`, `LogPage`, or the GitHub dict) with
  `rows`, `has_more` and `total`. The scope and a category filter are
  pushed into the query (`pool_of`), the other filters and the sort run on
  those rows, and the page alone is hydrated. Roster-sized lists (members,
  projects, roles, repos, steps) stay whole. `ListTasks` has a `scope`:
  `working` (open plus Done reached in the last `done_days`, what the board
  renders, `older` counting what the cutoff left out from the tallies, on
  an unfiltered page only), `older`, `done`, `all`; `q` is a server-side
  title search ranked exact, prefix, contains. `scope_total` on every
  page is the scope's count with no filter on (the pool when the page
  loaded the whole scope, else a tally or one more pushed read), so the
  table says "12 of 210" off its own page. `ListLogEntries` orders a day
  by stamp, newest first, the order every view shows, so a page fetched
  behind the first only adds rows below what is on screen, and it pages
  in the store: whole days are skipped on `LogDay.entry_total` and a day
  answers its slice ordered by `LogEntry.sort_key` (the stamp as digits,
  then the jid, so unique), which makes a page load its own rows only.
  Both are kept on write by `note_entry` / `forget_entry` in `models.jac`,
  so a new writer of log entries must call them; a day from before them
  (`entry_total` -1) is keyed and counted once by `fill_day` on its first
  read. A GitHub import logs once per batch (`log_imports`, called at the
  end of `ImportIssues`, a sync pass and a drain): one issue keeps its own
  line, more grow the day's `Imported N issues from org/repo` line for that
  repo and status (`item_count`, no task), which the log page folds with
  the single lines. The log's counts (`log_totals`, so `LogCounts` and the
  Overview) read each day's `entry_total` and `member_counts`, kept by the
  same helpers; `fill_day` tallies a day written before them, once, and
  folds a backfill of more than `IMPORT_FOLD_MIN` single import lines for
  one repo and status into the day's batch line. The Overview's blocked
  reasons are one pushed query per blocked task (`blocked_lines`), no log
  load. `GetFlowLine` counts and
  `ListStepTasks` lists the same working set (`done_days`), so a done step
  shows recent Done the way the board's column does; the count's pass over
  that set also keeps each step's first two titles (`StepView.task_titles`,
  the panel's order), so the flow line page's close zoom reads them off
  the line and makes no request.
  The Overview adds up history through `TaskCounts` / `LogCounts` rather
  than loading it. Every ordering ends in the jid, so a row cannot swap
  pages between two requests (sorts are stable, so a `jid` pass first and
  the real key second gives a deterministic tiebreak).
- **`constants.jac`**: `STATUSES`, `PRIORITIES`, `STEP_KINDS`, `KIND_COLORS`,
  `KIND_STATUS`, `STATUS_KIND` and `FLOW_LINE_TEMPLATES` as `glob`s shared by
  client dropdowns and server validation.
- **`main.jac`**: entry point. **A walker missing from its import list 404s**,
  and the entry module cannot use relative imports (`import from models {…}`,
  not `.models`); modules under `services/` likewise import bare, by the
  full dotted path (`import from services.tasks.tasks {…}`).

### The flow line drives the board

An org designs its own steps on `/flowlines` (`WorkflowStep` nodes under the
`WorkflowSteps` box, transitions stored on each step, cycles allowed on
purpose). **The
board's columns ARE those steps**, in `sort_order`, so the two views cannot
disagree. The feature was called "workflow" until Aug 2026; the archetypes
keep that name. `/workflow` redirects to `/flowlines` for old links.

Each step carries a semantic `kind` (`start` / `active` / `handoff` /
`blocked` / `done`) behind the user's chosen name. **Roughly thirty places key
behavior on what a status MEANS** (`Done` is terminal, `Blocked` needs
attention, `Review` is a handoff), so every task write sets `step_id` *and*
the mapped legacy `status` via `KIND_STATUS`. Insights, GitHub sync, the
assistant and the log therefore never learn what a step is; keep it that way
rather than teaching them.

**Write `status` through `Task.set_status(status, stamp)`, never by
assignment** (a constructor passes `done_at` itself). It stamps `done_at`
when a task enters Done and clears it when it leaves; `done_day(t)` and
`moved_to_done(t)` in `services/util.jac` are the done date (falling back to
`updated_at` on older rows) and the rule that a task created straight into
Done is history, not throughput (`seeded_done` in `models.jac`, which the
`seeded_done_total` tally counts). The Overview's weekly Done count,
`TaskHistory` (burn-up, throughput), the snapshot's done-in-period and the
board's working scope (the pushed `done_at >= cutoff`, the same test as
`done_day` once `ensure_tallies` has filled every Done row's `done_at`) all
read those two, so they agree. `set_status` also moves the project's Done
tallies, which is one more reason never to assign `status`. A GitHub import writes the
issue's own `created_at` and `closed_at`, so a closed issue lands in the week
it was really closed and ages out of the board like any other task;
`SyncGithub(full=True)` re-walks a repo and corrects rows an earlier import
stamped with the sync time.

Tasks with an empty `step_id` (written before flow lines existed, or whose step
was deleted) fall back to `STATUS_KIND[status]` and render in the first column
of that kind; an org with no flow line at all falls back to `STATUSES`. Both
fallbacks are load-bearing: do not assume a task has a step.

### Security model: the one thing not to regress

Isolation is structural: authenticated walkers run on the caller's own root, so
`[root --> …]` cannot reach another tenant. `jobj(id)` is owner-gated on
0.37.7 (a foreign root or node resolves to `None`, even for the system
identity), **but resolution is still not authorization.** Every jid-addressed
mutation must call `owned(holder, target)` (or go through the `find_task` /
`find_log_entry` lookup bases) before touching anything. `owned` climbs
container edges (at most three hops: task, project, box; or log entry, day,
box) and compares each
parent's jid with the caller's root. `Root` is not a runtime name in
`models.jac`, so nothing there may `isinstance(x, Root)`. That gate is also why
the webhook receiver cannot apply a delivery itself: it queues, the tenant
drains (see `services/github/events.jac`).

**An uncaught walker exception returns its message to the browser** as a 500
`EXECUTION_ERROR` (since jac 0.37.18 the traceback goes to the server log
only), and a message can still carry a URL or a config hint. Anything that can fail outside our control (the LLM, GitHub) is
caught inside the walker, logged server-side with the operator hint, and
reported as an empty or `{"ok": False, ...}` result; the client shows a plain
"not available right now". See `_llm_failed` in `services/assistant/assistant.jac`
and `gh_request` in `services/github/util.jac`.

Watch the container variable inside abilities: in a `Task`/`LogDay` entry
ability `here` is the *task or day*, not the root; the caller's root is
`root`. Getting this wrong silently drops assignee and project links rather
than erroring.

**Webhook deliveries never touch a tenant graph from the receiver.**
`GithubEvent` (system identity) checks the `installation.id` against the
`gh_installations` index that `CompleteGithubInstall` writes, drops the App's
own echoes, and inserts the delivery into `gh_deliveries` keyed by GitHub's
delivery id, so a redelivery is a primary-key no-op. `drain_deliveries` runs
in the tenant's session (from `DrainGithubEvents` or the start of
`SyncGithub`), reads only its own installation's rows and only when the index
binds that installation to this root (the workspace that last connected it),
drops items older than the task's last applied `updated_at`, stamps the log
with the event's own time, and applies through the helpers the poll uses.
Neither side calls GitHub. The one write-back is the issue's state for a repo
with `auto_close`: a move that crosses Done closes the issue (landing) or
reopens it (leaving). It runs inside `MoveTask` / `UpdateTask` through
`sync_issue_state` in `services/github/util.jac` (not in
`services/github/github.jac`: that module imports `tasks`, so `tasks` cannot import
it back); it rides on the move's own log line, and the receiver drops the
App's echo by sender login so neither is applied a second time. An issue
reopened on GitHub does not move its card; titles, assignees and labels are
never written back.

**No walker a page load calls reaches GitHub.** The poll is
`sync_connected_workspaces` in `services/github/schedule.jac`, a plain `def`
under `@schedule(trigger=ScheduleTrigger.STATIC, interval=SYNC_INTERVAL_SECONDS)`
(300 s; `FLOWLINE_SYNC_INTERVAL_SECONDS` overrides it for the gates, CI
uses 30), registered by its import in `main.jac` like a walker. It runs in
the app workers as the system identity, one worker per tick through the
runtime's `sched:` lease on the Postgres store, walks the `gh_installations`
index (`bound_installations`), skips a workspace bound inside the last
interval (still being set up on its GitHub page), takes the per-workspace
lease `sync:<root jid>` (`acquire_sync_lease`, `SYNC_LEASE_SECONDS` = 240,
released after the pass) and spawns `SyncGithub(auto=True)` inside a pushed
context on that workspace's root (`Jac.create_j_context(user_root=jid)` +
`push_request_context`; `here` and `root` in the walker are that root, so
`owned()` works unchanged), commits, closes, and logs one `flowline.github`
line per workspace with the counts. Schedule a function, never a walker: a
decorated walker loses its `/walker/` route and logs a spurious error per
fire on 0.37.18, and static fires do not serialise themselves, hence the
lease. `SyncGithub` keeps drain-then-poll: the auto cooldown (1 min quiet,
15 min while deliveries are live, both shorter than never) gates only the
poll, the token is minted only when a poll will run, an invalid connection
reports `invalid` without a call, and a manual sync (`auto=False`) holds the
same lease with owner `manual` so the schedule stays out of a workspace
someone is syncing by hand. A pass that reaches the end of every stream
rewrites the repo's stored open issue and pull request pages
(`gh_repo_lists` in the docs store, keyed by repo jid, kind and state;
`RemoveRepo` drops them); `ListRepoIssues` / `ListRepoPulls` answer page 1
from that store with `synced_at` and `stale` and call GitHub only with
`refresh=True` (the page's Refresh button, and once for a repo with no
stored page yet) or for a later page. The board spawns no `SyncGithub` on
open; it keeps `DrainGithubEvents` on its timers and the manual Sync
button. The webhook gate asserts a board and GitHub page read make no stub
call (the stub records each call's bearer), and that the scheduled pass
syncs a workspace nobody opens; the browser gate asserts a board open
spawns no sync. The webhook gate's own drain checks stay deterministic
because every workspace it drives is inside the grace window or holds the
manual lease, so add a manual `SyncGithub` after a new workspace's connect
if a section grows past one interval.

### Client

File-based routing with route groups:

| Path | File | Access |
| --- | --- | --- |
| `/` | `pages/(public)/index.jac` | public landing page |
| `/login` | `pages/(public)/login.jac` | public; `?mode=signup` opens the signup tab |
| `/auth/callback` | `pages/(public)/auth/callback.jac` | receives `?token=` from SSO |
| `/board`, `/tasks`, `/roadmap`, `/log`, `/overview`, `/flowlines`, `/workspace`, `/github`, `/setup` | `pages/(auth)/…` | auto-guarded |
| `/settings`, `/projects`, `/roster`, `/workflow` | `pages/(auth)/…` | redirects only: `/settings` goes to `/workspace?tab=preferences` |

- **`pages/layout.jac` is path-aware**: app chrome renders only for
  authenticated, non-public paths (`PUBLIC_PATHS`), otherwise the landing page
  would show two navs. Do not add a `layout.jac` inside `(auth)/`: it
  collides with the root layout. The chrome is a top bar grouped into daily
  views and setup pages (`NAV_PAGES` in `CommandPalette.jac`, shared with the
  palette and the phone tab bar), an account menu with the signed-in identity
  and the theme, and `components/assistant/AssistantDock` (Ask), mounted once:
  a docked column at 1280px and up, a sheet below. `/setup` gets only the mark
  and Sign out.
- **`/workspace` is every setting**: Organization, People, Projects, Roles and
  Preferences (the theme) as `?tab=` sections from `components/workspace/`.
  The page loads one `GetWorkspace` and hands the Projects and Roles
  sections their lists as props (open counts are the projects' own
  tallies), so a tab switch is a render, not a request; a section's write
  calls `forgetWorkspace()` and awaits the page's `loadAll` (`onChanged`)
  rather than refetching a list of its own. GitHub lives at `/github`;
  `?tab=github` and install round trips forward there with the query intact.
- Pages are **thin stateful shells**: they own `has` state and handlers (bodies
  in `.impl.jac` annexes under `pages/(auth)/impl/`) and compose presentational
  components from `components/<area>/` (`board`, `tasks`, `roadmap`, `log`,
  `dashboard` for the Overview, `flowlines`, `workspace`, `github`, `roster`,
  `projects`, `assistant`, `auth`, `landing`, `common`).
- Form-heavy dialogs take a `dict` plus one `onField(key, value)` callback
  rather than a dozen props.
- **`components/ui/`** is jac-shadcn: import only, never edit. When a
  registry component ships broken, keep the fixed copy under a name
  `jac install --shadcn <name>` cannot write to, or the next install
  silently restores the bug: `toaster.jac` (not `sonner.jac`). The
  Checkbox once needed the same treatment (`tickbox.jac`, for a stray
  `# noqa` text node); the registry copy at jac 0.34.14 is clean, so
  `checkbox.jac` is imported directly again.
- **A list paints after its first page; the rest lands behind it.** The
  board's first load (`loadBoard`, `paintPages`) shows page 1 of
  `BoardSnapshot` and appends the pages behind it (the working set is one
  `sort_order` run, so a later page lands under the cards on screen; the
  newest load owns the state through `loadReqRef`); a refetch keeps its
  rows until the whole set is in. The log week (`weekPage`) and the
  Overview's week log (`absorbWeekLog`) do the same. Nothing is fetched
  twice on a mount: the log page starts on today rather than writing
  `selectedDate` in an entry (the live-cell gotcha below), and the tasks
  table's scope count rides on its page (`scope_total`).
- **A page fires the workspace read beside its own data, never after it.**
  `lib/workspace.jac` `loadWorkspace()` answers a dict keyed like
  `WorkspaceView` plus `ok` from its minute-long cache, or spawns
  `GetWorkspace` (the empty shape on failure, so a page keeps its own
  failed-load handling). Every page other than the
  board calls it as `loadShared` together with its own walker
  (`w.Promise.all(jobs)`), and no page awaits more than two calls in
  sequence on mount; only `/github` has a dependent third (the issue list
  once the repo is known). A refetch of one list after a save may still
  call that list's walker. Its two helpers are pinned `"client"` in
  `jac.toml`, like `lib/utils`.
- **`lib/session.jac`** wraps `/user/me` (the runtime exports no helper)
  and reads it once per page load: `fetchMe` keeps the in-flight promise and
  the answer in module state, `fetchProfile` / `fetchOrgName` and the
  layout's `loadMe` go through it, and `patchProfile` or `forgetSession`
  drops it.
  **`lib/dates.jac`** owns the calendar rules (`todayIso`, `daysUntil`,
  `dueTone`, `dueLabel`): the card, the lane header and the overview all
  derive "overdue" from it, so change it there or nowhere.
- **`components/common/`** holds the shared bits: `Avatar.jac` (initials
  avatars on eight fixed fills hashed from the name, `AvatarStack` for
  assignees), `KindGlyph.jac` (a step kind as a glyph), `StepName.jac` (a
  step's swatch plus name), `CommandPalette.jac` (⌘K), `ErrorNote`,
  `LoadFailed`, `glyphs`, `Markdown`.
- **The visual system lives in `styles/global.css`.** Archivo (the
  `wdth.css` import, so `font-stretch` works) for UI and display, IBM Plex
  Mono for data, shadcn token names on a neutral ground with one rust
  primary. Shared classes (`.page-title`, `.meta`, `.num`, `.toolbar`,
  `.toolbar-filter`, `.data-table`, `.step-swatch` ...) are defined there;
  the two that dress registry primitives sit outside `@layer` so they beat
  the primitives' utilities. Nothing renders below 12px, labels are
  sentence case, and only floating layers cast a shadow.
- **Step colours are tokens.** `--step-<key>`, `-ink` (text) and `-wash`
  (opaque canvas fill) in `styles/global.css` for both palettes; the tables
  in `components/flowlines/kinds.jac` only name them (`bg-step-sky`). A new
  colour key needs tokens in both palettes, and its key is what persists
  (`rose` renders orchid, clear of the andon red).
- **One task sheet everywhere.** `components/board/TaskDialog` is a right-side
  sheet (route breadcrumb, Move menu, properties, notes, checklist, and "Travel
  so far" from `ListLogEntries` with `task_id`); only the board passes `beside`
  so it stays non-modal next to the lanes. Clicking a step in the flow line
  page's view mode floats `StepTasksPanel` over the diagram (a bottom sheet on
  phones), and a row opens the sheet on the same form dict and the same
  `UpdateTask` / `DeleteTask` walkers the board drives it with. `/tasks`
  does the same for its rows, and keeps scope, filters, sort and page in the
  URL (`replaceState`, defaults omitted); its Step column and `ListTasks`
  `sort="step"` follow the board's column order and placement rule. `/roadmap`
  opens it from a bar. **`UpdateTask` overwrites every field**, so each page
  that opens the sheet must carry `start_date` and `iteration` (a jid or
  `"none"`) in its form and pass them on save, or a save clears them.
  **The sheet loads the open task's `TaskView` itself** (`GetTask` in its
  entry ability, since a list row carries no notes or checklist items): the
  checklist stays in the sheet's own state, the notes go to the page's form
  through `onLoaded` (the page seeds `"notes": ""` on open and the board
  rebases `baseForm` too, so the load never reads as an edit), and Save
  stays off until the view lands, or it would write empty notes over the
  real ones.
- **A task's checklist is not part of the form.** `Task.checklist` is written
  only by `AddChecklistItem` / `SetChecklistItem` / `RemoveChecklistItem`,
  each applied at once from `components/board/Checklist.jac`, so a sheet
  save (`UpdateTask` overwrites every field it is sent) cannot clobber it. A
  page that opens `TaskDialog` passes `taskId`, `onLoaded` and an
  `onChecklist` that swaps the reported view into its rows (its
  `checklist_done` / `checklist_total` are what the card shows).
- **The board polls, it does not react to focus.** `BoardSnapshot` every
  `POLL_MS` (60 s); a tab return refetches only when the snapshot on screen
  is older than that; `DrainGithubEvents` every `DRAIN_MS` (20 s) only while
  `webhook_live` (the workspace view: a delivery inside the server's
  `LIVE_WINDOW_MINUTES`, or a drain that just landed rows), otherwise once
  per poll ahead of the refresh. It never spawns `SyncGithub` on open: the
  server schedule polls (see the GitHub section above).
- **Board deep links**: `/board?task=<id>` opens a card, `/board?new=1` the
  new-task sheet (setup lands there after applying a template); an already
  mounted board listens for `flowline:open-task` / `flowline:new-task` instead
  (the palette uses both paths).
- **A log entry's `member_name` is every assignee comma-joined**, so split
  it before comparing to a member.
- **`brand/logo.jac`** generates every logo variant into `assets/brand/` and
  **`brand/social.jac`** draws `og-image.png` (fonts from `node_modules`, so
  `jac install` first); edit the generators, not their output. Reference brand
  assets as **`/static/...`**, not `/assets/...`: Vite owns `/assets/*` at
  build time.

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
`max_replicas`. **The gateway gets an HPA of its own** with the same
`[scale.kubernetes]` bounds unless `[scale.gateway.hpa]` sets them (it does:
1 to 2); four gateway pods on dev (2026-09-14) were that inheritance plus a
512Mi request sized for one worker while `[serve.workers]` gives the gateway
two. `[scale.monitoring] k8s_metrics_enabled` and `[scale.gateway.logs]`
each add a per-node DaemonSet (node-exporter, Alloy) to the namespace on the
shared cluster, so both stay off; the deploy gate checks the gateway range.
The dry-run command above renders the manifests locally
once `bundle_storage_class` is set to any name (a placeholder for the RWX
check that a real deploy satisfies on the platform); `tests/smoke/
deploy_gate.py` asserts its transcript in CI.

**`[project] entry-point` is the dotted module name, `main`.** jac 0.37.12+
refuses `"main.jac"` on load. The jachammer deploy manager used to check the
key as a file path, so between the pin bump and the platform's 2026-09-14
release the line had to be omitted entirely (jaseci-labs/jacBuilder#1806,
fixed by its #1808); the platform now resolves either spelling to the file.

## Jac gotchas that have already cost real debugging time

- **A computed key does not survive a dict-literal spread.** `{**form, key: v}`
  compiles to JS `{...form, key: v}`, a *literal* `"key"` property, so bound
  inputs freeze. Use `updated = {**form}; updated[key] = v; form = updated;`.
- **Never name a module after an npm package it imports.**
  `components/ui/sonner.jac` importing `"sonner"` resolved to itself → infinite
  React mount loop that pinned the main thread. It lives in `toaster.jac`.
- **No Python imports in modules the client imports types from.** A stray
  `import datetime` in `models.jac` dragged `@jac/wasm_host` into the browser
  bundle and broke the build; that helper lives in `services/util.jac`.
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
  whole Vite build fails with a 503 at request time (`jac check` passes:
  the clash only exists in the emitted JS). Name the method something else.
  Worse, an **imported function** named `set<Field>` doesn't even fail the
  build: the generated setter shadows the import silently, so every call
  updates React state instead of doing its job (issue #131, `setThemePref`
  vs `has themePref`). Never declare a `has` whose setter name an import uses.
- **A docstring as the first statement of a plain `def` is a parse error**:
  use a `#` comment above the `def`.
- **A page mounts once, because the layout reads `jacIsLoggedIn()` at render
  time.** Until Sep 2026 it read it in `can with entry` (an effect), so every
  full load painted a bare page first and then remounted it inside the
  chrome, and the pages grew defences that must stay: a one-shot URL param
  is read in entry but consumed in the effect that acts on it (see
  `pendingTaskId` on the board), and a call that must reach the server
  exactly once (the GitHub install completion, #187) strips the param and
  starts the call BEFORE the first await, keeps the in-flight promise in
  module state, and awaits that same promise from every mount. Keep those
  patterns: a `has` flag or a `Ref` is per instance, and a remount is still
  one route change away.
- **The page is blank until the bundle runs, then paints its frame at
  once.** The HTML shell is an empty `#root` plus the bundle: there is no
  boot script, `jac.toml` carries plain metadata only. (An inline
  `[[client.app_meta_data.scripts]]` placeholder was tried on 2026-09-17;
  the jachammer deploy runner rewrites `jac.toml` while staging and cannot
  carry a multi-line string, so it failed every deploy and was dropped.)
  The header reads the cached workspace name and account from `lib/session.jac` (`flowline-org`,
  `flowline-account`, written when `/user/me` resolves), so it never shows
  the wordmark and then the name. A page renders its loaded frame with
  skeleton rows on the first data load only, sized by per-browser caches of
  the last visit (the `*_KEY` globs in `lib/session.jac`: lanes, overview,
  log, roadmap, GitHub; the log writes today's view and the roadmap the
  unfiltered one). `forgetSession` clears every cache when a session starts
  or ends, so another account never inherits a name or a shape. The swap to
  the content goes through `components/common/Reveal` (a 150ms cross-fade in
  one grid cell, so no frame in between is blank; the frame comes back if
  `ready` drops with nothing on screen, a retry after a failed first load)
  and a page never re-skeletons: a refetch keeps the rows under `aria-busy`
  and shows `components/common/Busy` after 300ms.
- **`{if}` inside a `{for}` slot body takes no braces** (`if x { <li/> }`,
  not `{if x {…}}`): the compiler rejects the wrapped form (E2023).
- **Placement is inferred and pinned in `jac.toml`, never in source.** Since
  jac 0.35 the `cl`/`sv` markers are syntax errors; `[placement.pins]` is the
  override. `models` and every `services` module carry a module-level
  `"server"` pin, keyed by the dotted path (`"services.github.events"`):
  without it a page's plain import of a walker pulls the whole module
  (abilities included) into the browser bundle and the build dies with
  "Client pathway failed to lower this edge reference shape". **A new
  service module needs its own pin line.** The three `lib/utils`
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
- **A dependent entry reads the live cell, so an entry write fires it
  twice.** `can with [x] entry` runs on mount and reads `x` through the
  cell; an `entry` that assigns `x` in the same commit is visible to that
  mount run, and the re-render's changed deps run it again (the log page
  fetched its week twice, #225). A value known at render time is the `has`
  default (`selectedDate: str = todayIso()`), never an entry assignment.
- **A Radix `Select` shows its placeholder only for the value `""`.** A
  sentinel such as `"none"` with no matching item renders an empty
  trigger and no muted styling. Seed `""` for "nothing picked" (project on
  the task sheet and the repo picker); keep a sentinel only where an item
  carries it (the reviewer's "No reviewer").
- Client-side: `is None` misses `undefined`; `params["id"]`, never `.get()`;
  rebind state rather than mutating.

## Verification

**API gates**: the suite lives in the scratchpad, not the repo; it signs up two
accounts and asserts CRUD plus tenant isolation: cross-account reads return
nothing, and foreign-jid `UpdateTask` / `MoveTask` / `DeleteTask` /
`AssignToProject` / `UpdateLogEntry` / `SaveProject` / `ArchiveMember` are all
no-ops, and every list filter (`project_id`, `assignee_id`, `step_id`,
`task_id`) yields nothing for a foreign id. Paging gates: pages partition
the set with no repeats, `total` is stable across pages, a page past the end
is empty, `page_size` clamps. Re-run something equivalent after touching
walkers or `owned()`. The repo's `tests/smoke/api_gate.py` carries the
tally parity suite: tasks across statuses, projects, members and
categories, some created Done and some moved there, then deletes and a
re-parent, and `TaskCounts`, `BoardSnapshot`, `TaskHistory`, `GetFlowLine`
counts and `ListTasks` totals must equal a brute-force pass over
`ListTasks(scope="all")` each time. Run it after touching a tally write
point or a reader.

**Browser QA**: use `agent-browser`, and note that **`agent-browser type` does
not reliably trigger React onChange** (it sets the value in a way React's
tracker ignores, making working inputs look broken). Use `agent-browser
keyboard type` for real key events. Assert on rendered text, not just
coordinates: a stale `@eN` ref can produce a phantom pass.

**Docs site** (`docs/`, MkDocs Material, published to GitHub Pages by
`.github/workflows/docs.yml`). The API and data graph reference is generated
from the `.jac` sources by `docs/hooks/jac_docs.py`: a new or renamed walker
needs a `::: walker <Name>` line on its `docs/content/api/` page, or the
strict build fails. Build with `mkdocs build -f docs/mkdocs.yml --strict`.

**CI** (`.github/workflows/ci.yml`) runs on every PR and on pushes to
`main`/`dev`. The `serve` job installs the pinned jac, runs `jac install`,
asserts the deploy dry run would build the client bundle with two workers
(`tests/smoke/deploy_gate.py`), boots `jac run --no-dev` and drives it:
`tests/smoke/api_gate.py` (shell, bundle, register, login, walkers, a
concurrent burst), `tests/smoke/webhook_gate.py` (the GitHub integration end
to end against `tests/smoke/github_stub.py`, a local stand-in for the few
GitHub endpoints the app calls: the connect round trip binds the
installation, the poll back-fills, signed deliveries are queued by the
receiver and applied by the drain, three workspaces stay isolated; the App
env and `GITHUB_API_BASE` / `GITHUB_WEB_BASE` come from the workflow, no
secrets) and `tests/smoke/browser_gate.py` (Playwright: sign up, finish the
three-step setup on the Simple template, land on the board with the new-task
sheet open and the template's steps applied, create a task and see the card
survive a reload, then land on GitHub's install redirect against the stub and
check the page finishes it with exactly one `CompleteGithubInstall` request). The `jac` job runs
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

**SSO**: the HMR dev server (`jac run main.jac`) has not proxied `/sso` to
the API (only `/walker`, `/user`, `/function`, `/graph`, `/admin`, `/static`,
`/assets`, `/docs`, `/introspect`), so exercise SSO with `jac run --no-dev`. The initiate
endpoint requires a `client_callback` query param, which `jacSsoLogin` does not
send, so `components/auth/SsoButtons.jac` builds the URL itself. It also finds
the configured providers by following `GET /sso/{platform}/callback`, which
redirects to `[scale.sso] client_auth_callback_url` with
`?error=SSO_NOT_CONFIGURED` when a provider has no credentials (`${VAR:-}` in
`jac.toml` keeps an unset pair empty). A missing `client_auth_callback_url`,
or a `HOST` that does not match the served origin, therefore hides both
buttons. The answer is cached (`flowline-sso` in localStorage) and probed
again once per tab, so check a config fix in a new tab.

## Repo conventions

- **`main` is protected**: branch → PR → merge. Direct pushes are rejected for
  everyone, including admins. Merged branches auto-delete.
- **No `Co-Authored-By: Claude` trailers** in commits.
- `PLAN.md` (current working plan) is gitignored; shipped plans are archived in
  `plan-archive/`.
- Product copy must describe what the app actually does. The source design mock
  carries invented testimonials, usage metrics, pricing and integrations
  (Slack/Teams, blocker alerts, a 14-day trial); none of that shipped, and the
  FAQ states the honest "not yet" answers instead.
