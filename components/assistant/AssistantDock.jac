"""Ask: the assistant panel, mounted once in the root layout so the transcript
survives closing it. `docked` (1280px and up) is a right column that pushes the
page, otherwise a sheet. A turn is a plain dict (`role`, `kind`): an obj would
create a models <-> walkers import cycle."""

import from "@jac/runtime" { navigate, useLocation }
import from ...lib.voice { hasVoice, startVoice, stopVoice }
import from ...services.assistant.assistant {
    AskAssistant,
    WriteStandup,
    ProposeAction
}
import from ...services.tasks.tasks { ListTasks, CreateTask, MoveTask }
import from ...services.roster.roster { ListMembers }
import from ...services.projects.projects { ListProjects }
import from ..ui.button { Button }
import from ..ui.sheet { Sheet, SheetContent, SheetTitle }
import from ..common.Markdown { Markdown }
import from ..common.glyphs { Spinner, WarnIcon }
import from ..common.CommandPalette { PageIcon }
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
     # Titles shorter than this are too likely to match an ordinary word.
     MIN_CITE: int = 6,
     MAX_CITES: int = 5;


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
    w.dispatchEvent(new(w.CustomEvent, "flowline:refresh"));
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


# Sort key for citations: where the title first appears in the answer.
def citeOrder(d: dict) -> int {
    return d["at"] as int;
}


# Longest title first, so a short title cannot claim part of a longer one.
def citeLength(t: any) -> int {
    return 0 - len(str(t.title).strip());
}


# A letter (anything with case) or a digit, for the word-boundary test.
def isWordChar(ch: str) -> bool {
    return ch.lower() != ch.upper() or ch in "0123456789";
}


# Where `needle` first appears in `hay` as whole words, outside every span a
# longer title already claimed, or -1.
def findTitle(hay: str, needle: str, taken: list[dict]) -> int {
    at = hay.find(needle);
    while at >= 0 {
        end = at + len(needle);
        before = hay[at - 1] if at > 0 else " ";
        after = hay[end] if end < len(hay) else " ";
        free = not isWordChar(before) and not isWordChar(after);
        for span in taken {
            if at < (span["to"] as int) and end > (span["from"] as int) {
                free = False;
            }
        }
        if free {
            return at;
        }
        at = hay.find(needle, at + 1);
    }
    return -1;
}


def:pub AssistantDock(
    open: bool = False,
    onOpenChange: Callable[[bool], None] = None,
    docked: bool = False,
    narrow: bool = False
) -> JsxElement {
    has turns: list[dict] = [],
        draft: str = "",
        mode: str = "ask",
        busy: bool = False,
        listening: bool = False,
        logRef: Ref[any] = Ref(),
        inputRef: Ref[any] = Ref(),
        panelRef: Ref[any] = Ref();

    location = useLocation();

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

    # Docked, opening focuses the composer and Escape closes only from inside
    # the column, so an Escape meant for a dialog, menu or the palette leaves it
    # open. The sheet (below 1280px) is a Radix dialog that does both itself.
    useEffect(
        lambda {
            timer: any = 0;
            if open and docked {
                timer = window.setTimeout(lambda { focusComposer(); }, 30);
            }
            onKey = lambda (e: any) {
                doc: any = document;
                panel: any = panelRef.current;
                if docked
                    and open
                    and e.key == "Escape"
                    and panel
                    and panel.contains(doc.activeElement) {
                    closePanel();
                }
            };
            window.addEventListener("keydown", onKey);
            return lambda {
                window.removeEventListener("keydown", onKey);
                if timer {
                    window.clearTimeout(timer);
                }
            };
        },
        [open, docked]
    );

    # The palette's "Ask" action hands its typed question over as an event.
    useEffect(
        lambda {
            onAsk = lambda (e: any) {
                question = str(e.detail.question or "") if e.detail else "";
                if question {
                    mode = "ask";
                    quick("ask", question);
                }
            };
            window.addEventListener("flowline:ask", onAsk);
            return lambda { window.removeEventListener("flowline:ask", onAsk); };
        },
        []
    );

    async def send -> None;
    async def quick(kind: str, value: str) -> None;
    async def citeTasks(text: str) -> list[dict[str, str]];
    async def applyProposal(index: int) -> None;
    def setTurnState(index: int, state: str) -> None;
    def copyNote(index: int) -> None;
    def toggleMic -> None;

    def focusComposer {
        if inputRef.current {
            inputRef.current.focus();
        }
    }

    # Back to the top bar's Ask button, unless another dialog now holds focus.
    def returnFocus {
        doc: any = document;
        trigger: any = doc.querySelector("[data-ask-trigger]");
        if doc.querySelector("[role=dialog][data-state=open]") {
            return;
        }
        if trigger and trigger.offsetParent {
            trigger.focus();
        }
    }

    def closePanel {
        if onOpenChange {
            onOpenChange(False);
        }
        if docked {
            returnFocus();
        }
    }

    def openTask(e: any, id: str) {
        e.preventDefault();
        if not docked and onOpenChange {
            onOpenChange(False);
        }
        if location.pathname == "/board" {
            w: any = window;
            w.dispatchEvent(new(w.CustomEvent, "flowline:open-task", {"detail": id}));
            return;
        }
        navigate("/board?task=" + id);
    }

    asking = mode == "ask";
    canListen = hasVoice();

    # The index travels with the row so the JSX never needs tuple unpacking.
    rows: list[dict] = [];
    at = 0;
    for t in turns {
        rows.append({** t, "at": at});
        at = at + 1;
    }

    # On a phone the header and composer controls grow to touch size.
    def modeClass(active: bool) -> str {
        base = "rounded-sm transition-colors "
            + ("h-9 px-3 text-[13px] " if narrow else "h-6 px-2 text-xs ");
        if active {
            return base + "border bg-card font-semibold text-foreground";
        }
        return base
            + "border border-transparent font-medium text-muted-foreground hover:text-foreground";
    }

    if docked and not open {
        return <span hidden={True}/>;
    }

    # The sheet names itself through Radix's title; the column through an id.
    titleClass = "truncate text-[13.5px] font-semibold";
    title: any = <h2 id="ask-title" className={titleClass}>
        Ask about this workspace
    </h2>;
    if not docked {
        title = <SheetTitle className={titleClass}>
            Ask about this workspace
        </SheetTitle>;
    }

    head = <div className="flex h-11 shrink-0 items-center gap-2 border-b pr-2 pl-3.5">
        <PageIcon name="ask" className="text-muted-foreground"/>
        {title}
        <div className="ml-auto flex items-center gap-0.5">
            {if len(turns) > 0 {
                <Button
                    key="clear"
                    variant="ghost"
                    size="sm"
                    className={"text-muted-foreground "
                        + ("h-10 px-3" if narrow else "")}
                    onClick={lambda { turns = []; }}
                >
                    Clear
                </Button>
            }}
            <Button
                variant="ghost"
                size="icon-sm"
                className={"size-10" if narrow else ""}
                aria-label="Close Ask"
                title="Close (Esc)"
                onClick={closePanel}
            >
                <svg width={16} height={16} viewBox="0 0 16 16" aria-hidden="true">
                    <path
                        fill="none"
                        stroke="currentColor"
                        strokeWidth={1.6}
                        strokeLinecap="round"
                        d="m4 4 8 8M12 4l-8 8"
                    />
                </svg>
            </Button>
        </div>
    </div>;

    log = <div
        ref={logRef}
        className="min-h-0 flex-1 space-y-4 overflow-y-auto px-3.5 py-3.5 text-[13.5px] leading-relaxed"
        aria-live="polite"
    >
        {if len(rows) == 0 {
            <div key="empty" className="space-y-3">
                <div className="space-y-1 text-muted-foreground">
                    <p>Answers come from your board, projects, people and log.</p>
                    <p>A change comes back as a proposal you apply.</p>
                </div>
                <div className="divide-y border-y">
                    {for q in QUICK_ASKS {
                        <button
                            key={q["label"]}
                            type="button"
                            disabled={busy}
                            onClick={lambda { quick(q["kind"], q["value"]); }}
                            className="flex h-9 w-full items-center justify-between px-1 text-left text-[13.5px] text-foreground transition-colors hover:bg-accent disabled:opacity-50"
                        >
                            {q["label"]}
                            <svg
                                width={14}
                                height={14}
                                viewBox="0 0 16 16"
                                aria-hidden="true"
                                className="text-subtle"
                            >
                                <path
                                    fill="none"
                                    stroke="currentColor"
                                    strokeWidth={1.6}
                                    strokeLinecap="round"
                                    strokeLinejoin="round"
                                    d="M3 8h9.5M9 4.5 12.5 8 9 11.5"
                                />
                            </svg>
                        </button>
                    }}
                </div>
            </div>
        }}
        {for r in rows {
            <div key={"turn" + str(r["at"])}>
                {if r["role"] == "user" {
                    <div
                        key="u"
                        className="ml-auto w-fit max-w-[90%] rounded-xl bg-muted px-2.5 py-1.5"
                    >
                        {r["text"]}
                    </div>
                } elif r["kind"] == "note" {
                    <div key="note" className="rounded-md border bg-background p-3">
                        <div className="flex items-start gap-2">
                            <p className="flex-1 font-medium leading-snug">
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
                        <div className="mt-3 space-y-3 border-t pt-3">
                            <NoteList title="Shipped" items={r["note"].shipped}/>
                            <NoteList title="In flight" items={r["note"].in_flight}/>
                            <NoteList title="Blocked" items={r["note"].blocked}/>
                            <NoteList
                                title="Needs attention"
                                items={r["note"].needs_attention}
                            />
                        </div>
                        <Citations cites={r["cites"] or []} onOpen={openTask}/>
                    </div>
                } elif r["kind"] == "proposal" {
                    <ProposalCard
                        key="prop"
                        proposal={r["proposal"]}
                        state={r["state"]}
                        busy={busy}
                        onApply={lambda { applyProposal(r["at"]); }}
                        onDismiss={lambda { setTurnState(r["at"], "dismissed"); }}
                    />
                } elif r["kind"] == "error" {
                    <p
                        key="err"
                        className="flex items-start gap-2 text-muted-foreground"
                    >
                        <WarnIcon className="mt-1 shrink-0 text-warning"/>
                        <span>{r["text"]}</span>
                    </p>
                } else {
                    <div key="text">
                        <Markdown text={r["text"]}/>
                        <Citations cites={r["cites"] or []} onOpen={openTask}/>
                    </div>
                }    }
            </div>
        }}
        {if busy {
            <p key="busy" className="flex items-center gap-2 text-muted-foreground">
                <Spinner/>
                Reading your workspace
            </p>
        }}
    </div>;

    foot = <div
        className="shrink-0 space-y-2 border-t px-3.5 pt-2.5 pb-[max(0.75rem,env(safe-area-inset-bottom))]"
    >
        {if len(rows) > 0 {
            <div
                key="again"
                className="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-muted-foreground"
            >
                {for q in QUICK_ASKS {
                    <button
                        key={q["label"]}
                        type="button"
                        disabled={busy}
                        onClick={lambda { quick(q["kind"], q["value"]); }}
                        className="rounded-sm hover:text-foreground hover:underline disabled:opacity-50"
                    >
                        {q["label"]}
                    </button>
                }}
            </div>
        }}
        <div className="flex items-center gap-2">
            <div
                className="inline-flex rounded-md bg-muted p-0.5"
                role="group"
                aria-label="Mode"
            >
                <button
                    type="button"
                    aria-pressed={asking}
                    className={modeClass(asking)}
                    onClick={lambda { mode = "ask"; }}
                >
                    Ask
                </button>
                <button
                    type="button"
                    aria-pressed={not asking}
                    className={modeClass(not asking)}
                    onClick={lambda { mode = "do"; }}
                >
                    Propose a change
                </button>
            </div>
        </div>
        <div className="flex items-center gap-1.5">
            <input
                ref={inputRef}
                value={draft}
                placeholder={"Ask a question"
                    if asking
                    else "Describe the task to add or move"}
                aria-label={"Ask a question"
                    if asking
                    else "Describe the task to add or move"}
                disabled={busy}
                onChange={lambda (e: any) { draft = e.target.value; }}
                onKeyDown={lambda (e: any) { if e.key == "Enter" { send(); }}}
                className="h-9 min-w-0 flex-1 rounded-md border border-input bg-card px-2.5 text-[13.5px] placeholder:text-subtle focus-visible:outline-offset-[-1px] disabled:opacity-60"
            />
            {if canListen {
                <Button
                    key="mic"
                    variant={"secondary" if listening else "outline"}
                    size="icon"
                    className="size-9"
                    aria-label={"Stop dictating" if listening else "Dictate"}
                    aria-pressed={listening}
                    onClick={toggleMic}
                >
                    <svg width={16} height={16} viewBox="0 0 16 16" aria-hidden="true">
                        <path
                            fill="none"
                            stroke="currentColor"
                            strokeWidth={1.5}
                            strokeLinecap="round"
                            d="M8 10.5a2.5 2.5 0 0 0 2.5-2.5V4a2.5 2.5 0 0 0-5 0v4A2.5 2.5 0 0 0 8 10.5zM12.5 7.5a4.5 4.5 0 0 1-9 0M8 12v2"
                        />
                    </svg>
                </Button>
            }}
            <Button
                variant="outline"
                size="icon"
                className="size-9"
                aria-label="Send"
                disabled={busy or not draft.strip()}
                onClick={send}
            >
                <svg width={16} height={16} viewBox="0 0 16 16" aria-hidden="true">
                    <path
                        fill="none"
                        stroke="currentColor"
                        strokeWidth={1.6}
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        d="M3 8h9.5M9 4.5 12.5 8 9 11.5"
                    />
                </svg>
            </Button>
        </div>
        <p className="text-xs text-muted-foreground">
            {"Answers come from your workspace only."
                if asking
                else "Nothing changes until you press Apply."}
        </p>
    </div>;

    if docked {
        return
            <aside
                ref={panelRef}
                data-ask-panel="docked"
                aria-labelledby="ask-title"
                className="sticky top-12 z-30 flex h-[calc(100dvh-3rem)] w-[360px] shrink-0 flex-col self-start border-l bg-card"
            >
                {head}{log}{foot}
            </aside>;
    }

    return
        <Sheet
            open={open}
            onOpenChange={lambda (o: bool) { if onOpenChange { onOpenChange(o); }}}
        >
            <SheetContent
                data-ask-panel="sheet"
                side={"bottom" if narrow else "right"}
                aria-describedby={None}
                onOpenAutoFocus={lambda (e: any) {
                    e.preventDefault();
                    focusComposer();
                }}
                onCloseAutoFocus={lambda (e: any) {
                    e.preventDefault();
                    returnFocus();
                }}
                className="gap-0 p-0 [&>[data-slot=sheet-close]]:hidden data-[side=bottom]:h-[88dvh] data-[side=bottom]:rounded-t-xl data-[side=right]:w-[400px] data-[side=right]:sm:max-w-[400px]"
            >
                {head}{log}{foot}
            </SheetContent>
        </Sheet>;
}


# The tasks an answer names, as links that open the card on the board.
def Citations(
    cites: list[dict[str, str]], onOpen: Callable[[any, str], None]
) -> JsxElement {
    if len(cites) == 0 {
        return <span hidden={True}/>;
    }
    return
        <div className="mt-2.5 grid gap-1 border-t pt-2 text-[12.5px]">
            <span className="text-muted-foreground">Tasks in this answer</span>
            {for c in cites {
                <a
                    key={c["id"]}
                    href={"/board?task=" + c["id"]}
                    onClick={lambda (e: any) { onOpen(e, c["id"]); }}
                    className="w-fit max-w-full truncate text-foreground underline decoration-input underline-offset-2 hover:decoration-foreground"
                >
                    {c["title"]}
                </a>
            }}
        </div>;
}


# One labelled group inside a standup note. Renders nothing when the list is
# empty, so a quiet day produces a short note rather than four bare headings.
def NoteList(title: str, items: list[str]) -> JsxElement {
    if not items or len(items) == 0 {
        return <span hidden={True}/>;
    }
    return
        <div>
            <div className="text-xs font-medium text-muted-foreground">{title}</div>
            <ul className="mt-1 space-y-1">
                {for it in items {
                    <li key={it} className="flex gap-2 leading-snug">
                        <span
                            className="mt-2 h-1 w-1 shrink-0 rounded-full bg-muted-foreground"
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
        <div className="rounded-md border bg-background p-3">
            <div className="flex items-center gap-2 text-xs text-muted-foreground">
                <span className="font-medium text-foreground">
                    {"Proposed move" if moving else "Proposed task"}
                </span>
                {if proposal.confidence and proposal.confidence != "high" {
                    <span key="conf">
                        {" · " + proposal.confidence + " confidence"}
                    </span>
                }}
            </div>
            {if usable {
                <p key="title" className="mt-1.5 font-medium leading-snug">
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
                <p key="nope" className="mt-2 text-muted-foreground">
                    That does not look like a board change. Switch to Ask to get an answer instead.
                </p>
            } elif state == "applied" {
                <p
                    key="done"
                    className="mt-3 flex items-center gap-1.5 text-xs font-semibold text-success"
                >
                    <svg
                        width={14}
                        height={14}
                        viewBox="0 0 16 16"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth={1.8}
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        aria-hidden="true"
                    >
                        <path d="m3.5 8.5 3 3 6-7"/>
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
