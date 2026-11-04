# Flowline MCP and hosted CLI

Use Flowline from Codex, Claude Code or a terminal without running the Flowline
app locally. This package is an HTTP client and a per-user stdio MCP bridge;
the Flowline server stays at your hosted URL. Python 3.11+ is required on the
client machine; Jac, Node and a local Flowline database are not required there.

The deployed server must include this PR for process authoring. Workspace,
project and task tools also use existing Flowline endpoints. This contribution
is based directly on `dev`, independent of the Processes UI PR #321. It adds
no example catalogue, UI or process executor. It uses the
same `models.ProcessDefinition` schema so a later UI can read the saved data.

**Deployment prerequisite:** definition writes require the Jac transaction fix
in [jac#10576](https://github.com/jaseci-labs/jac/pull/10576). Stock Jac 0.39.0
can commit duplicate definitions after a concurrent retry. This PR retains
`dev`'s version pin and a failing integration gate on that stock runtime;
do not enable hosted authoring until a supported hosted build/runtime includes
the fix and passes the gate. Local patched-runtime validation is not hosted
compatibility evidence. Installing this Python client does not upgrade Jac.

## Install and connect

From a checkout of this PR:

```sh
python3 -m pip install ./integrations/agents
flowline --url https://your-flowline.example login --email you@example.com
flowline workspace
```

After this package is merged to `dev`, it can also be installed directly,
without checking out or running Flowline:

```sh
python3 -m pip install 'git+https://github.com/kashmithnisakya/flowline.git@dev#subdirectory=integrations/agents'
```

The password is prompted without echo and never accepted in command arguments.
`--password-stdin` supports a secret manager supplying stdin. The login token is
saved in `~/.config/flowline/credentials.json` with mode 0600 on POSIX; the
password is never saved. Protect the equivalent user-profile ACL on Windows.
The file contains credentials, so keep it out of repositories and shared folders.
`FLOWLINE_CONFIG` selects a different credentials file.

For an existing token (including an SSO account), configure:

```sh
export FLOWLINE_URL=https://your-flowline.example
export FLOWLINE_TOKEN=... # supply from your secret manager
flowline process list
```

Credentials are selected by the complete server URL, including any deployment
path prefix. An environment token requires a matching `FLOWLINE_URL`; changing
`--url` cannot silently forward that token to another server. Remote URLs must
use HTTPS. HTTP is accepted only for loopback development. HTTP redirects are
refused, so configure the final canonical URL. Tokens are never printed by
login or included in command arguments. Authentication/expiry errors require
logging in again; this client does not extract browser credentials.

## Create and modify a process

Start with `flowline process example > process.json` (also available as
[`process-example.json`](src/flowline_agent/process-example.json)). Steps and process
metadata are descriptive; saving them does not run agents, enforce approvals,
execute QA, or change the operational board.

```sh
flowline process example > process.json
flowline process validate process.json
flowline process create process.json --request-id onboarding-001
flowline process list
flowline process get PROCESS_ID --history
flowline process export PROCESS_ID > process.json
# Edit the exported JSON. Diff shows both the change and the etag to use.
flowline process diff PROCESS_ID process.json
flowline process update PROCESS_ID process.json --etag ETAG_FROM_DIFF --request-id onboarding-002
```

`create`/`update` require a request ID (1–128 ASCII letters, digits, `_` or `-`).
Retry an ambiguous save with the **same ID and identical arguments**; the
server returns the original receipt. Reusing an ID for different input fails.
Updates require the exact saved etag, and concurrent stale edits fail instead
of overwriting newer work. On conflict, read/diff again and intentionally
reconcile the document; do not blindly refresh the etag and overwrite.

The document has exactly `title`, `family`, `variant`, `summary`, `steps`,
`transitions`, `policies` and `configuration`. Steps use stable IDs; `variant`
is `current` or `proposed`, a descriptive label rather than approval state.
`family` can identify any process, not only the demonstration families.
The server validates size, types, unique step IDs, transition references,
finite coordinates and HTTP(S) source links. It preserves review notes and
earlier definition snapshots. A save increments the definition revision.
Managed example definitions are readable/exportable but must be copied with
`create` before customization (`template_requires_copy`), preserving their
separate catalogue-upgrade revision semantics.
At 200 snapshots, further updates fail with `history_limit`; history is never
silently truncated. Receipt records persist per workspace without automatic
expiry. A replay receipt describes the original save, not the current state;
call `get` to inspect later changes.

## Work with the operational board

```sh
flowline projects
flowline flow
flowline task list --project-id PROJECT_ID
flowline task create --project-id PROJECT_ID --title "Review onboarding" --notes "Check the new process"
flowline task get TASK_ID
flowline task move TASK_ID --step-id STEP_ID
```

Step moves retain the server's entry rules, ownership checks and normal side
effects (including configured GitHub synchronization/AI responsibilities).
Use `--step-id` for a configured flow. A legacy `--status` move clears the
current step, so step-specific entry rules and handoffs do not apply. Statuses
are limited to Backlog, In Progress, Review, Changes Requested, Done and Blocked.
Unlike process saves, task creation has no idempotency key in the existing API;
reconcile a timeout with a read before creating again. This interface does not
expose the existing full-replacement task editor as a partial-update tool.

Operation results and failures are JSON on stdout; failures exit nonzero.
Help and argument-usage messages follow normal CLI conventions.
Use `-` instead of a process filename to read JSON from stdin. Pagination is
explicit; no tool silently claims that its first page is the complete workspace.

## Connect MCP clients

The MCP bridge runs on the agent's machine and connects to **hosted Flowline**.
It is not a second Flowline installation and does not open a public port or
share a configured workspace credential between remote MCP users.

After logging in as above, configure either client:

```sh
codex mcp add flowline -- flowline-mcp --url https://your-flowline.example --allow-write
claude mcp add --transport stdio flowline -- flowline-mcp --url https://your-flowline.example --allow-write
```

The Codex command follows the [official MCP configuration documentation](https://learn.chatgpt.com/docs/extend/mcp?surface=cli).

See [`examples/mcp.json`](examples/mcp.json) for a portable stdio configuration.
Use the installed executable's absolute path if it is not on the agent's PATH.
Omit `--allow-write` for the default read-only tool set. This is a bridge-side
capability choice; the server always authenticates requests and enforces
workspace ownership. Current Flowline authentication grants the account's
workspace access; this PR does not add per-agent roles or scoped API tokens.
Host approval settings still apply to MCP tool calls.

Available tools: `list_processes`, `get_process_example`, `get_process`, `validate_process`,
`diff_process`, `get_workspace`, `list_projects`, `get_flow`, `list_tasks`,
`get_task`; with writes enabled: `save_process`, `create_task`, `move_task`.
Validation failures return explicit errors; refused operations are failed MCP
tool results, never fabricated success. Only JSON-RPC is written to stdout.

Example request to your agent:

> Create an onboarding process with intake, review and completion steps. Validate
> it, show the proposed changes, then save it in my Flowline workspace. Before
> modifying an existing process, read its latest etag and retain its stable step IDs.

## Development

```sh
python3 -m pip install -e ./integrations/agents pytest
python3 -m pytest integrations/agents/tests
python3 tests/smoke/agent_interface_gate.py https://YOUR_TEST_DEPLOYMENT
```

The smoke gate creates disposable test accounts and process definitions on the
selected server. Use a test deployment, not a production customer workspace.
