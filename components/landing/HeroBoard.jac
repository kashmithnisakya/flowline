"""The hero demo at product scale: a four-step route strip, the board whose
columns are those steps, and the log ledger under it. It opens mid-story with
the ledger already written; dragging a card, clicking it or pressing Enter on
it moves it along and writes a new ledger line. Sample data, no autoplay.
"""

import from ..common.Avatar { AvatarStack }
import from ..common.KindGlyph { KindGlyph }

glob ROUTE: list[dict[str, str]] = [
         {"name": "Specify", "kind": "start", "color": "sky"},
         {"name": "Build", "kind": "active", "color": "indigo"},
         {"name": "Review", "kind": "handoff", "color": "rose"},
         {"name": "Done", "kind": "done", "color": "emerald"}
     ],
     GLYPH_TEXT: dict[str, str] = {
         "sky": "text-step-sky",
         "indigo": "text-step-indigo",
         "rose": "text-step-rose",
         "emerald": "text-step-emerald"
     },
     SWATCH: dict[str, str] = {
         "sky": "bg-step-sky",
         "indigo": "bg-step-indigo",
         "rose": "bg-step-rose",
         "emerald": "bg-step-emerald"
     },
     CARDS: list[dict[str, any]] = [
         {
             "title": "Offline mode for the task list",
             "meta": "Mobile app",
             "issue": "",
             "overdue": False,
             "who": ["Amara Perera"],
             "lane": 0
         },
         {
             "title": "Tax ID field for EU customers",
             "meta": "Billing",
             "issue": "",
             "overdue": False,
             "who": ["Ravi Kumar"],
             "lane": 0
         },
         {
             "title": "Invoice PDF redesign",
             "meta": "Billing · due Thu",
             "issue": "",
             "overdue": False,
             "who": ["Priya Raman"],
             "lane": 1
         },
         {
             "title": "Lighthouse score to 95",
             "meta": "Marketing site",
             "issue": "",
             "overdue": True,
             "who": ["Leo Martins"],
             "lane": 1
         },
         {
             "title": "Signup form A/B test",
             "meta": "Marketing site",
             "issue": "",
             "overdue": False,
             "who": ["Sofia Chen", "Ravi Kumar"],
             "lane": 1
         },
         {
             "title": "Webhook for cancelled subscriptions",
             "meta": "Billing",
             "issue": "#412",
             "overdue": False,
             "who": ["Priya Raman"],
             "lane": 2
         },
         {
             "title": "Stripe SDK upgrade",
             "meta": "Billing",
             "issue": "",
             "overdue": False,
             "who": ["Priya Raman"],
             "lane": 3
         },
         {
             "title": "Receipt emails missing VAT number",
             "meta": "Billing",
             "issue": "#398",
             "overdue": False,
             "who": [],
             "lane": 3
         }
     ],
     # Newest first, as the log reads. The second line is the repo's opt-in
     # auto Done at work, which is why it names the closed issue.
     OPENING_LOG: list[dict[str, str]] = [
         {
             "at": "09:42",
             "before": "Priya moved ",
             "issue": "",
             "middle": "",
             "title": "Invoice PDF redesign",
             "after": " to Build."
         },
         {
             "at": "09:15",
             "before": "Issue ",
             "issue": "#398",
             "middle": " closed on GitHub, so ",
             "title": "Receipt emails missing VAT number",
             "after": " moved to Done."
         }
     ],
     DRAG_TYPE: str = "text/x-flowline-demo";

def twoDigits(n: int) -> str {
    return ("0" + str(n)) if n < 10 else str(n);
}

def:pub HeroBoard(loggedIn: bool = False) -> JsxElement {
    has placed: dict[str, int] = {},
        touched: bool = False,
        written: list[dict[str, str]] = [],
        lastMoved: str = "Invoice PDF redesign",
        moves: int = 0,
        dragTitle: str = "",
        overLane: int = -1,
        hotLane: int = -1;

    def laneOf(card: dict[str, any]) -> int {
        if touched {
            return placed[card["title"]];
        }
        return card["lane"];
    }

    def moveTo(title: str, target: int) {
        # The first move copies every card's lane, so later moves only ever
        # change the one card they name.
        updated: dict[str, int] = {** placed};
        if not touched {
            for c in CARDS {
                updated[c["title"]] = c["lane"];
            }
        }
        if updated[title] == target {
            return;
        }
        updated[title] = target;
        placed = updated;
        touched = True;
        d: any = new(Date);
        stamp = twoDigits(int(d.getHours())) + ":" + twoDigits(int(d.getMinutes()));
        line: dict[str, str] = {
            "at": stamp,
            "before": "You moved ",
            "issue": "",
            "middle": "",
            "title": title,
            "after": " to " + ROUTE[target]["name"] + "."
        };
        written = [line] + written;
        lastMoved = title;
        moves = moves + 1;
        showColumn(target);
    }

    # A moved card remounts in its new column, so a keyboard move puts focus
    # back on it and Enter keeps moving the same card.
    def advance(card: dict[str, any], index: int, keyboard: bool) {
        moveTo(card["title"], (laneOf(card) + 1) % len(ROUTE));
        if keyboard {
            window.requestAnimationFrame(
                lambda {
                    doc: any = document;
                    el: any = doc.getElementById("demo-card-" + str(index));
                    if el {
                        el.focus({"preventScroll": True});
                    }
                }
            );
        }
    }

    # Phones scroll the columns sideways; bring one into view without moving
    # the page. On a wide screen nothing overflows and this does nothing.
    def showColumn(index: int) {
        doc: any = document;
        col: any = doc.getElementById("demo-col-" + str(index));
        if not col {
            return;
        }
        rail: any = col.parentElement;
        if rail and rail.scrollWidth > rail.clientWidth {
            w: any = window;
            still = bool(w.matchMedia("(prefers-reduced-motion: reduce)").matches);
            rail.scrollTo(
                {"left": col.offsetLeft, "behavior": "auto" if still else "smooth"}
            );
        }
    }

    ledger = written + OPENING_LOG;
    if len(ledger) > 4 {
        ledger = ledger[0:4];
    }
    counts: list[int] = [0, 0, 0, 0];
    for c in CARDS {
        lane = laneOf(c);
        counts[lane] = counts[lane] + 1;
    }

    return
        <div className="mt-6 mb-2">
            <div
                role="group"
                aria-label="Sample board you can try"
                className="overflow-hidden rounded-xl border bg-card"
            >
                <div className="flex items-center overflow-x-auto border-b px-4 py-3">
                    {for (i, step) in enumerate(ROUTE) {
                        <span key={step["name"]} className="flex shrink-0 items-center">
                            {if i > 0 {
                                <svg
                                    key="wire"
                                    width={34}
                                    height={10}
                                    viewBox="0 0 34 10"
                                    className="shrink-0 text-wire"
                                    aria-hidden="true"
                                >
                                    <path
                                        d="M0 5h27"
                                        stroke="currentColor"
                                        strokeWidth={2}
                                    />
                                    <path d="M26 1l7 4-7 4z" fill="currentColor"/>
                                </svg>
                            }}
                            <button
                                type="button"
                                aria-label={"Show the " + step["name"] + " column"}
                                onMouseEnter={lambda { hotLane = i; }}
                                onMouseLeave={lambda { hotLane = -1; }}
                                onFocus={lambda { hotLane = i; }}
                                onBlur={lambda { hotLane = -1; }}
                                onClick={lambda { showColumn(i); }}
                                className={"inline-flex items-center gap-[7px] rounded-md border bg-card px-2.5 py-[5px] text-[13px] font-semibold whitespace-nowrap transition-colors duration-150 hover:border-input "
                                    + ("border-input" if hotLane == i else "")}
                            >
                                <KindGlyph
                                    kind={step["kind"]}
                                    className={GLYPH_TEXT[step["color"]]}
                                />
                                {step["name"]}
                                <span
                                    className="font-mono text-xs font-medium text-subtle tabular-nums"
                                >
                                    {counts[i]}
                                </span>
                            </button>
                        </span>
                    }}
                    <span
                        className="ml-3.5 inline-flex shrink-0 items-center gap-1.5 font-mono text-xs whitespace-nowrap text-subtle"
                    >
                        <i
                            aria-hidden="true"
                            className="inline-block w-[22px] border-t-2 border-dashed border-wire"
                        ></i>
                        Review sends back to Build
                    </span>
                </div>
                <div
                    className="relative grid snap-x snap-mandatory auto-cols-[78%] grid-flow-col overflow-x-auto sm:snap-none sm:grid-flow-row sm:grid-cols-[repeat(4,minmax(180px,1fr))]"
                >
                    {for (li, lane) in enumerate(ROUTE) {
                        <div
                            key={lane["name"]}
                            id={"demo-col-" + str(li)}
                            className={"flex min-h-[248px] min-w-0 snap-start flex-col gap-2 border-r p-3 transition-colors duration-150 last:border-r-0 "
                                + (
                                    "bg-accent"
                                        if overLane == li or hotLane == li
                                        else ""
                                )}
                            onDragOver={lambda (e: DragEvent) {
                                e.preventDefault();
                                dt = e.dataTransfer;
                                if dt {
                                    dt.dropEffect = "move";
                                }
                                overLane = li;
                            }}
                            onDragLeave={lambda (e: DragEvent) {
                                # Entering a child card fires dragleave too.
                                ct: any = e.currentTarget;
                                rt: any = e.relatedTarget;
                                if not (ct and rt and ct.contains(rt)) {
                                    overLane = -1;
                                }
                            }}
                            onDrop={lambda (e: DragEvent) {
                                e.preventDefault();
                                dt = e.dataTransfer;
                                title = dt.getData(DRAG_TYPE) if dt else "";
                                overLane = -1;
                                if title {
                                    moveTo(title, li);
                                }
                            }}
                        >
                            <div
                                className="flex items-center gap-1.5 text-[13px] font-semibold"
                            >
                                <span
                                    className={"step-swatch " + SWATCH[lane["color"]]}
                                    aria-hidden="true"
                                ></span>
                                {lane["name"]}
                                <span
                                    className="ml-auto font-mono text-xs font-medium text-subtle tabular-nums"
                                >
                                    {counts[li]}
                                </span>
                            </div>
                            {for (ci, c) in enumerate(CARDS) {
                                if laneOf(c) == li {
                                    <div
                                        key={c["title"]}
                                        id={"demo-card-" + str(ci)}
                                        role="button"
                                        tabIndex={0}
                                        draggable={True}
                                        aria-label={str(c["title"])
                                            + ", in "
                                            + lane["name"]
                                            + ". Press Enter to move it to "
                                            + ROUTE[(li + 1) % len(ROUTE)]["name"]
                                            + "."}
                                        onDragStart={lambda (e: DragEvent) {
                                            dt = e.dataTransfer;
                                            if dt {
                                                dt.setData(DRAG_TYPE, c["title"]);
                                                dt.effectAllowed = "move";
                                            }
                                            dragTitle = c["title"];
                                        }}
                                        onDragEnd={lambda {
                                            dragTitle = "";
                                            overLane = -1;
                                        }}
                                        onClick={lambda { advance(c, ci, False); }}
                                        onKeyDown={lambda (e: KeyboardEvent) { if e.key
                                            == "Enter"
                                            or e.key == " " {
                                            e.preventDefault();
                                            advance(c, ci, True);
                                        }}}
                                        className={"grid cursor-grab gap-1.5 rounded-md border bg-card px-2.5 py-2 text-left transition-[border-color,box-shadow,opacity] duration-150 select-none active:cursor-grabbing "
                                            + (
                                                "border-primary ring-1 ring-primary "
                                                    if lastMoved == c["title"]
                                                    else "hover:border-input "
                                            )
                                            + (
                                                "opacity-50"
                                                    if dragTitle == c["title"]
                                                    else ""
                                            )}
                                    >
                                        <span
                                            className="text-[13.5px] leading-[1.35] font-medium"
                                        >
                                            {c["title"]}
                                        </span>
                                        <span
                                            className="flex min-w-0 items-center gap-1.5 text-xs text-muted-foreground"
                                        >
                                            {if c["overdue"] and li != 3 {
                                                <span
                                                    key="late"
                                                    className="inline-flex items-center gap-1 font-semibold text-destructive"
                                                >
                                                    <KindGlyph
                                                        kind="blocked"
                                                        size={12}
                                                    />
                                                    1 day overdue
                                                </span>
                                            } else {
                                                <span key="meta" className="truncate">
                                                    {c["meta"]}
                                                    {if c["issue"] {
                                                        <span key="issue">
                                                            {" · "}
                                                            <span className="font-mono">
                                                                {c["issue"]}
                                                            </span>
                                                        </span>
                                                    }}
                                                </span>
                                            } }
                                            <span
                                                className="ml-auto inline-flex shrink-0 items-center"
                                            >
                                                {if len(c["who"]) > 0 {
                                                    <AvatarStack
                                                        key="who"
                                                        names={c["who"]}
                                                        max={2}
                                                    />
                                                } else {
                                                    <svg
                                                        key="gh"
                                                        width={14}
                                                        height={14}
                                                        viewBox="0 0 16 16"
                                                        className="text-muted-foreground"
                                                        role="img"
                                                        aria-label="From GitHub"
                                                    >
                                                        <path
                                                            fill="currentColor"
                                                            d="M8 .8a7.2 7.2 0 0 0-2.3 14c.4.1.5-.1.5-.3v-1.3c-2 .4-2.4-.9-2.4-.9-.3-.8-.8-1-.8-1-.7-.5 0-.5 0-.5.7.1 1.1.8 1.1.8.6 1.1 1.7.8 2.1.6.1-.5.3-.8.5-1-1.6-.2-3.3-.8-3.3-3.6 0-.8.3-1.4.8-1.9-.1-.2-.3-.9.1-1.9 0 0 .6-.2 2 .7a6.9 6.9 0 0 1 3.6 0c1.4-.9 2-.7 2-.7.4 1 .2 1.7.1 1.9.5.5.8 1.1.8 1.9 0 2.8-1.7 3.4-3.3 3.6.3.2.5.7.5 1.4v2c0 .2.1.4.5.3A7.2 7.2 0 0 0 8 .8"
                                                        />
                                                    </svg>
                                                } }
                                            </span>
                                        </span>
                                    </div>
                                }
                            }}
                        </div>
                    }}
                </div>
                <ol
                    aria-label="Log"
                    aria-live="polite"
                    className="grid gap-1 border-t bg-muted px-4 py-2.5 text-[13px]"
                >
                    {for (i, line) in enumerate(ledger) {
                        <li
                            key={line["at"] + line["title"] + str(len(ledger) - i)}
                            className="grid grid-cols-[48px_minmax(0,1fr)] gap-2.5"
                        >
                            <time
                                className="font-mono text-[12.5px] text-subtle tabular-nums"
                            >
                                {line["at"]}
                            </time>
                            <span>
                                {line["before"]}
                                {if line["issue"] {
                                    <span key="issue" className="font-mono">
                                        {line["issue"]}
                                    </span>
                                }}
                                {line["middle"]}
                                <b className="font-semibold">{line["title"]}</b>
                                {line["after"]}
                            </span>
                        </li>
                    }}
                </ol>
            </div>
            <p className="mt-2.5 text-xs text-subtle">
                {if moves > 0 {
                    <span key="after">
                        {"That line wrote itself when the card moved. "}
                        <a
                            href={"/board" if loggedIn else "/login?mode=signup"}
                            className="font-semibold text-foreground underline underline-offset-2"
                        >
                            {"Open your board" if loggedIn else "Create your workspace"}
                        </a>
                    </span>
                } else {
                    <span key="hint">
                        {"Sample data. "}
                        <span className="sm:hidden">Tap a card to move it.</span>
                        <span className="hidden sm:inline">
                            Drag a card to another column, or click it to move it along.
                        </span>
                    </span>
                } }
            </p>
        </div>;
}
