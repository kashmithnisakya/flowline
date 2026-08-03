# standup — v4 Plan: The MCP Server (SHIPPED)

> Archived. Eleven tools over the existing walker API, verified 27/27 against
> both a local `jac start` and a minikube deployment. Streamable-HTTP transport,
> deletes, and structural org edits were deliberately deferred.

## The bet

standup already has a complete authenticated API: 29 walkers behind
`POST /walker/<Name>`. The GUI is one consumer. An MCP server is a second one,
aimed at the cases where typing a sentence beats clicking a board: *"what's
blocked?"*, *"move the auth task to review"*, *"log what I did today"*.

The North Star was **a second front door onto the existing API**, not a new
feature surface. Every decision below follows from it: the MCP server adds no
business logic, no graph access, and no authorization of its own.

---

## Findings that shaped the design

Verified by running code, not assumed.

### 1. `jac mcp` is language tooling, not an app-data server

The server built into the `jac` binary (`jaclang/cli/mcp/`) exposes Jac grammar,
docs, and the compiler. It teaches an assistant *the language*. It has no
concept of an app's graph. Exposing standup data is a thing we build.

### 2. Two viable engines; the official SDK won on validation

Both were spiked and both work.

**The built-in `McpEngine`** (`jaclang.cli.mcp.protocol`) takes `resources` /
`tools` / `prompts` as duck-typed `object`s, so a custom provider drops in with
zero dependencies. But it is an internal API, tool schemas are hand-written
JSON, and `serverInfo.name` is hardcoded to `"jac-mcp"`.

**The official `mcp` SDK** won because of one property: a Jac `Literal`
annotation compiles through to a JSON Schema `enum`, and pydantic **rejects a
bad value before the function body runs**.

```
tools/call status="Nonsense"
  -> "1 validation error ... Input should be 'Backlog', 'In Progress', ...
      [type=literal_error]"
```

That is the difference between *"we check statuses in `call_tool` and hope"*
and *a hallucinated column is structurally incapable of reaching the board*.
Under the built-in engine that guarantee is hand-written per tool, per field,
forever.

Note the 2.0 layout: FastMCP is no longer in the SDK (`mcp.server.fastmcp` does
not exist); the equivalent is `MCPServer` in `mcp.server.mcpserver`.

### 3. The SDK belongs in `[optional-dependencies]`

`mcp==2.0.0` pulls ~20 transitive packages (pydantic, starlette, uvicorn,
sse-starlette, pyjwt, jsonschema, opentelemetry-api). `[dependencies]` is the
app server's runtime closure and ships into every deploy, and the app never
imports any of it.

```toml
[optional-dependencies.mcp]
mcp = "==2.0.0"
```

Both halves verified: plain `jac install` leaves `mcp` absent;
`jac install --extras mcp` pulls it in. Quirk: `jac install --plan --extras mcp`
reports "No dependencies resolved" even though the real install works. `--plan`
does not account for extras.

### 4. A nested `root spawn` returns empty `.reports`

Carried over from v3. Every write walker reports only via `report` and carries
no `has results`, so an in-process caller can never read back what it did.

> Consequence: this **ruled out** an in-process `/mcp` route that spawns
> walkers. Going over HTTP sidesteps it, because the serve layer is then the
> top-level spawn.

### 5. Ownership checks live in the walkers, and only there

`owned(holder, target)` is called across `tasks`, `log`, `roster`, `projects`
and `vocab`. `jobj(id)` resolves any node id regardless of owner.

> Consequence: the MCP server is a dumb proxy. It forwards a token and a JSON
> body, never calls `jobj`, never resolves a name to a jid, never imports
> `models.jac`.

### 6. Naming the package directory `mcp/` shadows the SDK

The first cut lived in `mcp/`. `import from mcp.server.mcpserver { MCPServer }`
then resolved `mcp.server` to our own `mcp/server.jac`:

```
No module named 'mcp.server.mcpserver'; 'mcp.server' is not a package
```

Exactly the collision class `CLAUDE.md` already warns about from
`components/ui/sonner.jac`. Two things make it worse than the original: **`jac
check` passes**, so it only fails at runtime, and the message blames the SDK
rather than the local directory. Hence `mcp_server/`.

### 7. Raw nodes carry their jid as `_jac_id`

`TaskView` and `MemberView` are `obj` views with an explicit `id`. Raw nodes
(`LogEntry`, `Project`) serialize with the runtime envelope instead:
`_jac_id`, `_jac_type`, `_jac_archetype`. Without lifting `_jac_id` into `id`,
`update_log_entry` has no id to take and the model starts inventing them. The
`_jac_*` keys are dropped afterwards; tool output is prompt context.

### 8. Jac cannot docstring a plain `def`, and the SDK reads docstrings

`MCPServer.tool()` derives a description from the function docstring, which is
a parse error in Jac. Every tool therefore passes `description=` explicitly,
and a forgotten one would ship an empty description silently. The gate suite
asserts every registered tool has one.

---

## Architecture

```
MCP client (Claude Code / Claude Desktop)
        |  stdio, JSON-RPC 2.0
        v
mcp_server/server.jac              its own process
   MCPServer (official mcp SDK)    schema generation + pydantic validation
   mcp_server/tools.jac            11 tool functions
   mcp_server/client.jac  --- HTTP + Bearer JWT --->  running standup server
                                                        walkers -> owned() -> graph
```

Rejected: an in-process `/mcp` route (Finding 4, plus it couples MCP to the web
deployment), and direct graph access (bypasses `owned()`).

---

## What shipped

`mcp_server/{server,client,tools}.jac`, `mcp_server/README.md`,
`.mcp.json.example`, an `[optional-dependencies.mcp]` group, and
`deploy/minikube/` (see below). No existing walker, page or component changed.

**Six read tools**, always registered: `standup_whoami`, `list_tasks`,
`list_projects`, `list_members`, `list_log_entries`, `get_digest`.

**Five write tools**, only with `STANDUP_MCP_WRITE=1`: `create_task`,
`update_task`, `move_task`, `log_activity`, `update_log_entry`.

Eleven of 29 walkers, on purpose. Deletes are excluded outright: irreversible,
and a misread sentence should not be able to destroy a week of log. Structural
org edits are rare and better in the GUI. The assistant walkers are redundant
because the MCP client already has a model, and `get_digest` hands it the same
snapshot to reason over.

**The safety trade accepted:** in the GUI, `ProposeAction` suggests and a human
confirms. Over MCP the tool call goes straight through, so the client's own
approval prompt is the only confirmation left. That is why writes are opt-in.

---

## Verification

A gate suite in the scratchpad (not the repo, per convention) signs up two
accounts, seeds both, and drives **every tool through a real stdio JSON-RPC
session**, so it covers argument marshalling and schema generation rather than
just the HTTP client.

**27/27 against a local `jac start`, and 27/27 against the minikube
deployment.** Isolation is asserted through the MCP layer in both directions:
A cannot see B's tasks, log, projects or members, and `move_task` /
`update_task` / `update_log_entry` against a foreign jid all fail with B's data
verifiably untouched afterwards. Read-only mode registers 6 tools and hides
`move_task`.

---

## The minikube deploy, and why it is hand-rolled

`jac start --scale` is the supported path and does not work from a macOS host
against a Linux cluster in jac 0.34.9. It seals app bytecode by writing the
**Linux pod binary** to `.pod-jac` and exec'ing it **on the host**
(`scale/injector/bundle.jac::_precompile_app`), which dies with
`[Errno 8] Exec format error`. The error names `JAC_NODE_ARCH`, a red herring:
host and node are both arm64, the mismatch is the OS. It is not configurable
away either, since `_precompile_app` runs ahead of the `fat_bundle` check and
`BinaryInjector` subclasses `PvcInjector` rather than being an alternative.

`deploy/minikube/` therefore builds an image from `jaseci/jaclang:0.34.9` and
reuses the MongoDB and Redis that `--scale` provisions before it fails. Two
traps documented there cost real time:

- The base image sets `ENTRYPOINT ["jac"]`, so `CMD ["jac", "start", ...]`
  becomes `jac jac start ...` and crashloops with `Not a valid file!`.
- `redis` is absent from the base image but `REDIS_URL` is set in the pod. The
  runtime logs a *warning* and carries on, then every OCC-guarded write fails
  with HTTP 500 `list index out of range`. Reads keep working, so the app looks
  healthy until you try to write.

---

## Deferred

- **Streamable HTTP / SSE transport.** `MCPServer` already exposes
  `run_streamable_http_async`; the work is auth, swapping one process-wide
  token for per-request pass-through.
- **MCP resources and prompts.** Both are supported by the SDK. Prompts could
  ship canned workflows ("write my standup for today").
- **Deletes and structural org edits**, per the surface section.
- **Keeping the `Literal` types in sync with `constants.jac` automatically.**
  Today `check_constants_in_sync()` fails loudly at startup if they drift,
  which is a guard rather than a fix.
