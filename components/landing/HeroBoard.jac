"""The landing hero's product mock: a three-lane board with real-looking
cards where, every few seconds, one card moves and a log line appears
beneath, which is the whole pitch (the board writes the log). Decorative and
aria-hidden; reduced-motion users see the final state without the loop.
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

def:pub HeroBoard -> JsxElement {
    has stage: int = 0,
        still: bool = False;

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
            if not still {
                timer = window.setTimeout(
                    lambda { stage = (stage + 1) % STAGES; }, TICK_MS
                );
            }
            return lambda { if timer { window.clearTimeout(timer); }};
        },
        [stage, still]
    );

    recent = [LOG_LINES[i] for i in range(1, stage + 1)];

    return
        <div
            aria-hidden="true"
            className="anim-fade-up anim-d5 mx-auto mt-14 max-w-3xl text-left"
        >
            <div
                className="rounded-2xl bg-background/70 p-3 shadow-xl ring-1 ring-foreground/10 backdrop-blur"
            >
                <div className="grid grid-cols-3 gap-2.5">
                    {for (li, lane) in enumerate(LANES) {
                        <div
                            key={lane["name"]}
                            className="relative flex min-h-40 flex-col gap-2 rounded-xl border bg-muted/40 p-2 pt-2.5"
                        >
                            <span
                                className={"absolute inset-x-3 top-0 h-[3px] rounded-b-full " + lane[
                                    "color"
                                ]}
                            />
                            <div
                                className="flex items-center justify-between px-1 text-[11px] font-semibold"
                            >
                                <span className="flex items-center gap-1.5">
                                    <span
                                        className={"h-1.5 w-1.5 rounded-full " + lane[
                                            "color"
                                        ]}
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
                                            if laneOf(c, stage) == li
                                        ]
                                    )}
                                </span>
                            </div>
                            {for c in CARDS {
                                if laneOf(c, stage) == li {
                                    <div
                                        key={c["title"]}
                                        className={"animate-in fade-in slide-in-from-bottom-1 rounded-lg border-l-[3px] bg-card p-2 shadow-xs ring-1 ring-foreground/10 duration-500 " + (
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
                                                className={"h-1 w-1 rounded-full " + c[
                                                    "dot"
                                                ]}
                                            />
                                            {c["project"]}
                                        </div>
                                        <div
                                            className={"mt-0.5 text-[11px] font-medium leading-snug " + (
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
                                                    className={"ml-auto text-[9px] font-semibold " + (
                                                        "rounded bg-warning/15 px-1 text-warning"
                                                            if c["due"] == "Tomorrow"
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
                                className={"animate-in fade-in slide-in-from-left-1 truncate duration-500 " + (
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
            </div>
        </div>;
}
