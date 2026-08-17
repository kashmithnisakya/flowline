# standup — v4 Plan: Roles, the Jaseci Flow & the Lane View (SHIPPED)

Shipped in PRs #57 (roles + Jaseci template), #58 (Lane view), #59 (cleanup),
promoted to main in #60. Mockups: https://claude.ai/code/artifact/e8c35e62-ce9c-4081-899f-578e764564d7

## v2 addendum (2026-08-14, after review): editable roles + workflow strip

Roles were promoted from template constants to persisted org data so they
can be added, edited and deleted:

- `node Role {name, blurb, color, sort_order}` in models.jac (+ RoleView).
  ApplyTemplate seeds the template's roles as Role nodes (get-or-create by
  name); from then on they are ordinary editable data.
- Name-centric walkers in walkers/roster.jac (roles live as NAMES in
  Member.roles and WorkflowStep.owner): ListRoles; SaveRole (get-or-create,
  rename propagates through members and step owners, rename onto an
  existing name refused, blurb overwrite gated by touch_blurb); DeleteRole
  (node + strip from members + clear matching step owners). Free-text roles
  from before management become managed on first edit and can be deleted by
  name with no node. All registered in main.jac.
- RolesSection: per-card Edit (rename + blurb inline) and Delete (two-click
  "Remove from everyone" confirm), always-visible "New role" input,
  assignment chips unchanged. Cards = Role nodes plus any in-use free-text
  roles.
- MemberDialog options now come from ListRoles (workspace.impl loadAll),
  not the template; the template_key plumbing remains but nothing keys
  roles on it anymore.
- /workflow viewer shows a roles strip under the kind legend: color dot,
  role name, holders ("no one yet" when empty), and a "Manage roles" link
  to /workspace?tab=roles. Loaded at boot; step cards already carry the
  owner role.

## The three changes

**A. Template picker shrinks to two choices.** Keep the Jaseci flow (rebuilt,
see below) and "Start from scratch". Delete the Kanban, Software and Support
templates. `TemplatePicker` renders straight from `WORKFLOW_TEMPLATES`, so
trimming the glob is the whole picker change.

**B. Setup adds people, not roles.** The wizard runs before any workflow
exists (org -> project -> people -> workflow picker), so it cannot know which
roles to offer. Delete the "Role (optional)" input and `mRole` state from
step 3; `SaveMember` gets `roles=[]`. Copy: "Names only for now. You will
pick a workflow next, and assign roles on the Workspace tab."

**C. Roles move to a Workspace tab.** New "Roles" tab after People. For the
Jaseci flow it shows the four fixed roles as assignment cards; for a scratch
workflow it shows the free-text roles in use plus a "new role" input.
Assignment is chip toggles; a person can hold several roles
(`Member.roles` is already `list[str]`, no model change needed for that).

## The new Jaseci flow template

7 steps, 10 labeled transitions. Kinds keep the status dual-write working:

| Step           | kind    | status via KIND_STATUS | owner (role)     | color   |
|----------------|---------|------------------------|------------------|---------|
| Specify        | start   | Backlog                | anyone           | sky     |
| Triage         | start   | Backlog                | Product Engineer | indigo  |
| Design         | active  | In Progress            | Architect        | slate   |
| Implement      | active  | In Progress            | Builder          | amber   |
| Review & merge | handoff | Review                 | Product Engineer | indigo  |
| Refactor       | active  | In Progress            | De-slop Engineer | rose    |
| Done           | done    | Done                   | Product Engineer | emerald |

Triage is `start`, not `handoff`: triaged-but-unstarted work must report
Backlog, not Review. Two start steps is fine; the no-step fallback lands on
the first of the kind (Specify).

Transitions (`links` + `link_labels`):

1. Specify -> Triage: "to PE first"
2. Triage -> Specify: "PE too"
3. Triage -> Design: "needs design"
4. Triage -> Implement: "small, straight to build"
5. Design -> Implement: "approach agreed"
6. Implement -> Review & merge: "ready and tested"
7. Review & merge -> Done: "merged, clean"
8. Review & merge -> Implement: "big changes, back to builder"
9. Review & merge -> Refactor: "brittle, small changes"
10. Refactor -> Done: "rewritten, merged"

The template dict also gains a `"roles"` list (name + blurb for the four
Jaseci roles). One source feeds the picker, step `owner` fields, the Roles
tab and the member dialog.

Roles (from the org chart): Product Engineer (triage, review, merge, done),
Builder (many PRs, fast), Architect (shared design), De-slop Engineer
(small fixes, flagged rewrites).

## Wiring

- **models.jac**: `WorkflowMeta` gains `template_key: str = ""`. Additive
  field with a default = safe for persisted data. Nothing moves, nothing is
  deleted.
- **walkers/workflow.jac**: `ApplyTemplate` stamps
  `get_meta(here).template_key = self.template_key` after seeding;
  `GetWorkflowMeta` reports `template_key` alongside `name`. Scratch
  workflows keep `""` = free-text roles mode.
- **walkers/roster.jac**: new `SetMemberRoles(member_id, roles)` walker,
  `resolve` + `isinstance` + `owned()` before writing, touching ONLY
  `roles`. Do not reuse `SaveMember` from the Roles tab: its update branch
  overwrites email/github/tags with whatever is sent.
- **main.jac**: import `SetMemberRoles` (missing import = 404 at runtime,
  jac check will not catch it).
- **components/workspace/RolesSection.jac** (+ impl under
  `components/workspace/impl/`): self-contained like OrganizationSection,
  loads `GetWorkflowMeta` + `ListMembers` itself. Role cards with member
  chips (click chip = remove, "+ Add" popover = assign), "No role yet" row
  at the bottom.
- **components/roster/MemberDialog.jac**: new `roleOptions: list[str]`
  prop. Non-empty -> toggle chips, hide the free-text input; empty ->
  today's behavior. Page passes options resolved from
  `GetWorkflowMeta.template_key` + the template's `roles`.

Deliberately unchanged: board, insights, GitHub sync, assistant, log. They
keep reading `status` (written from step kind); none of them learns what a
role is.

Back-compat: `ApplyTemplate` refuses to seed over existing steps, so orgs on
the old Jaseci template keep their workflow. Their `template_key` stays ""
-> custom-roles mode with their existing free-text roles. Workflows already
seeded from the removed templates are ordinary steps and unaffected.

## Build order

1. constants.jac: rewrite WORKFLOW_TEMPLATES (jaseci only, new steps/links/
   labels/roles). jac check.
2. models.jac + walkers/workflow.jac: template_key. jac check both.
3. walkers/roster.jac: SetMemberRoles; main.jac import. jac check.
4. setup.jac + setup.impl.jac: drop the role input, update copy.
5. workspace.jac + RolesSection (new) + impl: Roles tab.
6. MemberDialog + workspace impl: roleOptions chips.
7. Verify (below).

## Verification

- jac check on every touched file.
- API gates (scratchpad suite): ApplyTemplate seeds 7 steps + 10 labeled
  transitions; GetWorkflowMeta round-trips template_key; cross-tenant
  SetMemberRoles with a foreign jid is a no-op; SetMemberRoles leaves
  email/github/tags untouched.
- Browser QA (agent-browser, `keyboard type`, assert rendered text):
  - Picker shows exactly two cards.
  - Setup step 3 has no role field; members land with empty roles.
  - Roles tab assigns/removes; one person can hold all four roles.
  - Member dialog shows chips on jaseci, free text on scratch.
  - Board renders the 7 columns in sort order; moving into Review & merge
    writes status "Review"; existing workspaces still load and move tasks.
