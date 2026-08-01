# standup — v2 Plan: Auth, Organizations, Projects & People (SHIPPED)

> Archived. Delivered by PR #2 (`a0a1fd9`). Superseded by PLAN.md (v2.1),
> which removes the `Organization` node in favour of the `/user/me` profile
> and applies the Standup brand design.

v1 replaced the team spreadsheet with a no-auth kanban app (see PLAN-V1.md).
v2 put a front door on it: **Project Managers sign up, set up their
organization, create projects, and manage the people on them.** Clean start —
no spreadsheet import, no carried-over v1 data.

## What shipped

- **Login / signup is the first page**; `(public)/login.jac` plus an
  auto-guarded `(auth)/` route group. Signing up makes you a PM; team members
  stay roster records with no accounts.
- **Setup wizard**: organization → first project → people.
- **One PM = one private org.** Every walker requires a JWT and runs on the
  caller's own graph root, so `[root --> Organization]` cannot reach another
  tenant — isolation with zero permission plumbing.
- **`Project` nodes replaced the `TEAMS` glob.** Tasks link via `ForProject`,
  members via `OnProject`; the board filters by project.
- **Security hardening**: `jobj(id)` resolves any id, so resolution is not
  authorization — `owned()` and the `find_task` / `find_log_entry` lookup
  bases verify org parentage before every mutation.
- **v3 hooks**: `Organization.pm_root_ids` and `_on_attached()` were seeded so
  multi-PM orgs would not need a re-parenting migration.
- **`ImportCsv` deleted** along with every spreadsheet reference.

## Structure introduced

`endpoints.jac` (759 lines) split into `models.jac` (archetypes only — module
path is archetype identity, never move) plus `walkers/` by domain (org,
projects, roster, tasks, log, util). Pages became thin stateful shells
composing section components under `components/{board,log,roster,projects}/`,
with handler bodies in `.impl.jac` annexes.

## Verification at merge

26 modules passed `jac check`; an 18-check API suite covered the auth wall,
onboarding idempotence, CRUD, cross-tenant reads, and foreign-jid
update/move/delete/assign attacks; the signup → wizard → board flow drove
clean in a headless browser.

## Known issues found after merge (carried into v2.1)

1. **Frozen inputs** — `{**form, key: value}` compiles to a JS object literal
   with a literal `"key"` property, so the dict-backed dialogs never updated
   the field being typed into.
2. **Wrong signup wording** ("Create a PM account") — the account *is* the
   organization, so the copy should say so.
3. **`Organization` node is redundant** — `/user/me` already stores a profile
   per account, and one account is one org.
4. **No brand design** — the app shipped with default jac-shadcn neutral
   styling.
