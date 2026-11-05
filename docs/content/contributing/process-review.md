# Review user-supplied processes

The `/processes` library imports and compares workspace-owned definitions,
shows diagrams and lists, and saves review notes. It is separate from the
workspace's operational flow line. No personal or organization-specific flows
ship with Flowline.

## Import your catalog

Keep your catalog outside the repository. If a local file must live inside
the checkout, `.flowline-local/` is ignored. Never commit personal catalogs,
meeting notes, credentials or test workspaces.

Start the app with the pinned compiler wrapper:

```sh
python3 tools/jac.py run --no-dev --host 127.0.0.1 -w 1 main.jac
```

Sign in to your workspace, open `/processes`, and choose **Import process
catalog** to select a JSON file. A new workspace starts empty. Definitions
are imported only into the authenticated caller's workspace, never a shared
catalog. Repeating an import retains existing records. Increase `revision`
explicitly to update a definition; IDs, notes and earlier-definition snapshots
are preserved. Save or discard pending review-note changes before importing.
Note editing and additional imports pause while an import is in progress.
Malformed or conflicting catalogs cannot partially create or update records.

Agents and scripts can use the same protected `ImportProcessCatalog` walker
with a JSON body containing a `definitions` array. A saved UI action is not
required. The server does not read a client-supplied filesystem path.

## Catalog format

The file is a JSON array of 1–100 definitions, limited to 1 MiB. Each
record requires `template_key`, `title`, `family`, `variant` and nonempty `steps`.
Keys and step IDs use letters, digits, dots, underscores and hyphens. Each key
and each family/variant pair must be unique. `variant` is `current` or `proposed`;
`revision` defaults to 1 and must increase for an update. `summary`,
`transitions`, `policies` and `configuration` are optional.

Each step requires `id` and `title`. Optional plain-text fields include
`owner`, `mode`, `status`, `detail`, `guard`, `inputs`, `outputs`, `tool`,
`timing` and `evidence`. Set `kind` to `start`, `active`, `handoff`, `blocked`
or `done`; it defaults to `active`. Coordinates `x` and `y` must be finite
and within the shared canvas bound. Missing coordinates produce a horizontal
layout. A definition supports up to 200 steps and 1,000 transitions.

`path: "branch"` makes a step visible under **All paths** rather than **Main
path**. `short_title` supplies an optional diagram label. `stage` is an optional
group label; the diagram highlights the first named group. These fields carry
presentation metadata rather than assumptions about particular step IDs.

Transitions require existing, distinct `source` and `target` step IDs. `kind`
is `forward` or `return` (default `forward`), with an optional `label`. Loops
through multiple steps are allowed. Policy/configuration rows have `title`,
`detail` and optional `status` fields. Source links use `source_url` and
`source_label`, with optional `related_url` and `related_label`; URLs must use
HTTP or HTTPS.
Labels are optional; a source link without a label displays its URL.

The neutral fixture at `tests/fixtures/process_catalog.json` demonstrates this
schema for tests. It is never installed by the application automatically.
Catalog imports exclude saved notes and history; those remain workspace-owned.

## Inspect and compare

Families come from saved data. Select Current, Proposed or Compare, then use
the diagram, list or **Jump to step**. Drag or scroll to pan; Ctrl/Cmd with the
wheel zooms. Focus the diagram to pan with arrows, zoom with +/- and fit with F.
The contextual inspector becomes a sheet on phones. Comparison shares a zoom
level and switches to readable lists at narrow widths.

Drafts survive changes of step and view. Save to retain a note after reload.
Failed saves retain the input for retry. Earlier definitions and their saved
notes remain available under **Earlier definitions & notes** after an update.

## Compiler prerequisites

Use `python3 tools/jac.py` for compiler-dependent commands. The manifest pins
Jac 0.39.0 source, standard-library stubs and seven upstream fixes:

- [Jac #10441](https://github.com/jaseci-labs/jac/pull/10441): bound dictionary keys.
- [Jac #10445](https://github.com/jaseci-labs/jac/pull/10445): numeric default sorting.
- [Jac #10560](https://github.com/jaseci-labs/jac/pull/10560): comprehension truthiness.
- [Jac #10559](https://github.com/jaseci-labs/jac/pull/10559): package-relative effects paths.
- [Jac #10565](https://github.com/jaseci-labs/jac/pull/10565): committed requests report late write failures without replaying saved work.
- [Jac #10576](https://github.com/jaseci-labs/jac/pull/10576): whole-request replay before commit and bounded retries of post-commit writes.
- [Jac #10578](https://github.com/jaseci-labs/jac/pull/10578): effects declarations on cached interfaces.

The wrapper verifies archive, patch and resulting-source checksums and leaves
the installed binary unchanged. Preparation needs Python 3, `patch` and GitHub
access. A stock hosted image does not inherit this local handoff. Hosted rollout
requires a compatible compiler and deployed integration validation; local and
CI success do not establish hosted compatibility.
