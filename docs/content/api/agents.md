# AI responsibilities

A role can carry AI responsibilities, such as code review, that run when a
task enters one of the role's steps. These walkers manage the responsibilities,
the workspace's AI switch and a task's runs. Source:
`services/agents/agents.jac`.
{ .fl-lede }

!!! info "How a run starts"

    A move that lands a task on one of a role's steps queues a run for each
    of the role's enabled responsibilities (`services/agents/runs.jac`): one
    active run per task and responsibility, only while the workspace's AI is
    on, only for a task with a linked pull request, within
    `AGENT_LIMITS.daily_runs`. The move's log line says what was queued or
    why nothing was.

    The runner (`services/agents/runner.jac`, a scheduled function) then
    claims due runs for each workspace with queued work, awaits the PR
    review service for them, and writes the result on the run and the task's
    log. A GitHub 5xx or an unreachable review service is retried with
    backoff, up to `AGENT_LIMITS.max_attempts`; a 403 or a closed PR is not.
    A commit already reviewed by the same responsibility is skipped.

    The review is posted on the pull request as one GitHub review on the
    reviewed commit, with inline comments on the lines the findings name. In
    request-changes mode, a review with a blocking finding is posted as
    `REQUEST_CHANGES` and sends the task back along its step's "changes
    requested" arrow, if the task is still on the step the run was queued for.

    New commits on the linked pull request (a `synchronize` delivery) queue
    the task's responsibilities again while it stays on the step. A queued run
    reads the newest commit when it runs; one already running on the commit
    before gets a new run queued behind it; a commit already reviewed is
    skipped. The PR must be linked to the task the way the GitHub sync links
    one (the PR's body closes the task's issue).

Every refusal is `{"ok": false, "error": <code>, "message": <text>}`.

## Settings

::: walker ListResponsibilities h3

**Reports** one [`AiSettings`](types.md#aisettings): the switch and every
role's responsibilities. With no roles, an empty list. Cached by the browser
for up to 60 s.

::: walker SetAiEnabled h3

The switch is off in a new workspace. Turning it on stamps `enabled_at`;
turning it off keeps the last stamp.

**Reports** `{"ok": true, "enabled", "enabled_at"}`.

## Responsibilities

::: walker SaveResponsibility h3

With an empty `responsibility_id`, saves the role's responsibility with this
`key`, creating it if the role has none, so a role holds one of each.
Otherwise updates the addressed responsibility, whose key cannot change.
`on_steps` keeps each id that names a step of this workspace, once; anything
else is dropped.

**Reports** `{"ok": true, "responsibility": `[`ResponsibilityView`](types.md#responsibilityview)`}`.
**Refuses** `unknown_key` (not in `AI_RESPONSIBILITIES`), `bad_mode` (not
one of the key's modes), `too_long` (instructions over
`AGENT_LIMITS.max_instructions`), `bad_model`, `key_fixed`, or `not_found`
for an unknown or foreign role or responsibility.

!!! warning "Send the whole responsibility"

    A save writes every field it is sent, like `UpdateTask`, so omitting
    `on_steps` or `instructions` clears them.

::: walker DeleteResponsibility h3

Past runs of the responsibility stay, as history. Deleting a role
(`DeleteRole`) deletes its responsibilities too.

**Reports** `{"ok": true, "deleted": <id>}`. **Refuses** `not_found`.

## Runs

::: walker ListRuns h3

**Reports** one list of [`AgentRunView`](types.md#agentrunview), newest
first. A task has a few runs, so the list is not paged. An unknown or foreign
task reads empty. Never cached.

::: walker ListAgentRuns h3

What the AI page shows. `page` and `page_size` page the workspace's runs, newest
first, each with the title and project of the task it ran on (a deleted task
leaves its run, with an empty title). `attention` narrows it to what failed or
requested changes in the last two weeks.

**Reports** one [`AgentRunPage`](types.md#agentrunpage), which also carries
today's run count and the daily limit. Never cached.

::: walker RetryRun h3

Queues a `failed`, `skipped` or `cancelled` run again, clearing its error.

**Reports** `{"ok": true, "run": `[`AgentRunView`](types.md#agentrunview)`}`.
**Refuses** `not_retryable`, `ai_off` while the switch is off, or `not_found`.

::: walker CancelRun h3

Cancels a `queued` or `running` run.

**Reports** `{"ok": true, "run": `[`AgentRunView`](types.md#agentrunview)`}`.
**Refuses** `not_cancellable` or `not_found`.

## Review service

::: walker CheckReviewService h3

Calls the PR review service, its own app (`[apps.pr_review]`) and, when
deployed, its own pod.

**Reports** `{"ok": true, "ms"}` when it answers. **Refuses** `unavailable`
when it does not (still starting, or down); the reason goes to the server
log only.
