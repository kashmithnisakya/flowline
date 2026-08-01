# standup — v2 Plan: Auth, Organizations, Projects & People

v1 (shipped) replaced the team spreadsheet with a no-auth kanban app — see
[docs/PLAN-V1.md](docs/PLAN-V1.md) for that design and its Jac gotchas.
v2 puts a front door on it: **Project Managers sign up, set up their
organization, create projects, and manage the people on them.**

## Product flow

1. **Login / Signup is the first page.** Nothing else is reachable logged out.
2. Signing up **makes you a PM** — team members do not get accounts in v2
   (they stay roster records; member logins are v3).
3. First login lands on a **setup wizard**: name your organization → create
   your first project → add people (or import the spreadsheet) → board.
4. Day-to-day: full CRUD on projects and people — create/rename/archive
   projects, add/remove people from the org, assign/unassign them per project.

## Design decisions

- **One PM = one private org (v2).** Every authenticated walker in Jac runs on
  the caller's own isolated graph root, so hanging `Organization` off the PM's
  root gives complete tenant isolation with **zero permission plumbing** — no
  shared-root or grant machinery in v2. Multi-PM orgs and member accounts are
  v3 concerns; nothing in this shape blocks them (an org subtree can later be
  shared or re-parented by a dedicated migration walker).
- **Projects replace the hardcoded team strings.** The spreadsheet's "teams"
  (Jac Core, Jac Scale, …) are long-lived projects in disguise. The `TEAMS`
  glob dies; `Project` becomes a node with CRUD, and tasks/members link to it
  by edge, so renaming a project touches one node instead of every task.
- **Auth = Jac built-ins.** `jacSignup` → check `success` → `jacLogin`
  (signup does not create a session), JWT in localStorage, `(public)`/`(auth)`
  route groups for the guard. Every v1 walker flips `:pub` → bare
  (auth-required); scoping is automatic because the caller's root IS the org.
- **The WhoAmI picker retires.** The nav shows the logged-in PM (+ logout).
  Daily-log attribution keeps the member dropdown it already has — the PM
  logs on behalf of roster members, same as the spreadsheet.
- **Migration = re-import.** v1's live data sits on the anonymous graph; the
  authoritative source is still the spreadsheet export. After signup, the PM
  runs the (now authenticated) import — the wizard offers it as a step. The
  old anonymous data is deliberately orphaned; no adopt-from-shared-root
  machinery.

## Data model changes (all in endpoints.jac — never move node/edge declarations)

```
node Organization { name, created_at }                    # NEW — root ++> Organization, exactly one per PM
node Project      { name, description = "", active = True } # NEW — org ++> Project; replaces TEAMS strings
node Member       { name, role, email, github_username, section, active }
                                                          # MODIFIED — drop `team` str; org ++> Member
node Task         { ... unchanged fields ... }            # MODIFIED — drop `team` str; org ++> Task
node LogEntry     { ... , project_name }                  # MODIFIED — denormalized project name replaces `team`

edge ForProject: Task --> Project {}                      # NEW — a task belongs to one project
edge OnProject:  Member --> Project {}                    # NEW — assignment; a member can be on many projects
# AssignedTo / Logged / By unchanged. Repo + LogDay unchanged (org ++> Repo, org ++> LogDay).
```

View objects: `TaskView` gains `project_id` / `project_name` (same join
pattern as assignee). `MemberView` (new, if needed) carries the member's
project names for the roster table.

## API changes

| Walker | Change |
| --- | --- |
| *all v1 walkers* | `:pub` → bare (JWT required); traversal roots change from `root -->` to `org -->` via a `get_org` helper |
| `GetMe()` | NEW — reports the org (or nothing → client redirects to /setup) |
| `CreateOrganization(name)` | NEW — idempotent: refuses a second org on the same root |
| `ListProjects / SaveProject(project_id="") / ArchiveProject` | NEW — project CRUD; archive keeps history like members |
| `AssignToProject(member_id, project_id)` / `UnassignFromProject` | NEW — manage `OnProject` edges |
| `CreateTask / UpdateTask / MoveTask` | `team` param → `project_id`; rewire `ForProject` edge on update |
| `ListTasks` | joins project via `ForProject`; client filters by project |
| `SaveMember` | drops `team` param; optional `project_ids` list for initial assignment |
| `LogActivity` | takes `project_id`, denormalizes `project_name` onto the entry |
| `ImportCsv` | auth-required; the todo/roster `Team` column get-or-creates Projects and wires edges |

Client note: any 401 hard-reloads the page (runtime behavior); the reload
lands on an `(auth)` route and bounces to `/login` — acceptable session-expiry
UX for v2.

## Pages

```
pages/layout.jac            # shell: nav + project switcher + PM menu when logged in; bare shell otherwise
pages/(public)/login.jac    # login/signup card (toggle), jacSignup -> jacLogin -> navigate /
pages/(auth)/index.jac      # Board (moved) — scoped by the nav's project switcher
pages/(auth)/log.jac        # Daily Log (moved) — same scoping
pages/(auth)/roster.jac     # People — org roster + per-member project assignment
pages/(auth)/projects.jac   # NEW — project CRUD (list, create, rename, archive)
pages/(auth)/setup.jac      # NEW — onboarding wizard: org -> first project -> people/import
components/ProjectSwitcher.jac  # NEW — replaces WhoAmIPicker in the nav; persists selection in localStorage
```

(The route-group guard is automatic; keep `layout.jac` at `pages/` root —
a layout inside `(auth)/` collides with the root layout.)

## Build order (one PR each; app stays deployable at every step)

1. **M1 — Auth wall**: login/signup page, route groups, logout, all walkers
   flip to auth-required, WhoAmI picker removed.
   *Gate:* logged-out user sees only /login; signup → login → empty app works.
2. **M2 — Organization + onboarding**: `Organization` node, `GetMe` /
   `CreateOrganization`, `/setup` wizard step 1, client gate (no org → /setup).
   *Gate:* fresh account is forced through org creation exactly once.
3. **M3 — Projects**: `Project` node + CRUD + `ForProject` edges, projects
   page, project switcher, Board/Log scoped, `TEAMS` glob deleted, task
   dialog uses live projects.
   *Gate:* create/rename/archive a project; board filters by it; no `team`
   string remains in the codebase.
4. **M4 — People**: roster scoped to org, `OnProject` assignment UI on the
   roster page, member form updated.
   *Gate:* add a person, assign to two projects, unassign, archive.
5. **M5 — Import + wizard finish**: authenticated `ImportCsv` mapping the
   Team column to Projects, wizard import step, README/screenshots refresh.
   *Gate:* fresh signup → wizard → import the real workbook → populated,
   project-scoped board.

Estimated effort: ~6–8 working days.

## Auth gotchas to honor (verified against the runtime)

- `jacSignup` returns a dict and **does not log in** — always
  `await jacSignup(...)` → check `["success"]` → `await jacLogin(...)`.
- Pre-declare variables assigned from `await` (jac2js `let` scoping).
- `jacIsLoggedIn()` checks token *presence*, not validity — treat it as a UI
  hint; the server and the 401 reload are the truth.
- Bare walkers run on the caller's own root: **never** assume v1's shared
  data is visible after the flip — that's the point.

## Deferred to v3

Multi-PM organizations (shared org subtree / grants), member accounts +
invitations, per-role permissions (PM vs member views), email verification /
password reset, org settings page, audit trail, the Dashboard page, GitHub
API integration.
