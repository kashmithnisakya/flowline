# Use Flowline from agents and the terminal

The Flowline agent client connects to a **hosted Flowline URL**. You do not
need to run Flowline, Jac, Node or a database on the agent's machine. Install
the small Python 3.11+ client from a checkout containing this contribution:

```sh
python3 -m pip install ./integrations/agents
flowline --url https://your-flowline.example login --email you@example.com
flowline workspace
```

The password is prompted; the token is stored in a private credentials file.
An existing token can instead be supplied through `FLOWLINE_TOKEN` together
with its matching `FLOWLINE_URL`. Use the canonical HTTPS URL, including any
deployment path prefix. Credentials are not forwarded through redirects or
silently reused for a different server URL. Client installation does not
deploy or upgrade the server: process authoring requires a hosted instance
containing the [authoring API](../api/process-authoring.md).

Definition writes also require a supported hosted Jac build containing
[jac#10576](https://github.com/jaseci-labs/jac/pull/10576). Stock 0.39.0 can
duplicate a definition after concurrent retries. Hosted deployment remains
blocked until that runtime fix is available and the integration gate passes
there. The client does not install a patched runtime on the server.

## Create or edit a process

```sh
flowline process example > process.json
# Edit the JSON to describe the desired process.
flowline process validate process.json
flowline process create process.json --request-id onboarding-001
flowline process list
flowline process get PROCESS_ID --history
flowline process export PROCESS_ID > process.json
# Edit, inspect the diff, then use the returned etag for an update.
flowline process diff PROCESS_ID process.json
flowline process update PROCESS_ID process.json --etag ETAG_FROM_DIFF --request-id onboarding-002
```

Stable step IDs retain review notes through edits. A stale etag is a conflict:
read and reconcile the newer document before saving again. Retrying an
identical save with its original request ID returns the original receipt.
Reusing a request ID with different arguments is an error. The CLI emits
JSON and exits nonzero on failure. `-` reads a process document from stdin.

These are descriptive process definitions, separate from operational board
steps and task execution. They do not run agents, enforce approvals or claim
that QA passed. This headless contribution adds no new UI.

## Connect Codex or Claude Code

The local MCP bridge uses the same hosted API and saved credentials:

```sh
codex mcp add flowline -- flowline-mcp --url https://your-flowline.example --allow-write
claude mcp add --transport stdio flowline -- flowline-mcp --url https://your-flowline.example --allow-write
```

Omit `--allow-write` to expose read-only tools. The bridge uses stdio and
does not open a network listener. Each user runs their own bridge; it is not
a shared remote MCP endpoint using one workspace's token for everybody.
Every backend request remains authenticated and workspace-scoped. The
account has its normal Flowline permissions; separate agent identities and
granular API-token scopes are not introduced by this integration.

Ask the agent to get a process example, inspect existing processes, validate
and preview a change, then save it with the current etag and a request ID.
It can also inspect workspace/projects/operational flows, list/create tasks
and move tasks to steps under the normal entry rules. Use step IDs for a
configured flow: legacy status moves clear the current step and do not apply
step-specific entry rules or handoffs. The UI remains available for
existing operational features; editing process definitions does not modify
that operational board.

For complete commands, credential handling, portable MCP configuration and
development tests, see `integrations/agents/README.md` in the repository.
