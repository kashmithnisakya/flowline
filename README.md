# flowline

A board that follows the flow line your team actually uses, and a written daily
log it fills in for you. For teams that hate status meetings.

Built entirely in [Jac](https://www.jaseci.org/) (graph-native backend plus a
JSX/React client) with [jac-shadcn](https://github.com/jaseci-labs/jaseci) UI.

**Documentation:** <https://kashmithnisakya.github.io/flowline/> covers running
it, the data graph, every API walker and deploying with jachammer (sources in
[`docs/`](docs/)).

![A tour of Flowline: sign in, the flow line you design, the board it becomes, a task on its flow line, and the log it writes](gifs/flowline-demo.gif)

## Draw your flow line, get your board

Most tools hand every team the same columns. Here you name the steps your team
really uses, connect them however work moves (loops and branches included), and
the board's columns become those steps, each in its own colour.

Setup takes three steps: name the workspace and its first project, add people
(or skip), then pick how work moves. **Simple** (recommended) is To do, Doing,
Review and Done, with Review able to send work back to Doing. **Software team**
is seven steps from writing the issue to done, with an architecture step for
big changes, loops back from review and four roles. **Draw my own** goes to
the flow line page so you draw the steps yourself. A template opens the board
with a new task ready to type.

On the flow line page, Edit lets you drag a step to move it, drag from its edge
onto another step to connect them, and click a transition to label or delete
it. Drag the empty canvas to pan, zoom with ctrl or cmd and the wheel (or a
pinch), and press F to fit. Flow shows the steps where you drew them; Lanes
lays them out by owner role.

Every step carries a *kind* behind the name you chose: start, active, handoff,
blocked or done. The name is yours, the kind is what the app understands, which
is why renaming a step never changes how anything behaves.

## What it does

- **A flow line per organization** and a board built from it: your steps, your
  order, your colours, with a route strip of every step above the lanes (one
  lane at a time behind step tabs on a phone)
- **The board writes the log**: creating a task and every move land in the
  log automatically, with timestamps, issue/PR links and who was involved
- **A task sheet** beside the board: where the card sits on the route, a Move
  menu, its properties, notes, checklist and its history from the log.
  On the keyboard, M on a card opens the move menu (number keys pick a step),
  J and K step the open sheet through the cards, N starts a new task and /
  filters
- **Handoffs ask for detail**: moving work to a handoff or blocked step asks
  (optionally) for a reviewer, a review-by date, a PR link or what is blocking it
- **Multi-assignee tasks**, free-text categories and tags, repos attached to projects
- **A Tasks table** of every task, searchable as you type and sortable, with
  Working, Done, All and Needs attention scopes kept in the URL
- **Iterations and a roadmap**: plan tasks into time boxes, filter the board to
  the current one, and see work on a twelve-week timeline by its start and due
  dates or its iteration
- **A written log**: each day as a standup grouped by what happened (stuck,
  handed off, finished, in progress, to do), a time-ordered timeline, a week
  view by person, and a one-line composer for notes
- **GitHub, live**: install the app on the repos you choose; issues opened,
  closed or reopened and pull requests merged on GitHub land on an open board
  within seconds, import issues as tasks, see a linked pull request's state on
  its task, and open an issue from a task
- **An Overview** that leads with what needs someone (overdue, blocked, waiting
  on review, due this week, gone quiet), then this week's figures and charts,
  projects and people
- **Ask**, an assistant that reads the whole workspace and writes the standup
  note for you, answers questions about your own board, and turns "add a task
  for Nadia on the docs site" into a suggestion you confirm before anything is
  written. It docks as a column on wide screens
- **Light and dark**, chosen under Workspace, Preferences (or the account menu)
  or followed from your device

## Install Jac

Jac ships as a single native binary. No Python, pip or Node required up front:

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
```

Run `jac` afterwards to confirm it is on your PATH.

## Run the app

```bash
jac install                 # dependencies (Python + npm) from jac.toml
jac run --no-dev main.jac   # serve at http://localhost:8000
```

Use `jac run -w 1 main.jac` for hot reload while developing (app on :8000, API on :8001; hot reload needs a single worker).

Copy `.env.example` to `.env` and fill in what you need. Everything in it is
optional: without `OPENAI_API_KEY` the app runs fine and only the assistant is
unavailable, and leaving a Google or GitHub pair empty simply hides that
sign-in button.

## Connecting GitHub

The GitHub page needs its own **GitHub App**, which is separate from the GitHub
sign-in button. Signing in with GitHub only proves who someone is: the runtime
discards that OAuth token, so reading issues and pull requests needs a
credential of its own.

Create one at <https://github.com/settings/apps/new>:

| Field | Value |
| --- | --- |
| Callback URL | `<HOST>/github` |
| Setup URL | `<HOST>/github`, with "Redirect on update" ticked |
| Request user authorization (OAuth) during installation | **on** |
| Webhook | **Active**, URL `<HOST>/webhook/GithubEvent`, a secret you generate (`openssl rand -hex 32`) |
| Subscribe to events | Issues · Pull request · Pull request review · Sub-issues (installation events are sent to every App on their own) |
| Repository permissions | Issues: read and write · Pull requests: read · Metadata: read |

The OAuth-during-installation box is not optional. Installation ids are small
integers, so completing a connection requires proving the person who
authorized can actually see that installation; with the box off, that check
cannot run and connecting is refused.

Generate a private key, then set `GITHUB_APP_ID`, `GITHUB_APP_SLUG`,
`GITHUB_APP_CLIENT_ID`, `GITHUB_APP_CLIENT_SECRET`, `GITHUB_APP_PRIVATE_KEY`
(see `.env.example` for the base64 one-liner) and `GITHUB_APP_WEBHOOK_SECRET`,
the same secret you gave the webhook. Leave any of the first five empty and
the GitHub page says GitHub is not set up on this server instead of failing;
leave the webhook secret empty and the server refuses to start, since the
receiver would have nothing to verify deliveries against. An App registered
with the older `<HOST>/workspace?tab=github` URLs still works: that link
forwards to `/github` with its query intact.

What the app stores is an installation id, not a token: each request mints a
one-hour installation token in memory and drops it.

### What syncs live

GitHub posts each change to `/webhook/GithubEvent`. The runtime checks the
signature before any app code runs, and the receiver only queues the delivery:
it never calls GitHub and never touches a workspace. An open board applies its
own queue every 20 seconds, so a card appears or moves without a reload, and
the GitHub page's connection strip shows "Live · last event N ago". What lands
this way, for the repos you track:

- an issue opened, edited, closed, reopened, deleted or transferred (a closed
  issue moves its card to your done step when the repo has "Move a card to
  Done when its issue closes or its pull request merges" on)
- a pull request's state on its task, and a merge moving the card to done
  under the same setting
- who GitHub has assigned an issue to, and a review requested on a linked
  pull request or answered with an approval or a change request
- sub-issue links added or removed
- the App suspended, unsuspended or uninstalled, and repos removed from it

The log entry carries the event's own time, not the time someone next opened
the board.

### What the reconcile pass still does

Opening the board still runs the GitHub poll, on a cooldown: every 15 minutes
while deliveries are flowing, every minute otherwise. It catches history from
before the webhook existed and anything delivered while the app was being
deployed. GitHub does not retry a failed delivery on its own; the App's
Advanced tab lists every delivery with its response and a Redeliver button.

Flowline writes to GitHub in two cases: an issue you explicitly create from a
task, and, per repo and off by default ("Close the issue when its card moves
to Done"), the issue's state: closing it when its card reaches your done step,
and reopening it when the card moves back out. The receiver drops the App's own echo of either, so
the card is not moved or logged twice. Titles, assignees and labels are never
written back. Nothing runs on a schedule: a workspace nobody opens stays as it
was.

## License

[MIT](LICENSE)
