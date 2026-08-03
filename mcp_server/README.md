# standup MCP server

Drive standup from an MCP client (Claude Code, Claude Desktop, Cursor) instead
of the GUI: *"what's blocked?"*, *"move the auth task to review"*, *"log what I
did today"*.

It runs as its own process and talks to a **running standup server** over the
same HTTP walker API the browser uses. It never touches the graph directly, so
every tenant boundary stays where it already lives, in the walkers' `owned()`
checks.

## Install

The MCP SDK is an optional dependency, kept out of `[dependencies]` so it never
ships into a deploy:

```bash
jac install --extras mcp
```

> `jac install --plan` does not account for extras and will claim nothing
> resolved. Run the real install to verify.

## Configure

| Variable | Required | Meaning |
| --- | --- | --- |
| `STANDUP_URL` | no | Base URL of the running server. Default `http://localhost:8000`. |
| `STANDUP_TOKEN` | either this | A JWT. Skips login entirely. |
| `STANDUP_EMAIL` + `STANDUP_PASSWORD` | or these | Account credentials; the server logs in at startup and re-logs in once on a 401. |
| `STANDUP_MCP_WRITE` | no | `1` enables the five write tools. Anything else is read-only. |

Prefer email/password over a pasted token: the token is a long-lived credential
sitting in a plaintext config file, while the password path at least keeps a
fresh token in memory only.

## Wire up a client

**Claude Code** — copy `.mcp.json.example` to `.mcp.json` in the project root
and fill in your credentials. `.mcp.json` is gitignored.

**Claude Desktop** — add to
`~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "standup": {
      "command": "jac",
      "args": ["run", "mcp_server/server.jac"],
      "cwd": "/absolute/path/to/standup",
      "env": {
        "STANDUP_URL": "http://localhost:8000",
        "STANDUP_EMAIL": "you@example.com",
        "STANDUP_PASSWORD": "...",
        "STANDUP_MCP_WRITE": "1"
      }
    }
  }
}
```

**Cursor** uses the same block in `.cursor/mcp.json`.

## Tools

Read (always registered):

| Tool | Purpose |
| --- | --- |
| `standup_whoami` | Org name plus the real statuses, priorities, categories and tags. Call it first. |
| `list_tasks` | Every task with its `id`. |
| `list_projects` | Projects with their `id`. |
| `list_members` | Roster with each member's `id`. |
| `list_log_entries` | Log entries between two `YYYY-MM-DD` dates. |
| `get_digest` | Server-computed snapshot: blocked items, stale work, review queue. |

Write (only with `STANDUP_MCP_WRITE=1`):

| Tool | Purpose |
| --- | --- |
| `create_task` | New task on the board. |
| `update_task` | Edit a task; empty arguments leave fields unchanged. |
| `move_task` | Move a task between columns. |
| `log_activity` | Add a daily-log entry. |
| `update_log_entry` | Edit a log entry. |

Eleven tools out of 29 walkers, on purpose. Agents choose badly among many
near-identical tools.

**Not exposed:** deletes (`DeleteTask`, `DeleteLogEntries`) are irreversible and
a misread sentence should not be able to destroy a week of log. Structural org
edits (projects, members, repos, vocab) are rare, high blast radius, and better
in the GUI. The assistant walkers (`AskAssistant`, `WriteStandup`,
`ProposeAction`) are redundant here because the MCP client already has a model;
`get_digest` hands it the same snapshot to reason over.

## Safety

`status` and `priority` are `Literal` types, so the SDK generates a JSON Schema
`enum` and pydantic rejects a bad value **before** the walker is called. A
hallucinated column cannot reach the board.

Every id argument is a jid that must come from a `list_*` tool. Nothing here
resolves a name to a jid, because that would move identity resolution to the
wrong side of the walker boundary.

Worth stating plainly: in the GUI, `ProposeAction` suggests and a human
confirms. Over MCP the tool call goes straight through, so **your client's tool
approval prompt is the only confirmation step**. That is why writes are opt-in.

## Troubleshooting

**`standup is not reachable`** — the health check failed at startup, by design,
rather than letting every tool hang. Check `STANDUP_URL`. Note `jac start`
drifts to the next port pair when a stale process holds the API port, so read
the real port from the startup log instead of assuming 8000.

**`No module named 'mcp.server.mcpserver'`** — the SDK is not installed
(`jac install --extras mcp`), or something named `mcp` is shadowing the package.
This directory is called `mcp_server/` rather than `mcp/` for exactly that
reason: a local `mcp/server.jac` makes `import from mcp.server.mcpserver`
resolve to itself. `jac check` does **not** catch it; it only fails at runtime.

**Tools return nothing** — the account is probably empty, not broken. Confirm
with `standup_whoami` and the GUI.

**Nothing appears in the client** — the client only reads stdout as JSON-RPC.
Never add a `print()` to this package; diagnostics belong on stderr.
