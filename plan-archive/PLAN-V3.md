# standup — v3 Plan: The Assistant (SHIPPED)

> Archived. Delivered by PR #15 (`42e7b30`). All six milestones shipped:
> M1 the deterministic `Snapshot` and `Digest` walker · M2 the byLLM surface
> and its three walkers · M3 the floating dock in `layout.jac` · M4 the
> structured standup note · M5 propose-then-confirm task entry ·
> M6 Web Speech dictation. SSE streaming and moving Overview onto the
> server-side `Digest` were deliberately deferred.

## The bet

standup already automates the *"what happened"* half of a standup: the board writes the log.
It does not touch the other half, which is still manual:

- **synthesis** — somebody still writes the summary
- **entry** — somebody still fills the form

v3 attacks exactly those two. The North Star is **"the standup note wrote itself, and I can
interrogate the board instead of a person"**, not a generic chat-with-your-data bot.

Two product facts drive every decision below:

1. Members have no accounts, so all output is third-person about named people.
2. A whole organization's data fits comfortably in one prompt. **Stuffed context beats
   tool-calling and beats RAG at this scale**, and it happens to dodge two runtime landmines
   (see Findings).

---

## Findings that shaped the design

These were verified by running code against the pinned runtime (jac 0.34.6), not assumed.

### 1. byLLM streaming and tool-calling do not compose

A graph-reading tool returns its data under a normal call and returns **empty** under
`by llm(stream=True)` — silently. The model then answers fluently from nothing. No exception,
no 500, no warning.

> Consequence: we cannot have both a typing effect and tools in v3.0. We choose correct answers.

### 2. A nested `root spawn` inside a walker returns empty `.reports`

`_sv_on_complete` merges an inner walker's reports into the **outer** walker and returns early,
so the inner walker's own `.reports` is `[]`:

```
--- top-level spawn ---   TOP .reports = [['a','b']]
--- nested spawn ---      reports=[]  results=['a','b']
```

Two consequences:

- A tool written as `w = root spawn ListTasks(); ... w.reports` reads `[]` and the assistant
  says "you have no tasks" — the same silent-empty failure as streaming, on the path everyone
  assumed was safe. Our `List*` walkers survive only by accident, because each also carries
  `has results`. **Every write walker** (`CreateTask`, `MoveTask`, `SetMoveInfo`, `LogActivity`,
  `SaveMember`, `SaveProject`) reports only via `report` and has no `results`, so a tool can
  never read back what it did.
- The inner reports pollute the outer walker's `reports` array, so `reports[0]` — the pattern
  every existing page uses — becomes the tool dump, shipping the whole board to the browser on
  every chat turn.

> Consequence: **assistant code never nests `root spawn`.** Context is gathered by traversing
> `[root-->]` directly, in plain `def`s.

### 3. `:pub` would be an unauthenticated token burner

`walker:pub` runs anonymous callers on the shared guest graph. It fails *invisibly*: a caller
who does send a token works fine, so a demo looks perfect while an unauthenticated caller can
burn the OpenAI key against the guest graph.

> Consequence: every assistant walker is bare (JWT-required), like every other walker here.

### 4. byLLM has no audio surface

The media types are Text / Image / Video. There is no audio, whisper, transcription or TTS
anywhere in the package. Whisper would mean a hand-rolled OpenAI client, which breaks the
"byLLM only" rule.

> Consequence: voice input is the browser's Web Speech API or nothing.

---

## Architecture

```
client (Jac → React)                    server (walkers on the graph)
────────────────────                    ────────────────────────────
AssistantLauncher  ──root spawn──►  walker AskAssistant   (JWT-required)
  (floating, in layout.jac)               │
                                          ├─ def build_snapshot() → Snapshot   [traverses root-->]
                                          │     no LLM, no nested spawn
                                          └─ by llm() with the snapshot stuffed in context
                                                └─ returns str | StandupNote | ProposedAction
```

**One round trip, the same `POST /walker/<Name>` every page already uses.** It inherits JWT auth
and per-root tenant isolation for free, and it is the only shape where the model reliably sees
real data.

### Why no tools

Tool-calling buys nothing here (the whole org fits in a prompt) and costs correctness (findings
1 and 2). Context assembly is a deterministic `def` we can unit-test without an LLM.

---

## Capabilities, and the v3.0 cut line

### Tier 0 — deterministic, zero LLM. **Build this first.**

`walkers/insights.jac`: one `Digest` walker returning `obj Snapshot`.

- **Blocked list** — status Blocked, with the reason from the "Moved to Blocked" log row and
  `blocked_since` from that row's `at`
- **Review queue** — reviewer, review-by date, PR link, days waiting
- **Aging / stale** — not Done, `updated_at` older than N days
- **Overdue** — `due_date` past and not Done
- **Per-person** — open, done-this-period, log-entry counts
- **Per-project** — done / active / blocked / total
- **Flow metrics** from the log event stream — throughput per week, time in column, blocked
  duration

This is simultaneously (a) the context builder for every LLM call, (b) exact answers to half the
questions people would ask the bot, and (c) a fix for `/overview` recomputing everything in the
browser. **It is useful even if the LLM half never ships.**

### Tier 1 — synthesis (the headline). **v3.0**

- **Standup note generation** — daily / weekly, whole org or per project, from the snapshot.
  Structured `obj StandupNote { shipped, in_flight, blocked, needs_attention }` so it renders as
  a card rather than a wall of prose, and can be copied into Slack.
- **Question answering over your own data** — "what's blocked?", "what did Nadia do last week?",
  "what's been sitting in review longest?"

### Tier 2 — entry. **v3.0, but propose-then-confirm only**

The model **never writes**. It returns a structured `ProposedAction`; the UI renders a confirm
card; on Apply the **client** calls the existing `CreateTask` / `MoveTask` walker through the
normal path. This sidesteps finding 2 entirely and keeps a human on every mutation.

### Deferred past v3.0

SSE token streaming · voice output (TTS) · Whisper transcription · deep page context (selected
filters, open dialog) · cross-project analytics · scheduled/emailed digests · any autonomous
write.

---

## Permissions — what the assistant may do

**Read: everything inside the caller's own root. Write: nothing, directly.**

| Surface | Access | How it stays safe |
|---|---|---|
| Tasks, projects, members, repos, vocabulary, log entries | read | `build_snapshot()` traverses `[root-->]` only; no jid ever arrives from the client |
| Overview aggregates | read | recomputed server-side in Tier 0 |
| Create task, move task, edit task | **propose only** | model emits a `ProposedAction`; user confirms; client calls the existing walker |
| Archive / delete anything | **never** | not in the proposal vocabulary at all |
| Another account's graph | impossible | walkers are JWT-required and root-scoped; `owned()` guards any jid path |

Hard rules:

- No `:pub` on any assistant walker (finding 3).
- No jid from the client influences the prompt without passing `owned()`.
- The proposal vocabulary is an allowlist of intents, **not** "the model can call any walker".
  In particular `UpdateTask` is never exposed: it is full-replace with empty-string defaults, so
  one partial call would blank title, category, priority, due date, notes and links.

### Prompt injection is the real risk

Task titles, notes, log activity text and member names are user-authored and land in the model's
context. Mitigation is structural, not wording: **no tools, no autonomous writes, and every
mutation confirmed by a human.** An injected instruction can at worst produce a bad *suggestion*
that a person then declines.

---

## Transport: REST, not WebSocket

| Option | Verdict |
|---|---|
| **(a) Plain walker call, whole answer** | **v3.0.** Zero new machinery, inherits auth and isolation, the only shape where data is reliably seen. Cost: a spinner instead of a typing effect. |
| (b) SSE | Fast-follow. Genuinely achievable: ~10 server lines + ~25 client lines of `fetch` + `body.getReader()`. Requires eager context assembly and **loses tools** — fine, we have none. |
| (c) WebSocket | Not needed. Nothing here is bidirectional or push-driven. |
| (d) Polling a partial | Rejected. All the complexity of SSE, worse UX. |

Buy the spinner; keep correct answers.

---

## Voice

**Input:** Web Speech API (`SpeechRecognition`) via client JS interop, as a *progressive
enhancement*. `lib/voice.jac` with `hasVoice()` / `startVoice(onText)` / `stopVoice()`. The mic
button renders only when `hasVoice()` is true, so Firefox and unsupported browsers simply see a
normal composer rather than a broken button. Free, no server, no key.

Two honest caveats to surface in the UI: it is Chromium-only in practice, and Chrome ships the
audio to a Google service.

**Output (TTS) and Whisper:** deferred (finding 4).

---

## UI placement: floating launcher, not a sixth tab

The nav is already at five tabs, and `layout.jac` already mounts one always-on global component
(`<Toaster />`) — the exact precedent.

- A launcher mounted in `layout.jac` gets `location.pathname` **for free** (the layout already
  calls `useLocation()`), so "the assistant knows which page you're on" costs nothing.
- A sixth nav tab is marginally cheaper to wire but throws away page context.
- An Overview-only panel is invisible from the board and log, where the work happens.

The chat surface is ~70% buildable from existing primitives (Card, Button, Input, Textarea,
Badge, Separator, Skeleton, DropdownMenu). Missing pieces install offline from the registry
bundled in the jac binary — nothing needs hand-writing.

---

## Configuration

`.env` already holds `OPENAI_API_KEY`. **`.env.example` is written** (names only, no values).

byLLM does not read the key itself — it passes `api_key` down to litellm, which reads
`OPENAI_API_KEY` from the environment. So the key can simply be left out of `jac.toml`.

```toml
[byllm]
system_prompt = "You are the standup assistant for a kanban and daily-log tool. Answer only from the workspace snapshot you are given. Never invent tasks, people or dates. Be terse."

[byllm.model]
default_model = "${LLM_MODEL:-gpt-4o-mini}"

[byllm.call_params]
temperature        = 0.2
max_tokens         = 0
max_output_retries = 3
```

`${VAR}` and `${VAR:-default}` interpolation is verified to work in `[byllm.*]`. `llm` is an
**ambient builtin** — no import and no `glob llm` needed; `[byllm.model]` is the whole wiring.

**Testing without burning tokens:** MockLLM. Note the real signature is
`MockLLM(model_name="mockllm", config={"outputs": [...]})` — the `outputs=` keyword form raises
`TypeError`.

**Cost control:** `gpt-4o-mini` by default; the snapshot is a compact obj, not a raw board dump;
one call per user message; no autonomous loops.

---

## Milestones

| # | Milestone | Ships | State |
|---|---|---|---|
| **M1** | `walkers/insights.jac` — `Snapshot` + `Digest`, no LLM | Real value with zero AI risk | done |
| **M2** | byLLM wiring: `jac.toml`, `walkers/assistant.jac`, three walkers | Q&A over your own data | done |
| **M3** | Floating launcher + chat panel mounted in `layout.jac` | The actual UI | done |
| **M4** | Structured standup note, copyable | The headline feature | done |
| **M5** | Propose-then-confirm task creation and moves | Entry, safely | done |
| **M6** | Voice input, progressively enhanced | Nice-to-have | done |
| — | Overview switches to the server-side `Digest` | Removes browser recompute | deferred |
| — | SSE streaming | Fast-follow, now that the answers are proven right | deferred |

M1 was deliberately first: it is the substrate for everything, it is testable without an LLM, and
it improves the product on its own.

### Two more landmines, found while building the UI

Both are ordinary Jac-to-JS compilation facts, now in CLAUDE.md:

1. **A name first assigned inside an `if` is block-scoped in the compiled JS.** `label` was set in
   both branches of an if/else and was `ReferenceError` after it — the whole handler died before
   its first walker call, silently, with the spinner left spinning.
2. **A `has` read after `await` is the pre-call snapshot.** Appending the user's question and then
   the model's reply as two separate `turns = turns + [...]` statements dropped the question every
   time: the second append re-read the value captured when the handler was created. Build the new
   list in a local and assign once.

## Definition of done for v3.0

- [x] Every assistant walker is JWT-required; no `:pub` anywhere.
- [x] No nested `root spawn` in any assistant path.
- [x] The model performs no writes; every mutation is user-confirmed.
- [x] `jac check` clean on all touched files.
- [x] Browser-verified end to end: ask, standup note, propose, apply, board refresh.
- [x] The snapshot is built per request, never cached across turns.
- [x] API gate suite: 18 assertions covering JWT enforcement on all four walkers (missing and
      forged tokens), cross-account snapshot isolation, and empty-input disengage.

The gate suite lives in the scratchpad per repo convention. Its shape:

```
1. no token          -> Digest / AskAssistant / WriteStandup / ProposeAction all 401
2. forged token      -> same four, all 401
3. tenant isolation  -> A creates a task; B's Digest and B's AskAssistant answer
                        cannot contain it, and B's snapshot is genuinely empty
4. empty input       -> a blank question or instruction reports nothing,
                        so no call reaches the provider
```
