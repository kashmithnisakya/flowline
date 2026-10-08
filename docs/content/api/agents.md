# AI responsibilities

A role can carry AI responsibilities, such as code review, that run when a
task enters one of the role's steps. These walkers manage the responsibilities,
the workspace's AI switch and a task's runs. Source:
`services/agents/agents.jac`.
{ .fl-lede }

!!! info "Nothing runs yet"

    Runs are queued by the job queue, which is still being built. Until then
    no walker creates a run, and `RetryRun` and `CancelRun` only change a
    run's status.

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

::: walker RetryRun h3

Queues a `failed`, `skipped` or `cancelled` run again, clearing its error.

**Reports** `{"ok": true, "run": `[`AgentRunView`](types.md#agentrunview)`}`.
**Refuses** `not_retryable`, `ai_off` while the switch is off, or `not_found`.

::: walker CancelRun h3

Cancels a `queued` or `running` run.

**Reports** `{"ok": true, "run": `[`AgentRunView`](types.md#agentrunview)`}`.
**Refuses** `not_cancellable` or `not_found`.
