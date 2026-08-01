# standup

A multi-tenant kanban project tracker for Project Managers — sign up, set up
your organization, create projects, and manage the people on them. Built
entirely in [Jac](https://www.jaseci.org/) (graph-native backend + JSX/React
client) with [jac-shadcn](https://github.com/jaseci-labs/jaseci) UI.

![Board](assets/board.png)

## What it does

Log in, and everything below is scoped to **your organization** — a private
graph nobody else can read or write.

| Page | Purpose |
| --- | --- |
| **Login / Signup** (`/login`) | The front door. Signing up makes you a Project Manager; nothing else is reachable logged out |
| **Setup wizard** (`/setup`) | First run only: name your org → create your first project → add people |
| **Board** (`/`) | 6-column kanban filtered by project, drag-and-drop **plus** ←/→ click-to-move, optimistic moves with server-authoritative ordering, 60s poll + refetch-on-focus |
| **Daily Log** (`/log`) | One row per person per weekday, day/week views, This-Week count strip |
| **Projects** (`/projects`) | Create, rename, archive — tasks and logs hang off these |
| **People** (`/roster`) | Org roster with inline project assignment, plus the GitHub repo list |

<details>
<summary><b>More screenshots</b></summary>

### Login

![Login](assets/login.png)

### Daily Log

![Daily Log](assets/daily-log.png)

### People

![People](assets/people.png)

### Projects

![Projects](assets/projects.png)

</details>

## Running it

```bash
jac install              # deps (Python + npm) from jac.toml
jac start --dev main.jac # dev server with hot reload → http://localhost:8000
```

Production: `jac start main.jac`. Sign up at `/login` to create the first PM.

## Security model

- **One PM = one private organization.** Every walker requires a JWT and runs
  on the caller's own graph root, so `[root --> Organization]` structurally
  cannot reach another tenant — isolation with no permission plumbing.
- **Resolution is not authorization.** `jobj(id)` resolves *any* node id, so
  every jid-addressed mutation verifies the node's parentage back to the
  caller's org (`owned()` / the `find_*` lookup bases) before touching it. A
  leaked or guessed jid from another org is a no-op, not a breach.
- Verified by an 18-check suite covering the auth wall, onboarding, CRUD,
  cross-tenant reads, and foreign-jid update/move/delete/assign attacks.

## Layout

```text
models.jac              # every node/edge/obj archetype — never move (module path = identity)
constants.jac           # statuses, categories, priorities, sections
walkers/                # the API, one module per domain
  org · projects · roster · tasks · log · util
pages/                  # file-based routing
  layout.jac            # nav + org name + logout
  (public)/login.jac    # unauthenticated route group
  (auth)/               # auto-guarded: index (board) · log · roster · projects · setup
components/
  board/ · log/ · roster/ · projects/   # feature sections (tables, dialogs, forms)
  ui/                   # jac-shadcn primitives — import only, never edit
```

Pages are thin stateful shells: they own the data and handlers (bodies in
`.impl.jac` annexes) and compose presentational section components. Form-heavy
dialogs take a `dict` plus one `onField(key, value)` callback instead of a
dozen props.

## Roadmap

**v3**: multi-PM organizations (per-node grant backfill — `pm_root_ids` and the
`_on_attached` hook are already in place), member accounts and invitations,
per-role permissions, password reset, dashboard aggregates, GitHub API
integration.

> **Jac tip learned the hard way:** don't name a module after an npm package it
> imports (`sonner.jac` importing `"sonner"` resolves to *itself* → infinite
> render loop), and keep Python imports out of any module the client imports
> types from, or the wasm host gets dragged into the browser bundle.

## License

[MIT](LICENSE)
