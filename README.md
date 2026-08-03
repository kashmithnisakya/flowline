# standup

A kanban board and an automatic daily log for teams that hate status meetings.
Built entirely in [Jac](https://www.jaseci.org/) (graph-native backend plus a
JSX/React client) with [jac-shadcn](https://github.com/jaseci-labs/jaseci) UI.

https://github.com/user-attachments/assets/96b39f11-1718-4682-a7b9-7275f3bbc562

## What it does

- A six-column board per organization, scoped by project, with drag and drop
- The board writes the log: task creation and every status move land in the
  activity feed automatically, with timestamps, issue/PR links and the people involved
- Review handoffs: moving a task to Review asks (optionally) for a reviewer,
  a review-by date and the PR link; Blocked asks what is blocking it
- Multi-assignee tasks, org-defined categories and tags, repos attached to projects
- An Overview tab with headline numbers, per-project progress and per-person activity
- An assistant that reads the whole workspace and writes the standup note for you,
  answers questions about your own board, and turns "add a task for Nadia on the
  docs site" into a suggestion you confirm before anything is written

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

Use `jac start --dev main.jac` for hot reload while developing.

Copy `.env.example` to `.env` and fill in what you need. Everything in it is
optional: without `OPENAI_API_KEY` the app runs fine and only the assistant is
unavailable, and leaving a Google or GitHub pair empty simply hides that
sign-in button.

## Drive it from an AI assistant

An optional MCP server exposes the board and the daily log to Claude Code,
Claude Desktop or Cursor, so you can ask *"what's blocked?"* or say *"move the
auth task to review"* without opening the GUI.

```bash
jac install --extras mcp    # not part of the app's own dependencies
```

Read-only by default. See [mcp_server/README.md](mcp_server/README.md) for
client configuration and the tool list.

## License

[MIT](LICENSE)
