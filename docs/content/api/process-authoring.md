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
Local checks and CI prepare the verified source backports with
`python3 tools/jac.py`. The runtime contracts in
`tests/unit/runtime_boundaries.jac` check committed rows and callback counts.
This preparation does not change a hosted runtime image.

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
rather than an approval or execution state. `family` is a nonempty group label
of at most 100 characters, shared with the process library.

Steps have stable, unique identifiers and string metadata: `id`, `title`,
`owner`, `mode`, `status`, `detail`, `guard`, `inputs`, `outputs`, `tool`, `x`
and `y`. IDs support letters, digits, dots, underscores and hyphens, start with
a letter or digit, and have at most 80 characters. Optional `path` (`main` or
`branch`), `short_title` and `stage` metadata survives an authored copy.
Coordinates are finite numeric strings within ±20,000. Optional source/related
links require HTTP(S) without credentials; labels are optional, as in the
process library. Transitions have string `source`, `target`, `label` and `kind`
(`forward`/`return`), with distinct, existing endpoint IDs. Return loops are
valid. This structural validation does not prove business correctness,
approval, reachability of a release or successful execution.

Policy records have `title`, `detail` and optional `status`; configuration
records require all three. Documents are capped at 256 KiB of canonical JSON, collections at
500 records and metadata strings at 8,000 characters (title: 200).

::: walker SaveProcessDefinition

An empty `process_id` creates a custom definition with revision 1; no template
or operational steps/tasks are created. An update requires `expected_etag`
from the latest read/diff and archives the prior definition before replacing
it. The definition ID and all review notes are preserved, including notes on
retired steps. Updating increments `revision` and changes the etag. The etag
also reflects notes and snapshot generation, so a review-note or example
update invalidates an older authoring read.

Each workspace has at most one definition for a given `(family, variant)`.
Creating or moving a definition into an occupied pair returns
`family_variant_conflict` without changing its revision or history. Choose
an unused family/variant pair when making an independent copy.

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
Distinct concurrent creates for the same family/variant permit one winner.
These cases are covered by the two-worker integration gate.

Success reports `ok`, `process_id`, `etag`, `revision`, `request_id` and
`replayed`. Failures report `ok: false` with `invalid_definition`,
`invalid_request_id`, `unexpected_etag`, `not_found`, `conflict`,
`request_id_reused`, `family_variant_conflict`, `template_requires_copy` or
`history_limit`. At 200 snapshots, further changes are
refused; no history is silently removed. Request receipts have no automatic
expiry in this version.

A platform `failed_after_commit` error is a final failure after work may have
become durable. Read the workspace before retrying; retain the original request
ID and identical arguments for an authoring retry. The CLI and MCP report this
code as a failed operation and do not automatically repeat the write.

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
