# Flow lines

Design the organization's steps and the transitions between
them. The board's step groups are these steps. Read
[Flow lines](../concepts/flow-lines.md) first for kinds, fallbacks
and handoffs. Source: `services/flowlines/flowlines.jac`.
{ .fl-lede }

## The flow line

::: walker GetFlowLineMeta h3

**Reports** `{"name": "...", "template_key": "..."}`; with no flow line yet,
`{"name": "Flow line", "template_key": ""}`. An empty `template_key` means the
steps were drawn from scratch. [`GetWorkspace`](board.md#getworkspace) carries
the same two values as `flow_name` and `template_key`.

::: walker RenameFlowLine h3

**Reports** `{"name": "<name after the write>"}`. A blank name changes nothing
but still reports the current name (and creates the box if there was none).

::: walker GetFlowLine h3

**Reports** one list of [`StepView`](types.md#stepview) in `sort_order`, each with
`task_count` filled in (tasks placed by the board's fallback rules count too)
and `task_titles`, the first two titles in the step's panel order (what a node
shows at the flow line page's closest zoom). With no flow line, `[]`.

- The count is over the board's working set: open tasks plus Done tasks that
  reached Done in the last `done_days` (default 7), so the done step counts
  recent Done the way the board's Done group shows it, not the whole history. The
  titles come from the same set, so they are the first two rows
  [`ListStepTasks`](#liststeptasks) would page for that step.
- `project_id` counts only that project's tasks. A foreign id still lists the
  steps, with every count at 0 and no titles.
- `with_counts: false` skips the task walk (the board's poll uses it): every
  count is 0 and every `task_titles` empty.

::: walker ListStepTasks h3

The flow line page's step panel: the tasks sitting on one step.

**Reports** one [`TaskPage`](types.md#taskpage) ordered by `sort_order`:
`page_size` defaults to 50 and is capped at 500, and `older` is always 0. The
rows come from the same working set `GetFlowLine` counts (`done_days`), so
the panel and the node's count agree. An unknown or foreign `step_id` or
`project_id` reports an empty page.

::: walker ApplyTemplate h3

Seeds an empty flow line from a template in one call. The templates today are
`simple` (shown as Simple) and `jaseci` (shown as Software team); see
[Templates](../concepts/flow-lines.md#templates).

**Reports** one list of [`StepView`](types.md#stepview):

| Situation | Reported | Written |
| --- | --- | --- |
| Steps already exist | The existing steps | Nothing |
| Unknown `template_key` | `[]` | The empty box only |
| Success | The new steps, with transitions | Steps at `sort_order` 1024, 2048, ... with their entry rules; transitions with labels, carries and triggers; `template_key`; the template's roles, if it has any (existing names kept) |

Existing tasks are not touched; tasks with no step start landing on the new
steps through the status fallback.

## Steps

::: walker SaveStep h3

An empty `step_id` creates a step at the end of the flow line; otherwise it is
a **partial** update where empty fields keep their value.

**Reports** one [`StepView`](types.md#stepview).
**No-op when** creating with a blank name, or `step_id` is set but unknown or
foreign.

| Field | On create | On update |
| --- | --- | --- |
| `name` | Required | Empty keeps |
| `kind` | Invalid or empty becomes `active` | Invalid or empty keeps. A real change re-maps the status of every task on the step. |
| `color` | Empty uses the kind's default colour | Empty keeps |
| `owner`, `blurb` | Stored trimmed | Empty keeps |
| `x`, `y` | Canvas position; outside 0..20000 becomes 0 | Ignored: use `MoveStep` |

::: walker MoveStep h3

**Reports** the moved [`StepView`](types.md#stepview). Coordinates outside
0..20000 (or not finite) become 0.

::: walker SetStepRules h3

**Reports** the updated [`StepView`](types.md#stepview). Both rules are sent
every time. They gate every move onto the step: `MoveTask` and `UpdateTask`
leave the task where it is and report its view with `refused` set (for
example `"Validated needs a due date"`), `CreateTask` creates nothing, and a
GitHub trigger leaves the task and logs `Stayed on <step> · <reason>`. Tasks
already on the step stay.

::: walker DeleteStep h3

**Reports** one dict:

```json
{ "ok": true, "deleted": "<step id>" }
```

```json
{ "ok": false, "error": "last_of_kind", "message": "This is the only done step. Give another step that kind first, then delete this one." }
```

The guard applies to the last `start` and the last `done` step. On success,
tasks on the step keep their status and lose their `step_id` (so they fall back
to the first step of that kind), and every transition into the step is removed.

::: walker DeleteFlowLine h3

Wipes every step so the flow line can be designed again.

**Reports** `{"ok": true, "deleted": <number of steps>}`.
**Side effects** clears `step_id` on every task that was on a removed step
(statuses stay), deletes the steps and resets `template_key`. The flow line's
name and the roles stay.

## Transitions

::: walker LinkTransition h3

Draws the transition `from_id` to `to_id`, or redraws an existing one.

**Reports** `{"ok": true, "linked": true, "duplicate": <bool>}`, or
`{"ok": false, "error": "not_found"}` when either end is not an owned step, or
`{"ok": false, "error": "self_link", "message": "A step cannot flow into itself."}`.

- A new target is appended to the source step's `transitions`.
- An existing target (`duplicate: true`) is updated in place, and here an
  **empty label or carries keeps** the old value.
- `carries` other than `issue` or `pr` is stored as empty.
- `trigger` is one of `TRANSITION_TRIGGERS` (`label`, `pr_merged`,
  `changes_requested`) or empty; `trigger_label` is kept only for `label`.

::: walker LabelTransition h3

Sets or clears the label, the carries tag and the trigger on an existing
transition. Unlike `LinkTransition`, **empty clears**.

**Reports** `{"ok": true, "label": "...", "carries": "...", "trigger": "...",
"trigger_label": "..."}`, or `{"ok": false, "error": "not_found"}` when either
end is foreign or there is no such transition, or `{"ok": false, "error":
"match_required", ...}` for a `label` trigger with no `trigger_label`.

A trigger moves a task across the arrow without a person, from the step the
arrow leaves, when the GitHub sync or a webhook drain sees the fact:

| Trigger | Fires when |
| --- | --- |
| `label` | `trigger_label` is newly added to the task's issue or its linked PR (case-insensitive) |
| `pr_merged` | The linked PR merges |
| `changes_requested` | A review on the linked PR requests changes (webhook deliveries only) |

The move lands the task at the end of the target step's column, hands it to
the step's owner as a drag would, and logs `Moved to <step> · <why>`. A merge
that no `pr_merged` arrow takes still lands on the done step for a repo with
auto-done on.

::: walker UnlinkTransition h3

**Reports** `{"ok": true, "unlinked": true}` whether or not the transition
existed (idempotent), or `{"ok": false, "error": "not_found"}` when either end
is not an owned step.

## Lookup base

The base the jid-addressed walkers above extend: it resolves the id, checks ownership and only then visits. It is not an HTTP endpoint.

::: walker find_step h3
