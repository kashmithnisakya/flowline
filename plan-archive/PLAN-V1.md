# standup — Kanban Project Tracker, v1 Plan

Replaces `reference/Team_Activity_Tracker_v9.xlsx` (Team Roster / Daily Log / To Do List /
Dashboard) with a Jac 0.34.6 full-stack web app using **jac-shadcn** UI.

## Product shape

Three pages, file-based routing, no login in v1 (same trust model as the shared
spreadsheet — identity is a localStorage "who am I" member picker):

| Route | Page | Replaces |
|---|---|---|
| `/` | **Board** — 6-column kanban of tasks, drag-and-drop + arrow-button fallback, filters defaulting to the viewer's team | To Do List sheet |
| `/log` | **Daily Log** — one row per person per weekday, exact sheet columns, form prefilled from WhoAmI, This-Week count strip | Daily Log sheet |
| `/roster` | **Roster** — members table + GitHub repos list; feeds every dropdown | Team Roster sheet |

**One status vocabulary** everywhere (board columns = log dropdown):
`Backlog, In Progress, Review, Changes Requested, Done, Blocked`
(union of both sheets' status lists; "Not Started" renamed Backlog). Task Category
(`Architecture, Reviewing, Coding`), Teams (`Jac Core, Jac Scale, Jac Builder, Jac Mobile, CA`),
Priority (`High, Medium, Low`), and Jac Scale Sections live in `glob` lists — adding a value
is a data edit, not a schema migration.

**Deliberate v1 exclusions:** login/accounts, the Dashboard sheet (column count badges +
This-Week strip cover the most-read numbers), GitHub API integration (issue/PR links stay
plain URLs), log↔task linking, live sync (refetch on focus + 60s poll instead).

## Scaffold

The current guestbook was `jac create --kind web-app`; the shadcn installer refuses to
retrofit, so re-scaffold in place:

```bash
jac create --force --use jac-shadcn          # in standup/ — keeps git repo
jac install --shadcn badge select dialog table dropdown-menu sonner skeleton \
    input textarea label separator            # button + card ship with the template
```

Delete guestbook remnants (`endpoints.jac` Message walkers, `frontend.jac`,
`frontend.impl.jac`, `components/MessageCard.jac`).

Rules that follow from the template:
- Primitives live in `components/ui/` — **import only, never edit or re-implement**.
  Hyphenated registry names install as underscored files: `import from .ui.dropdown_menu { … }`.
- Import prefix depends on where you are: from `components/X.jac` → `.ui.button`;
  from `pages/X.jac` → `..components.ui.button`; `cn()` always from `lib/utils`.
- Tailwind is pre-wired; style with utility classes + `cn()`. No `.style.css` annexes,
  no `*` CSS reset (breaks Preflight).

## Data model (all in one server module — module path is part of persisted archetype identity; settle layout BEFORE importing real data)

```
node Member  { name, team, role, email, github_username, section (Jac Scale only), active: bool = True }
node Repo    { full_name }                          # "jaseci-labs/jaseci" dropdown list
node Task    { title, category, team, priority, status, due_date (ISO str), notes,
               created_at, updated_at (ISO str), sort_order: float }
node LogDay  { date (ISO yyyy-mm-dd) }              # unique day bucket, get-or-create
node LogEntry{ activity, category, repo, issue_link, pr_link, status, notes,
               member_name, team, section }          # member fields denormalized at write time

edge AssignedTo: Task --> Member {}                  # typed endpoints → typed traversal
edge Logged:     LogDay --> LogEntry {}
edge By:         LogEntry --> Member {}
```

All dates/timestamps are **ISO strings, never `datetime`** (no client marshalling exists).
Archiving a member sets `active=False` — never `del` — so history edges survive.
`LogEntry` denormalization is deliberate: historical rows render exactly like the old sheet
even after roster edits (document it; it is not a bug).

Report channel: `obj MemberView / TaskView / LogEntryView` — node fields + `id: str = jid(node)`;
`TaskView` joins assignee over `AssignedTo`. Client holds typed lists and passes `jid`
strings back into walkers (**never node objects, never Python `id()`**; nodes cannot be
constructed client-side).

## API — all `walker:pub` (bare walkers require JWT; v1 has no auth)

Walkers everywhere for one consistent call style, the proven 0.34.6 precedent
(`jaseci/jac/examples/day_planner`), and because the lookup-base pattern localizes the v2
`walker:priv` migration to one place per concern.

| Walker | Notes |
|---|---|
| `ListMembers / SaveMember(member_id="") / ArchiveMember` | empty id = create, else `jobj` + `isinstance` guard; one save walker for add+edit |
| `ListRepos / AddRepo / RemoveRepo` | repo dropdown CRUD |
| `ListTasks` | all tasks + assignee; client-side filtering is fine at ~100 cards |
| `find_task(task_id)` | abstract base: `jobj` → `isinstance Task` → `visit [target]` |
| `CreateTask(…, assignee_id="")` | status=Backlog, `sort_order` = end of column, `+>:AssignedTo:+>` |
| `UpdateTask(find_task)` | full-field save; rewire assignee by deleting the typed edge (`[edge …]` then `del`) and reconnecting |
| `MoveTask(find_task)(status, sort_order)` | the drag/arrow endpoint; sets status + fractional sort_order + updated_at |
| `DeleteTask(find_task)` | delete lives only in the edit dialog |
| `ListLogEntries(from_date, to_date)` | `[root-->(?:LogDay, date in range)]` → `[->:Logged:->]` |
| `LogActivity(date, member_id, …)` | get-or-create day bucket via `visit … else { fresh = here ++> LogDay(…); visit fresh; }` |
| `UpdateLogEntry / DeleteLogEntry` | correcting today's rows |
| `ImportCsv(sheet, csv_text)` | one-time migration: `roster` / `repos` / `todo`; idempotent (skip existing by name); **test against the real workbook export** |

Walker idioms (authoritative for 0.34.6): accumulate into `has reports: list[XView] = []`
(the `= []` default is mandatory) and report once from a `Root exit` ability; kwargs only
at spawn sites; fresh ordering = fractional `sort_order` (midpoint between neighbors),
with a renormalization walker deferred to v2.

## UI (shadcn primitives + Tailwind)

```
main.jac                      # def:pub app(children) rendering {children} — MUST render children or all routes silently drop
pages/layout.jac              # JsxLayout: top nav (Board/Log/Roster) + WhoAmIPicker + <Outlet/>
pages/index.jac  + .impl.jac  # BoardPage (JsxPage) — stateful shell: all has-state + handlers
pages/log.jac    + .impl.jac  # DailyLogPage
pages/roster.jac + .impl.jac  # RosterPage
components/WhoAmIPicker.jac   # Select of members, persisted to localStorage; drives team-default filter + log prefill
components/FilterBar.jac      # Select: team (defaults to viewer's) / assignee / category + hide-Done toggle
components/KanbanColumn.jac   # column header + Badge count; onDragOver(preventDefault)/onDrop
components/TaskCard.jac       # Card, draggable; Badges for team/priority/category; red blocked strip; ← → arrow move buttons; click opens dialog
components/TaskDialog.jac     # Dialog: create/edit form (Input/Textarea/Select/Label), Delete inside
components/LogEntryForm.jac   # add-activity row, prefilled from WhoAmI
components/WeekStrip.jac      # This-Week counts by status/category, computed client-side
components/MemberForm.jac + RepoManager.jac
```

- Stateful-shell architecture: the page owns every `has` field and async handler
  (implemented in its `.impl.jac`, where fields are bare — no `self.`); child components
  are stateless, typed props down, `Callable` callbacks up.
- Drag-and-drop: native HTML5 (fully typed in the compiler; no DnD lib — none precedented).
  Copy jacBuilder's FileTree conventions: custom MIME `text/x-standup-task` in
  `dataTransfer.setData` so foreign drags are ignored; `e.preventDefault()` in dragOver;
  `handler.call(None, …)` when invoking prop callbacks from lambdas.
- Moves are **optimistic**: rebind local state, spawn `MoveTask`, roll back + Sonner toast
  on failure. Arrow-button fallback ships in the same milestone (touch devices).
- Rendering: `{for (i, t) in enumerate(tasks) { <TaskCard key={jid(t)} …/> }}` — `jid` is
  the React key; `{if cond { … } else { … }}` slots; `skip;` for empty states.

## Milestones (each independently testable; ~9 working days total)

1. **M1 — Scaffold + backend spine**: re-scaffold jac-shadcn; delete guestbook; globs;
   Member/Repo nodes + roster walkers; routing shell with 3 stub pages.
   *Test:* `jac check` clean; walkers respond via curl; nav renders.
2. **M2 — Roster page** end-to-end (table + MemberForm + RepoManager).
   *Test:* add/edit/archive survives `jac start` restart.
3. **M3 — Tasks + read-only board**: Task node, `find_task` family, board with 6 columns,
   cards, TaskDialog create/edit, FilterBar with team-default + hide-Done.
   *Test:* cards land in correct columns; filters work.
4. **M4 — Board interactions**: MoveTask + fractional ordering; HTML5 drag; optimistic
   update/rollback; arrow-button fallback.
   *Test:* drag across all 6 columns; reload preserves order; failed move rolls back.
5. **M5 — Daily Log**: LogDay/LogEntry walkers; date navigator + week toggle;
   sheet-identical table; LogEntryForm prefilled from WhoAmI; WeekStrip.
   *Test:* two members logging the same day → exactly one LogDay; row edit/delete.
6. **M6 — Migration + ship**: ImportCsv; import the real workbook with the team lead;
   empty states; focus-refetch + 60s poll; deploy internally; 15-min team walkthrough.
   *Test:* imported data matches the sheet row-for-row.

## 0.34.6 gotchas (each verified in compiler source — will bite otherwise)

- **State**: `has` = `useState`. In-place mutation (`append`, `[i]=`, `.sort()`) never
  re-renders — always rebind. After any `await`, `has` reads are stale render-time
  snapshots — accumulate into locals, assign once. Client `sorted()` needs a named key fn.
- **Spawns are auto-awaited** (enclosing fn must be async, but never write `await root spawn`);
  `def:pub` RPC calls must be explicitly awaited. Errors throw — wrap in try/except with
  loading/error state. A 401 hard-reloads the page (moot until v2 auth).
- **60s reader cache**: writers invalidate overlapping readers — write-then-refetch is
  the canonical mutation shape and actually hits the server.
- **Routing**: a page is a route because it returns `JsxPage` (layouts `JsxLayout`);
  `main.jac`'s `app(children)` must render `children`. Never mix manual `<Router>` with `pages/`.
- **`is None` misses `undefined`** — use truthy checks for dict/hook values; `params["id"]`
  subscript, never `.get()`. Pre-declare vars assigned from `await` (jac2js `let` scoping);
  same for vars first assigned inside an `if` branch.
- **New endpoint 404/405s** until its exact name is in the entry module's import list.
- Dev loop: `jac start --dev main.jac`; server/`glob` changes need a full restart
  (`pkill -f "jac start"` first — a held port breaks the Vite proxy); schema edits on
  persisted nodes → stale-anchor 500s → `rm -rf .jac/data/` (dev only).
- JSX: comments are `{#* … *#}`; no `.map()` (use `for` slots / comprehensions);
  `cond ? : ` is a parse error (use Python ternary); lambdas for handlers
  (anonymous `def` is a parse error).

## v2 backlog (explicitly deferred)

Dashboard page (Sheet 4 aggregates via a server-side walker) · GitHub API integration
(resolve issue/PR state; PR-merged → auto-Done) · real accounts (`jacLogin` +
`walker:priv` + `root.shared` grants replacing WhoAmI) · log-from-card quick action +
`About` edge (the convergence path to a derived daily log) · blocked-as-flag preserving
column (instead of a Blocked column) · WebSocket live sync · Done-column archive sweep,
sort renormalization, overdue highlighting, CSV export · per-team routed boards.

## Risks

- **No auth**: leaked URL = anyone edits as anyone. Internal network only; every mutation
  goes through the `find_task`/lookup bases so the v2 `walker:priv` migration touches one
  place per concern.
- **HTML5 DnD has zero touch support** — the arrow-button fallback is part of M4, not later.
- **Adoption hinges on ImportCsv** handling the real export's quirks (date formats, blank
  sections) — test against the actual workbook, import together with the team lead.
- **Last-write-wins concurrency** (60s poll): two people editing one card can clobber each
  other silently. Accepted at ~20 users.
- If the team stops filling the Daily Log because the board feels sufficient, fast-track
  the v2 log-from-card derivation — watch entry counts in weeks 2–3.
