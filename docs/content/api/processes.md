# Process review library

Process definitions are user-supplied, workspace-owned review data, separate
from operational flow steps and tasks. Flowline ships no process catalog.
Import a local JSON file through the UI or send its definitions to the
protected API. Other workspaces cannot list or modify the imported records.
Keep personal catalogs outside the source repository or in the ignored
`.flowline-local/` directory.

## Walkers

::: walker ListProcesses

Returns the caller's saved `ProcessView` records. Reading an empty workspace
returns `[]` and creates no data.

::: walker ImportProcessCatalog

Accepts `definitions`, an array of process definitions. Validates the complete
payload and the proposed workspace groups before writing. Adds missing keys;
explicitly higher revisions of matching keys preserve IDs and review notes,
and snapshot the earlier definition and its notes in `history`. Equal or
older revisions remain unchanged. Records absent from the payload are retained.
No operational task or another workspace is modified. Returns
`{"ok": true, "added": N, "updated": N}` or `invalid_catalog` / `catalog_conflict`.
Notes and history supplied in the payload are ignored; clients cannot replace
them through a definition import. Validation failures make no partial writes.

::: walker SaveProcessNote

Saves a plain-text note of at most 6,000 characters for a known step on a
caller-owned definition. Notes are trimmed; an empty value clears the text.
Reports `{"ok": true}` or `not_found`, `unknown_step`, `note_too_long`.
Foreign and unknown process IDs receive the same `not_found` response.
Notes do not approve or execute steps.

Browser saves for the same note retain submission order through remounts and
page navigation. An earlier failed request does not discard a later accepted
save. Session changes cancel queued writes; stale refreshes are ignored.

## Persisted types

::: node ProcessDefinitions

::: node ProcessDefinition

::: obj ProcessView

The catalog schema and local setup are described in the
[process review guide](../contributing/process-review.md). Definition revisions
are separate from note edits. History retains notes on removed steps.
This library does not execute process steps or enforce the policies it displays.
