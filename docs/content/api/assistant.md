# Assistant

An LLM assistant that reads the whole workspace and never writes
to it. Each call builds the deterministic [snapshot](insights.md#digest)
and passes it to one byLLM function. Source:
`services/assistant/assistant.jac`.
{ .fl-lede }

## How it stays grounded

- **One snapshot, no tools.** Every call gets the [`Snapshot`](types.md#snapshot)
  for its date range (default: today) and nothing else. There is no tool use
  and no browsing.
- **The system prompt** in `jac.toml` tells the model to answer only from the
  snapshot, never invent tasks, people, projects or dates, say plainly when the
  snapshot lacks the answer, and write about members in the third person.
- **Low temperature** (`0.2`) with up to three output retries for structured
  results.
- **Model**: `${LLM_MODEL:-gpt-4o-mini}`, with the provider key in the
  environment (`OPENAI_API_KEY` for the default).

!!! note "Failures report nothing"

    When the LLM call fails, the walker logs the cause on the
    `flowline.assistant` logger with a hint (check `OPENAI_API_KEY`,
    `LLM_MODEL` and the account's credit) and reports nothing. Ask shows
    "The assistant is not available right now. Try again in a moment."

::: walker AskAssistant

**Reports** one string: the answer, usually two or three sentences. A blank
`question` reports nothing and makes no LLM call.

```bash
curl -X POST $BASE/walker/AskAssistant -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"question": "What is blocked and why?", "from_date": "2026-09-08"}'
```

```json title="data.reports"
["Two tasks are blocked. Priya Raman's \"Write the migration plan\" waits on the schema review, and ..."]
```

::: walker WriteStandup

**Reports** one [`StandupNote`](types.md#standupnote) with a headline and four
lists: `shipped`, `in_flight`, `blocked` and `needs_attention`, each line naming
the person. `period` is free text for the model ("today", "this week"); the
snapshot window comes from `from_date` and `to_date`.

::: walker ProposeAction

Turns an instruction such as *"add a task for Nadia on the docs site"* into
**one proposed change**. It writes nothing.

**Reports** one [`ProposedAction`](types.md#proposedaction). A blank
`instruction` reports nothing.

| `kind` | The client, after the user confirms |
| --- | --- |
| `create_task` | Resolves `project` and `assignee` by exact name, then calls [`CreateTask`](tasks.md#createtask) |
| `move_task` | Finds the task by title with [`ListTasks`](tasks.md#listtasks), then calls [`MoveTask`](tasks.md#movetask) with the proposed status |
| `none` | Shows the model's `note`; the request was not a board change |

Before reporting, the server blanks a `status` that is not one of the legacy
statuses and a `priority` that is not `High`, `Medium` or `Low`. Other fields
pass through as the model wrote them, which is why the client matches names
exactly and a human confirms.
