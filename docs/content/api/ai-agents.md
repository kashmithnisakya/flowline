# AI agents

An agent is an AI teammate that plays one of the workspace's roles. It wakes
when a task lands on the steps it names, uses only the tools its access allows,
and runs on the workspace's **own** model key. Sources:
`services/agents/crew.jac` (agents) and `services/agents/keys.jac` (keys).
{ .fl-lede }

!!! info "What runs today"

    Any agent can be saved, drawn on its canvas and switched on, but only a
    **review agent** (it holds `read_pr` and `comment_on_pr`) runs: when a task
    lands on one of its steps (in one of its projects) with a linked pull
    request, a run is queued as for a responsibility, and the runner reviews the
    pull request with the workspace's key. Its runs are recorded under
    `code_review` and show on the AI page. An agent's canvas is its design: the
    runner follows the agent's setup, not the drawn graph.

!!! warning "Bring your own key"

    Agent runs never use Flowline's `OPENAI_API_KEY`. The runner opens the
    workspace's key, passes it with the call to the review service, and the
    service holds it for that call only. A key is sealed with
    `FLOWLINE_SECRETS_KEY` before it is stored, is never reported (only its last
    four characters are), and never appears on a run. Tokens used count against
    the workspace's daily token budget.

Every refusal is `{"ok": false, "error": <code>, "message": <text>}`.

## Agents

::: walker ListAgents h3

**Reports** one list of [`AgentView`](types.md#agentview), oldest first. A
workspace with no agents reads empty. Never cached.

::: walker SaveAgent h3

An empty `agent_id` creates an agent (up to 30 per workspace), otherwise it
updates the addressed one. It saves the setup only: whether the agent is on is
`SetAgentEnabled`, and its canvas is `SaveAgentCanvas`. `projects` empty means
every project; `steps` and `projects` keep each id that names one of this
workspace's own, once. A save switches the agent off if its model has no key.

**Reports** `{"ok": true, "agent": `[`AgentView`](types.md#agentview)`}`.
**Refuses** `bad_name`, `bad_role` (not one of this workspace's roles),
`bad_event`, `bad_mode`, `too_long`, `bad_tool`, `no_access` (a tool needs
suggest or write access the agent lacks), `bad_model`, `too_many`, or
`not_found` for an unknown or foreign agent.

!!! warning "Send the whole setup"

    A save writes every field it is sent, like `UpdateTask`, so omitting
    `tools` or `steps` clears them.

::: walker SetAgentEnabled h3

Turning an agent on needs a model whose provider has a key.

**Reports** `{"ok": true, "agent": `[`AgentView`](types.md#agentview)`}`.
**Refuses** `no_model` or `not_found`.

::: walker SaveAgentCanvas h3

Saves the flow drawn for the agent: nodes (`trigger`, `prompt`, `tool`,
`condition`, `approval`) and the connections between them. The server rebuilds
the canvas from what it understands: unknown node types, tools and keys are
dropped, positions are clamped, and a connection to a node that is gone is
dropped. It never widens what the agent may do.

**Reports** `{"ok": true, "agent": `[`AgentView`](types.md#agentview)`}`.
**Refuses** `not_found`.

::: walker DeleteAgent h3

Past runs stay, as history.

**Reports** `{"ok": true, "deleted": <id>}`. **Refuses** `not_found`.

## Models and keys

::: walker ListAiKeys h3

**Reports** one [`AiKeys`](types.md#aikeys): each provider's status, the models
its connected providers offer, the default model, the daily token budget and
the tokens used today. `secrets_ready` is false when the server has no
`FLOWLINE_SECRETS_KEY`, so no key can be saved. Never a key.

::: walker SaveProviderKey h3

Saves or replaces a provider's key. The custom provider also names an
OpenAI-compatible address and a model; the address must be public `https`
(no credentials in it, no loopback, private or link-local host), because the
web app calls it.

**Reports** `{"ok": true}`. **Refuses** `unknown_provider`, `no_secrets`,
`bad_key`, `bad_base`, `bad_model`.

::: walker RemoveProviderKey h3

Forgets the key. Agents on that provider are switched off and a default model on
it is cleared.

**Reports** `{"ok": true}`.

::: walker TestProvider h3

Asks the provider for its model list with the saved key. It reports only
whether the provider answered, never the key or the provider's own error text.

**Reports** `{"ok": true}`. **Refuses** `no_key`, `unreadable`, `bad_base`,
`refused`, `unexpected`, `unreachable`.

::: walker SaveAiLimits h3

The default model for new agents (empty for none, or a model a connected
provider offers) and the daily token budget, between 1,000 and 50,000,000.

**Reports** `{"ok": true}`. **Refuses** `bad_budget` or `bad_model`.
