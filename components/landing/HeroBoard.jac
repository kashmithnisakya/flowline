"""The landing hero's product mock, now playable: drag a card between lanes
(or tap it) and the log beneath writes the move, which is the whole pitch.
Until the visitor touches it the scripted loop plays; the first real move
freezes the script and the visitor's own moves take over.
"""

import from "react" { useEffect }
import from ..common.Avatar { AvatarStack }

# Where each card sits at each stage: index into LANES. Four stages loop.
glob LANES: list[dict[str, str]] = [
         {"name": "Up next", "color": "bg-step-sky"},
         {"name": "In progress", "color": "bg-step-amber"},
         {"name": "Done", "color": "bg-step-emerald"}
     ],
     CARDS: list[dict[str, any]] = [
         {
             "title": "Ship the new landing page",
             "project": "Launch Site",
             "dot": "bg-chart-1",
             "who": ["Amara Perera", "Kasun Silva"],
             "chip": "Design",
             "due": "Tomorrow",
             "lanes": [1, 2, 2, 2]
         },
         {
             "title": "Roll out the auth change",
             "project": "Platform",
             "dot": "bg-chart-3",
             "who": ["Priya Raman"],
             "chip": "Backend",
             "due": "",
             "lanes": [1, 1, 1, 2]
         },
         {
             "title": "Pick the CDN region",
             "project": "Launch Site",
             "dot": "bg-chart-1",
             "who": ["Amara Perera"],
             "chip": "Infra",
             "due": "Aug 20",
             "lanes": [0, 0, 1, 1]
         },
         {
             "title": "Write the migration runbook",
             "project": "Platform",
             "dot": "bg-chart-3",
             "who": ["Dev Fernando"],
             "chip": "Docs",
             "due": "",
             "lanes": [0, 0, 0, 0]
         }
     ],
     # The log line each stage writes (stage 0 is the resting state).
     LOG_LINES: list[str] = [
         "",
         "Amara Perera moved Ship the new landing page to Done",
         "Amara Perera moved Pick the CDN region to In progress",
         "Priya Raman moved Roll out the auth change to Done"
     ],
     STAGES: int = 4,
     TICK_MS: int = 3800;

def laneOf(card: dict[str, any], stage: int) -> int {
    lanes: list[int] = card["lanes"];
    return lanes[stage];
}

def:pub HeroBoard(loggedIn: bool = False) -> JsxElement {
    has stage: int = 0,
        still: bool = False,
        # Set by the visitor's first move; stops the scripted loop for good.
        live: bool = False,
        userLanes: dict[str, int] = {},
        userLog: list[str] = [],
        moves: int = 0,
        dragTitle: str = "",
        overLane: int = -1;

    can with entry {
        w: any = window;
        media: any = w.matchMedia("(prefers-reduced-motion: reduce)");
        if bool(media.matches) {
            still = True;
            stage = STAGES - 1;
        }
    }

    # Re-armed each stage so the callback always sees the current value (a
    # setInterval closure would be stuck on the first render's stage).
    useEffect(
        lambda {
            # The early exit returns a no-op cleanup rather than None: React
            # calls back anything that is not `undefined`, so returning null
            # crashes the page on the next run of this effect.
            timer: any = 0;
            if not still and not live {
                timer = window.setTimeout(
                    lambda { stage = (stage + 1) % STAGES; }, TICK_MS
                );
            }
            return lambda { if timer { window.clearTimeout(timer); }};
        },
        [stage, still, live]
    );

    def curLane(card: dict[str, any]) -> int {
        if live {
            return userLanes[card["title"]];
        }
        return laneOf(card, stage);
    }

    def moveTo(title: str, target: int) {
        # First move freezes EVERY card where the script left it, so
        # stopping the loop shifts nothing else on the board.
        updated: dict[str, int] = {** userLanes};
        if not live {
            for c in CARDS {
                updated[c["title"]] = laneOf(c, stage);
            }
        }
        if updated[title] == target {
            return;
        }
        updated[title] = target;
        userLanes = updated;
        userLog = userLog + ["You moved " + title + " to " + LANES[target]["name"]];
        live = True;
        moves = moves + 1;
    }

    # The log shows the last three lines: whatever the script wrote before
    # the visitor took over, then the visitor's own moves.
    allLines = [LOG_LINES[i] for i in range(1, stage + 1)] + userLog;
    start = len(allLines) - 3;
    if start < 0 {
        start = 0;
    }
    recent = [allLines[i] for i in range(start, len(allLines))];

    return
        <div
            className="anim-fade-up anim-d4 mx-auto mt-12 w-full max-w-3xl text-left lg:mx-0 lg:mt-0 lg:max-w-none"
        >
            <div
                className={"flex items-center justify-end gap-1.5 pb-2 text-[11px] font-semibold text-primary transition-opacity duration-300 "
                    + ("opacity-0" if moves > 0 else "")}
                aria-hidden="true"
            >
                Drag a card, or tap one
                <svg
                    width={12}
                    height={12}
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={2.5}
                    strokeLinecap="round"
                    strokeLinejoin="round"
                >
                    <path d="M12 5v14"/>
                    <path d="m19 12-7 7-7-7"/>
                </svg>
            </div>
            <div
                role="group"
                aria-label="Try the board: drag a card between columns, or press Enter on a card to move it"
                className="rounded-2xl bg-background/70 p-3 shadow-xl ring-1 ring-foreground/10 backdrop-blur"
            >
                <div className="grid grid-cols-3 gap-2.5">
                    {for (li, lane) in enumerate(LANES) {
                        <div
                            key={lane["name"]}
                            className={"relative flex min-h-40 flex-col gap-2 rounded-xl border bg-muted/40 p-2 pt-2.5 transition-[box-shadow,background-color] duration-150 "
                                + (
                                    "bg-primary/5 ring-2 ring-primary/40"
                                        if overLane == li
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
                                e.preventDefault();
                                # dragleave fires entering a child card too;
                                # only clear when the pointer really left.
                                ct: any = e.currentTarget;
                                rt: any = e.relatedTarget;
                                if not (ct and rt and ct.contains(rt)) {
                                    overLane = -1;
                                }
                            }}
                            onDrop={lambda (e: DragEvent) {
                                e.preventDefault();
                                dt = e.dataTransfer;
                                title = dt.getData("text/x-flowline-demo")
                                    if dt
                                    else "";
                                overLane = -1;
                                if title {
                                    moveTo(title, li);
                                }
                            }}
                        >
                            <span
                                className={"absolute inset-x-3 top-0 h-[3px] rounded-b-full "
                                    + lane["color"]}
                            />
                            <div
                                className="flex items-center justify-between px-1 text-[11px] font-semibold"
                            >
                                <span className="flex items-center gap-1.5">
                                    <span
                                        className={"h-1.5 w-1.5 rounded-full "
                                            + lane["color"]}
                                    />
                                    {lane["name"]}
                                </span>
                                <span
                                    className="rounded-full bg-muted px-1.5 tabular-nums text-muted-foreground"
                                >
                                    {len(
                                        [
                                            c
                                            for c in CARDS
                                            if curLane(c) == li
                                        ]
                                    )}
                                </span>
                            </div>
                            {for c in CARDS {
                                if curLane(c) == li {
                                    <div
                                        key={c["title"]}
                                        draggable={True}
                                        role="button"
                                        tabIndex={0}
                                        aria-label={str(c["title"])
                                            + ". Drag to another column, or press Enter to move it along."}
                                        onDragStart={lambda (e: DragEvent) {
                                            dt = e.dataTransfer;
                                            if dt {
                                                dt.setData(
                                                    "text/x-flowline-demo", c["title"]
                                                );
                                                dt.effectAllowed = "move";
                                            }
                                            dragTitle = c["title"];
                                        }}
                                        onDragEnd={lambda {
                                            dragTitle = "";
                                            overLane = -1;
                                        }}
                                        onClick={lambda { moveTo(
                                            c["title"], (curLane(c) + 1) % len(LANES)
                                        ); }}
                                        onKeyDown={lambda (e: KeyboardEvent) { if e.key
                                            == "Enter"
                                            or e.key == " " {
                                            e.preventDefault();
                                            moveTo(
                                                c["title"],
                                                (curLane(c) + 1) % len(LANES)
                                            );
                                        }}}
                                        className={"animate-in fade-in slide-in-from-bottom-1 cursor-grab select-none rounded-lg border-l-[3px] bg-card p-2 shadow-xs ring-1 ring-foreground/10 transition-shadow duration-500 hover:shadow-md focus-visible:ring-2 focus-visible:ring-ring active:cursor-grabbing "
                                            + (
                                                "opacity-50 "
                                                    if dragTitle == c["title"]
                                                    else ""
                                            )
                                            + (
                                                "border-l-step-emerald"
                                                    if li == 2
                                                    else (
                                                        "border-l-step-amber"
                                                            if li == 1
                                                            else "border-l-step-sky"
                                                    )
                                            )}
                                    >
                                        <div
                                            className="flex items-center gap-1 text-[9px] font-medium text-muted-foreground"
                                        >
                                            <span
                                                className={"h-1 w-1 rounded-full "
                                                    + c["dot"]}
                                            />
                                            {c["project"]}
                                        </div>
                                        <div
                                            className={"mt-0.5 text-[11px] font-medium leading-snug "
                                                + (
                                                    "text-muted-foreground line-through decoration-foreground/30"
                                                        if li == 2
                                                        else ""
                                                )}
                                        >
                                            {c["title"]}
                                        </div>
                                        <div
                                            className="mt-1.5 flex items-center gap-1.5"
                                        >
                                            <AvatarStack names={c["who"]} max={2}/>
                                            <span
                                                className="rounded-full border px-1.5 text-[9px] font-medium"
                                            >
                                                {c["chip"]}
                                            </span>
                                            {if c["due"] and li != 2 {
                                                <span
                                                    key="due"
                                                    className={"ml-auto text-[9px] font-semibold "
                                                        + (
                                                            "rounded bg-warning/15 px-1 text-warning"
                                                                if c["due"]
                                                                    == "Tomorrow"
                                                                else "text-muted-foreground"
                                                        )}
                                                >
                                                    {c["due"]}
                                                </span>
                                            }}
                                        </div>
                                    </div>
                                }
                            }}
                        </div>
                    }}
                </div>
                <div
                    className="mt-2.5 flex items-start gap-3 rounded-xl border bg-card/80 px-3 py-2"
                >
                    <span
                        className="mt-0.5 shrink-0 text-[10px] font-semibold uppercase tracking-wide text-muted-foreground"
                    >
                        Log
                    </span>
                    <div className="min-w-0 flex-1 space-y-0.5 text-[11px]">
                        {if len(recent) == 0 {
                            <div key="quiet" className="text-muted-foreground/70">
                                Written automatically as cards move.
                            </div>
                        }}
                        {for (i, line) in enumerate(recent) {
                            <div
                                key={str(i)}
                                className={"animate-in fade-in slide-in-from-left-1 truncate duration-500 "
                                    + (
                                        "text-foreground"
                                            if i == len(recent) - 1
                                            else "text-muted-foreground"
                                    )}
                            >
                                {line}
                                {if i == len(recent) - 1 {
                                    <span
                                        key="now"
                                        className="ml-1.5 text-muted-foreground/70"
                                    >
                                        just now
                                    </span>
                                }}
                            </div>
                        }}
                    </div>
                </div>
                {if moves > 0 {
                    <div
                        key="cta"
                        className="animate-in fade-in slide-in-from-bottom-1 mt-2.5 rounded-xl border border-primary/25 bg-primary/10 px-3 py-2 text-[12px] duration-300"
                    >
                        <span className="font-semibold text-primary">
                            That line is the daily log writing itself.
                        </span>{" "}
                        {if loggedIn {
                            <a
                                key="board"
                                href="/board"
                                className="font-semibold underline underline-offset-2 hover:text-primary"
                            >
                                Open your board
                            </a>
                        } else {
                            <a
                                key="signup"
                                href="/login?mode=signup"
                                className="font-semibold underline underline-offset-2 hover:text-primary"
                            >
                                Create your workspace
                            </a>
                        } }
                    </div>
                }}
            </div>
        </div>;
}
