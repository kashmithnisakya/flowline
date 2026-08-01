# standup

A kanban board and an automatic daily log for teams that hate status meetings.
Built entirely in [Jac](https://www.jaseci.org/) (graph-native backend plus a
JSX/React client) with [jac-shadcn](https://github.com/jaseci-labs/jaseci) UI.

https://github.com/user-attachments/assets/303eb173-2508-4252-ab51-0f1c7fe1f4b2

## What it does

- A six-column board per organization, scoped by project, with drag and drop
- The board writes the log: task creation and every status move land in the
  activity feed automatically, with timestamps, issue/PR links and the people involved
- Review handoffs: moving a task to Review asks (optionally) for a reviewer,
  a review-by date and the PR link; Blocked asks what is blocking it
- Multi-assignee tasks, org-defined categories and tags, repos attached to projects
- An Overview tab with headline numbers, per-project progress and per-person activity

## Install Jac

Jac ships as a single native binary. No Python, pip or Node required up front:

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
```

Run `jac` afterwards to confirm it is on your PATH.

## Run the app

```bash
jac install          # dependencies (Python + npm) from jac.toml
jac start main.jac   # serve at http://localhost:8000
```

Use `jac start --dev main.jac` for hot reload while developing. Google and
GitHub sign-in are optional: put the client ids and secrets in `.env` (the
variable names are in `jac.toml` under `[scale.sso]`).

## License

[MIT](LICENSE)
