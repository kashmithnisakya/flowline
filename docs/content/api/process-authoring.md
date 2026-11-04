# Process authoring

Protected HTTP endpoints for headless, versioned process definitions. The
[MCP and CLI](../get-started/agents.md) call these same walkers against a hosted
server. One account remains one workspace; every ID-addressed read and write
checks the authenticated caller's ownership. Missing and foreign IDs both
report `not_found`.

**Runtime prerequisite:** hosted writes require the transaction fix from
[jac#10576](https://github.com/jaseci-labs/jac/pull/10576). Stock Jac 0.39.0
retries a losing transaction's writes without replaying its read decisions,
which permits duplicate definitions. The guarantees below require that fix
in the hosted build/runtime and a passing deployment integration gate.

## List and inspect

::: walker ListProcessDefinitions

Returns `ok`, `rows`, `page`, `page_size`, `total` and `has_more`. Page size is
clamped to 100. Rows are summaries with IDs, titles, families, variants,
revisions, etags and update timestamps. An empty workspace is not modified.

::: walker GetProcessDefinition

Returns `ok` and `process`, containing `id`, `template_key`, `etag`, `revision`,
`document`, `review_notes` and `updated_at`. `include_history` adds snapshots.
All records under `ProcessDefinitions`, including a separately installed
example catalogue, are readable through this API.

## Validate and save

::: walker ValidateProcessDefinition

Returns `ok` and `errors` without saving. The document has exactly `title`,
`family`, `variant`, `summary`, `steps`, `transitions`, `policies` and
`configuration`. `variant` is `current` or `proposed`, a descriptive label
rather than an approval or execution state. `family` is a lowercase identifier.

Steps have stable, unique identifiers and string metadata: `id`, `title`,
`owner`, `mode`, `status`, `detail`, `guard`, `inputs`, `outputs`, `tool`, `x`
and `y`. Coordinates are finite numeric strings within ±20,000. Optional
source/related links require HTTP(S), no credentials and a corresponding
label. Transitions have string `source`, `target`, `label` and `kind`
(`forward`/`return`), with distinct, existing endpoint IDs. Return loops are
valid. This structural validation does not prove business correctness,
approval, reachability of a release or successful execution.

Policy records have `title` and `detail`; configuration records also have
`status`. Documents are capped at 256 KiB of canonical JSON, collections at
500 records and metadata strings at 8,000 characters (title: 200).

::: walker SaveProcessDefinition

An empty `process_id` creates a custom definition with revision 1; no template
or operational steps/tasks are created. An update requires `expected_etag`
from the latest read/diff and archives the prior definition before replacing
it. The definition ID and all review notes are preserved, including notes on
retired steps. Updating increments `revision` and changes the etag. The etag
also reflects notes and snapshot generation, so a review-note or example
update invalidates an older authoring read.

Managed example definitions must first be exported and created as a custom
copy. Direct authoring updates return `template_requires_copy`; their revision
counter remains reserved for catalogue upgrades. This prevents a custom edit
from suppressing a later managed-template update.

Every save requires a `request_id`: 1–128 ASCII letters, digits, `_` or `-`.
Successful requests retain a workspace-owned receipt and the authenticated
root ID. An identical retry replays that receipt; different input with the
same ID reports `request_id_reused`. Receipt replay describes the original
write, not any changes made afterward. Read the process for its current state.

Requests run in Jac's serializable transaction with retry support. Concurrent
creates with the same request ID produce one definition; concurrent edits
with the same etag permit one winner and report `conflict` for stale input.
These cases are covered by the two-worker integration gate.

Success reports `ok`, `process_id`, `etag`, `revision`, `request_id` and
`replayed`. Failures report `ok: false` with `invalid_definition`,
`invalid_request_id`, `unexpected_etag`, `not_found`, `conflict`,
`request_id_reused`, `template_requires_copy` or `history_limit`. At 200 snapshots, further changes are
refused; no history is silently removed. Request receipts have no automatic
expiry in this version.

## Storage and boundaries

::: node ProcessDefinitions

::: node ProcessDefinition

The archetype identities and definition fields match the separate Processes
UI contribution. This API is independent of that UI and its example
definitions, while requiring the transaction fix above. Authoring receipts are stored separately
under `root → ProcessAuthoringRequests → ProcessAuthoringRequest`.

Definitions describe intended work. This API neither executes a process nor
enforces its textual approval rules. Operational task tools retain their
existing server authorization, entry rules and configured side effects.
