# Process storyboards

The `/processes` review library is separate from the workspace's operational
flow line. Definitions, versions, step metadata and review notes are persisted
under `root → ProcessDefinitions → ProcessDefinition`. Existing tasks, flow
steps and history are unaffected. These definitions have no execution engine.

## Walkers

::: walker ListProcesses

Reports one list of `ProcessView` records belonging to the caller's workspace.
An empty workspace reports `[]` without creating any containers.

::: walker InstallProcessExamples

Installs the current and proposed React migration and BAU definitions.
Reports `{"ok": true, "added": 4}` on a new workspace and `added: 0` on repeat.
Existing definitions and review notes are retained. This is a user-triggered
write, not a migration during a read.

::: walker SaveProcessNote

Saves one plain-text review note of at most 6,000 characters for a known step
on a definition owned by the caller. Notes are trimmed and rendered as text;
they are not approvals, state transitions or QA evidence. An empty note clears
its text. Reports `{"ok": true}` or `{"ok": false, "error": ...}` with
`not_found`, `unknown_step` or `note_too_long`. Foreign and unknown definition
IDs receive the same `not_found` result.

## Persisted types

::: node ProcessDefinitions

::: node ProcessDefinition

::: obj ProcessView

Each step includes a stable ID, title, owner, manual/automation mode,
implementation status, intended behavior, decision rule, inputs, outputs,
dependencies and diagram position. Transitions include source, target, label
and forward/return kind. Shared policy text and unset project/spec configuration
are stored with the example definition. `revision` identifies the storyboard
definition; editing a review note updates `updated_at` without changing that
definition revision.

This stage supports local review only. It cannot execute agents, enforce
approvals, provision data, start QA clocks, validate checks or declare readiness.
