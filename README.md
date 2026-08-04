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
- A roadmap per project: milestones with optional date ranges on a timeline,
  each showing how many of its tasks are done
- GitHub, on demand: install the app on the repos you choose, import issues as
  tasks, watch pull-request state on the cards, and open an issue from a task
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

## Connecting GitHub

The GitHub tab needs its own **GitHub App**, which is separate from the GitHub
sign-in button. Signing in with GitHub only proves who someone is: the runtime
discards that OAuth token, so reading issues and pull requests needs a
credential of its own.

Create one at <https://github.com/settings/apps/new>:

| Field | Value |
| --- | --- |
| Callback URL | `<HOST>/workspace?tab=github` |
| Setup URL | `<HOST>/workspace?tab=github`, with "Redirect on update" ticked |
| Request user authorization (OAuth) during installation | **on** |
| Webhooks | off |
| Repository permissions | Issues: read and write · Pull requests: read · Metadata: read |

The OAuth-during-installation box is not optional. Installation ids are small
integers, so completing a connection requires proving the person who
authorized can actually see that installation; with the box off, that check
cannot run and connecting is refused.

Generate a private key, then set `GITHUB_APP_ID`, `GITHUB_APP_SLUG`,
`GITHUB_APP_CLIENT_ID`, `GITHUB_APP_CLIENT_SECRET` and
`GITHUB_APP_PRIVATE_KEY` (see `.env.example` for the base64 one-liner). Leave
them empty and the GitHub tab explains what is missing instead of failing.

What the app stores is an installation id, not a token: each request mints a
one-hour installation token in memory and drops it. Nothing is polled or
scheduled, and the only write to GitHub is an issue you explicitly create from
a task.

## License

[MIT](LICENSE)
