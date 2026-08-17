"""The floating assistant: launcher button plus chat panel, mounted once in the
root layout with its own state and walker calls. A turn is a plain dict with a
`role` and a `kind` (text / error / note / proposal, proposals also carry
`state`): typing it as an obj would create a models <-> walkers import cycle."""

import from ...lib.voice { hasVoice, startVoice, stopVoice }
import from ...walkers.assistant { AskAssistant, WriteStandup, ProposeAction }
import from ...walkers.tasks { ListTasks, CreateTask, MoveTask }
import from ...walkers.roster { ListMembers }
import from ...walkers.projects { ListProjects }
import from ..ui.badge { Badge }
import from ..ui.button { Button }
import from ..ui.input { Input }
import from ..ui.separator { Separator }
import from ..common.Markdown { Markdown }
import from "sonner" { toast }
import from "react" { useEffect }

glob QUICK_ASKS: list[dict[str, str]] = [
         {"label": "Today's standup", "kind": "note", "value": "today"},
         {"label": "This week", "kind": "note", "value": "this week"},
         {
             "label": "What's blocked?",
             "kind": "ask",
             "value": "What is blocked right now, and why?"
         },
         {
             "label": "Needs chasing",
             "kind": "ask",
             "value": "What is overdue, stale, or has been waiting in review too long?"
         }
     ],
     SPARKLE: str = "M12 2.5l1.9 5.1 5.1 1.9-5.1 1.9L12 16.5l-1.9-5.1L5 9.5l5.1-1.9L12 2.5zM18.5 15l.9 2.4 2.4.9-2.4.9-.9 2.4-.9-2.4-2.4-.9 2.4-.9.9-2.4z";


# An ISO day `back` days before today, in the browser's own timezone.
# toISOString() is UTC, so shift by the offset first, or a late-evening user in
# UTC+5:30 asks for tomorrow's standup.
def isoDaysAgo(back: int) -> str {
    d = new(Date);
    d.setDate(d.getDate() - back);
    shifted = new(Date, d.getTime() - d.getTimezoneOffset() * 60000);
    return shifted.toISOString()[:10];
}


# Tell the rest of the app that the graph changed. The board listens for this
# so an applied proposal shows up at once instead of on its next poll.
# dispatchEvent and CustomEvent are absent from the checker's DOM typings.
def announceRefresh {
    w: any = window;
    w.dispatchEvent(new(w.CustomEvent, "standup:refresh"));
}


# One section of the plain-text form of a standup note, for the clipboard.
# Empty in, empty out, so a quiet day copies as a short note.
def noteSection(title: str, items: any) -> list[str] {
    if not items or len(items) == 0 {
        return [];
    }
    out: list[str] = [title + ":"];
    for it in items {
        out.append("  - " + it);
    }
    out.append("");
    return out;
}


def:pub AssistantDock -> JsxElement {
    has open: bool = False,
        turns: list[dict] = [],
        draft: str = "",
        mode: str = "ask",
        busy: bool = False,
        listening: bool = False,
        logRef: Ref[any] = Ref();

    # Pin the transcript to the newest turn. Without this a long standup note
    # or a proposal lands below the fold and its Apply button is unreachable
    # until the user scrolls, which reads as a dead button.
    useEffect(
        lambda {
            el = logRef.current;
            if el {
                el.scrollTop = el.scrollHeight;
            }
        },
        [turns, busy, open]
    );

    async def send -> None;
    async def quick(kind: str, value: str) -> None;
    async def applyProposal(index: int) -> None;
    def setTurnState(index: int, state: str) -> None;
    def copyNote(index: int) -> None;
    def toggleMic -> None;

    asking = mode == "ask";
    canListen = hasVoice();

    # The index travels with the row so the JSX never needs tuple unpacking.
    rows: list[dict] = [];
    at = 0;
    for t in turns {
        rows.append({** t, "at": at});
        at = at + 1;
    }

    def modeClass(active: bool) -> str {
        base = "rounded-md px-2.5 py-1 text-xs font-semibold transition-colors ";
        if active {
            return base + "bg-background text-foreground shadow-sm";
        }
        return base + "text-muted-foreground hover:text-foreground";
    }

    if not open {
        return
            <button
                type="button"
                aria-label="Open the assistant"
                onClick={lambda { open = True; }}
                className={(
                    # Card volume, ember only on the glyph: each page already
                    # has one solid primary action and this sits on every page.
                    "fixed bottom-6 right-6 z-50 flex h-11 items-center gap-2 rounded-full border border-border/70 bg-card px-4 text-sm font-semibold text-foreground shadow-lg transition-transform animate-in fade-in zoom-in duration-300 hover:-translate-y-0.5 hover:bg-accent active:scale-95"
                )}
            >
                <svg
                    width={17}
                    height={17}
                    viewBox="0 0 24 24"
                    aria-hidden="true"
                    className="text-primary"
                >
                    <path fill="currentColor" d={SPARKLE}/>
                </svg>
                Assistant
            </button>;
    }

    return
        <div
            className="fixed bottom-6 right-6 z-50 flex max-h-[calc(100dvh-3rem)] min-h-72 w-[min(26rem,calc(100vw-3rem))] flex-col rounded-2xl border bg-card shadow-2xl animate-in fade-in slide-in-from-bottom-4 duration-200"
        >
            <div className="flex items-center gap-2 border-b px-4 py-3">
                <svg
                    width={16}
                    height={16}
                    viewBox="0 0 24 24"
                    aria-hidden="true"
                    className="text-primary"
                >
                    <path fill="currentColor" d={SPARKLE}/>
                </svg>
                <span className="font-display text-sm font-bold tracking-tight">
                    Assistant
                </span>
                <div className="ml-auto flex items-center gap-1">
                    {if len(turns) > 0 {
                        <Button
                            key="clear"
                            variant="ghost"
                            size="sm"
                            onClick={lambda { turns = []; }}
                        >
                            Clear
                        </Button>
                    }}
                    <Button
                        variant="ghost"
                        size="icon"
                        aria-label="Close the assistant"
                        onClick={lambda { open = False; }}
                    >
                        <svg
                            width={15}
                            height={15}
                            viewBox="0 0 24 24"
                            aria-hidden="true"
                        >
                            <path
                                fill="none"
                                stroke="currentColor"
                                strokeWidth={2}
                                strokeLinecap="round"
                                d="M6 6l12 12M18 6L6 18"
                            />
                        </svg>
                    </Button>
                </div>
            </div>
            <div ref={logRef} className="flex-1 space-y-3 overflow-y-auto px-4 py-4">
                {if len(rows) == 0 {
                    <p
                        key="empty"
                        className="py-2 text-sm leading-relaxed text-muted-foreground"
                    >
                        I read your board, projects, people and log, then answer from that. I never write anything myself: a task change comes back as a suggestion you confirm. Start with one of the buttons below, or just ask.
                    </p>
                }}
                {for r in rows {
                    <div
                        key={"turn" + str(r["at"])}
                        className={"flex animate-in fade-in slide-in-from-bottom-1 duration-200 " + (
                            "justify-end" if r["role"] == "user" else "justify-start"
                        )}
                    >
                        {if r["role"] == "user" {
                            <div
                                key="u"
                                className="max-w-[85%] rounded-2xl rounded-br-sm bg-primary px-3.5 py-2 text-sm text-primary-foreground"
                            >
                                {r["text"]}
                            </div>
                        } elif r["kind"] == "note" {
                            <div
                                key="note"
                                className="w-full rounded-xl border bg-background p-3.5"
                            >
                                <div className="flex items-start gap-2">
                                    <p
                                        className="flex-1 text-sm font-medium leading-snug"
                                    >
                                        {r["note"].headline}
                                    </p>
                                    <Button
                                        variant="ghost"
                                        size="sm"
                                        onClick={lambda { copyNote(r["at"]); }}
                                    >
                                        Copy
                                    </Button>
                                </div>
                                <Separator className="my-3"/>
                                <div className="space-y-3">
                                    <NoteList
                                        title="Shipped"
                                        items={r["note"].shipped}
                                    />
                                    <NoteList
                                        title="In flight"
                                        items={r["note"].in_flight}
                                    />
                                    <NoteList
                                        title="Blocked"
                                        items={r["note"].blocked}
                                    />
                                    <NoteList
                                        title="Needs attention"
                                        items={r["note"].needs_attention}
                                    />
                                </div>
                            </div>
                        } elif r["kind"] == "proposal" {
                            <div key="prop" className="w-full">
                                <ProposalCard
                                    proposal={r["proposal"]}
                                    state={r["state"]}
                                    busy={busy}
                                    onApply={lambda { applyProposal(r["at"]); }}
                                    onDismiss={lambda { setTurnState(
                                        r["at"], "dismissed"
                                    ); }}
                                />
                            </div>
                        } else {
                            <div
                                key="text"
                                className={"max-w-[92%] rounded-2xl rounded-bl-sm px-3.5 py-2 text-sm leading-relaxed " + (
                                    "whitespace-pre-wrap bg-destructive/10 text-destructive"
                                        if r["kind"] == "error"
                                        else "bg-secondary text-foreground"
                                )}
                            >
                                {if r["kind"] == "error" {
                                    <span key="plain">{r["text"]}</span>
                                } else {
                                    <Markdown key="md" text={r["text"]}/>
                                } }
                            </div>
                        }   }
                    </div>
                }}
                {if busy {
                    <div
                        key="busy"
                        className="flex justify-start animate-in fade-in slide-in-from-bottom-1 duration-200"
                    >
                        <div
                            className="flex items-center gap-1.5 rounded-2xl rounded-bl-sm bg-secondary px-3.5 py-2.5"
                        >
                            <span className="sr-only">Reading your workspace</span>
                            <span
                                className="h-1.5 w-1.5 animate-bounce rounded-full bg-muted-foreground"
                                style={{"animationDelay": "-0.3s"}}
                            />
                            <span
                                className="h-1.5 w-1.5 animate-bounce rounded-full bg-muted-foreground"
                                style={{"animationDelay": "-0.15s"}}
                            />
                            <span
                                className="h-1.5 w-1.5 animate-bounce rounded-full bg-muted-foreground"
                            />
                        </div>
                    </div>
                }}
            </div>
            <div className="space-y-2.5 border-t px-4 py-3">
                <div className="flex flex-wrap gap-1.5">
                    {for q in QUICK_ASKS {
                        <button
                            key={q["label"]}
                            type="button"
                            disabled={busy}
                            onClick={lambda { quick(q["kind"], q["value"]); }}
                            className="rounded-full border px-2.5 py-1 text-xs font-medium text-muted-foreground transition-colors hover:bg-accent hover:text-foreground disabled:opacity-50"
                        >
                            {q["label"]}
                        </button>
                    }}
                </div>
                <div className="flex items-center gap-2">
                    <div className="flex shrink-0 rounded-lg bg-muted p-0.5">
                        <button
                            type="button"
                            className={modeClass(asking)}
                            onClick={lambda { mode = "ask"; }}
                        >
                            Ask
                        </button>
                        <button
                            type="button"
                            className={modeClass(not asking)}
                            onClick={lambda { mode = "do"; }}
                        >
                            Do
                        </button>
                    </div>
                    <Input
                        value={draft}
                        placeholder={"Ask about your workspace"
                            if asking
                            else "Describe the task to add or move"}
                        disabled={busy}
                        onChange={lambda (e: any) { draft = e.target.value; }}
                        onKeyDown={lambda (e: any) { if e.key == "Enter" { send(); }}}
                    />
                    {if canListen {
                        <Button
                            key="mic"
                            variant={"default" if listening else "outline"}
                            size="icon"
                            aria-label={"Stop dictating" if listening else "Dictate"}
                            onClick={toggleMic}
                        >
                            <svg
                                width={15}
                                height={15}
                                viewBox="0 0 24 24"
                                aria-hidden="true"
                            >
                                <path
                                    fill="currentColor"
                                    d="M12 14a3 3 0 0 0 3-3V6a3 3 0 0 0-6 0v5a3 3 0 0 0 3 3zm5-3a5 5 0 0 1-10 0H5a7 7 0 0 0 6 6.9V21h2v-3.1A7 7 0 0 0 19 11h-2z"
                                />
                            </svg>
                        </Button>
                    }}
                    <Button
                        size="icon"
                        aria-label="Send"
                        disabled={busy}
                        onClick={send}
                    >
                        <svg
                            width={15}
                            height={15}
                            viewBox="0 0 24 24"
                            aria-hidden="true"
                        >
                            <path
                                fill="currentColor"
                                d="M3 20.5l18-8.5L3 3.5V10l12 2-12 2v6.5z"
                            />
                        </svg>
                    </Button>
                </div>
                <p className="text-xs leading-tight text-muted-foreground">
                    {"Answers come from your workspace only."
                        if asking
                        else "Suggestions only. Nothing changes until you press Apply."}
                </p>
            </div>
        </div>;
}


# One labelled group inside a standup note. Renders nothing when the list is
# empty, so a quiet day produces a short note rather than four bare headings.
def NoteList(title: str, items: list[str]) -> JsxElement {
    if not items or len(items) == 0 {
        return <span/>;
    }
    return
        <div>
            <div
                className="text-xs font-semibold uppercase tracking-wide text-muted-foreground"
            >
                {title}
            </div>
            <ul className="mt-1 space-y-1">
                {for it in items {
                    <li key={it} className="flex gap-2 text-sm leading-snug">
                        <span
                            className="mt-1.5 h-1 w-1 shrink-0 rounded-full bg-muted-foreground"
                        />
                        <span>{it}</span>
                    </li>
                }}
            </ul>
        </div>;
}


# A proposed board change awaiting confirmation. The model produced it; nothing
# reaches the graph until Apply calls the ordinary CreateTask / MoveTask walker.
def ProposalCard(
    proposal: any,
    state: str,
    busy: bool,
    onApply: Callable[[], None],
    onDismiss: Callable[[], None]
) -> JsxElement {
    moving = proposal.kind == "move_task";
    usable = proposal.kind in ["create_task", "move_task"];

    facts: list[dict[str, str]] = [];
    if proposal.project {
        facts.append({"k": "Project", "v": proposal.project});
    }
    if proposal.assignee {
        facts.append({"k": "Assignee", "v": proposal.assignee});
    }
    if proposal.status {
        facts.append({"k": "Column", "v": proposal.status});
    }
    if proposal.priority {
        facts.append({"k": "Priority", "v": proposal.priority});
    }
    if proposal.category {
        facts.append({"k": "Category", "v": proposal.category});
    }
    if proposal.due_date {
        facts.append({"k": "Due", "v": proposal.due_date});
    }

    return
        <div
            className="rounded-xl border border-l-2 border-l-primary bg-background p-3.5"
        >
            <div className="flex items-center gap-2">
                <Badge variant="secondary">
                    {"Move task" if moving else "New task"}
                </Badge>
                {if proposal.confidence and proposal.confidence != "high" {
                    <span key="conf" className="text-xs text-muted-foreground">
                        {proposal.confidence} confidence
                    </span>
                }}
            </div>
            {if usable {
                <p key="title" className="mt-2 text-sm font-medium leading-snug">
                    {proposal.title}
                </p>
            }}
            {if len(facts) > 0 {
                <dl
                    key="facts"
                    className="mt-2 grid grid-cols-[auto_1fr] gap-x-3 gap-y-1"
                >
                    {for f in facts {
                        <div key={f["k"]} className="contents">
                            <dt className="text-xs text-muted-foreground">{f["k"]}</dt>
                            <dd className="text-xs font-medium">{f["v"]}</dd>
                        </div>
                    }}
                </dl>
            }}
            {if proposal.note {
                <p
                    key="note"
                    className="mt-2 text-xs leading-snug text-muted-foreground"
                >
                    {proposal.note}
                </p>
            }}
            {if not usable {
                <p key="nope" className="mt-2 text-sm text-muted-foreground">
                    That does not look like a board change. Switch to Ask and I will answer it instead.
                </p>
            } elif state == "applied" {
                <p
                    key="done"
                    className="mt-3 flex items-center gap-1.5 text-xs font-semibold text-success animate-in fade-in"
                >
                    <svg
                        width={14}
                        height={14}
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth={2}
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        aria-hidden="true"
                    >
                        <path d="M20 6 9 17l-5-5"/>
                    </svg>
                    Applied to the board.
                </p>
            } elif state == "dismissed" {
                <p key="gone" className="mt-3 text-xs text-muted-foreground">
                    Dismissed.
                </p>
            } else {
                <div key="acts" className="mt-3 flex gap-2">
                    <Button size="sm" disabled={busy} onClick={onApply}>Apply</Button>
                    <Button
                        size="sm"
                        variant="ghost"
                        disabled={busy}
                        onClick={onDismiss}
                    >
                        Dismiss
                    </Button>
                </div>
            }   }
        </div>;
}
