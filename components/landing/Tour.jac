"""Product tour: the three surfaces behind one tab row, flow line first,
because designing your own steps is the thing no other board offers. Every
panel is a hand-drawn mock in the product's own visual language, not a
screenshot.
"""

import from ..common.Avatar { Avatar, AvatarStack }

glob TABS: list[dict[str, str]] = [
         {"key": "flow", "label": "The flow line"},
         {"key": "board", "label": "The board"},
         {"key": "log", "label": "The daily log"}
     ],
     # The example flow the SVG draws; x is the node's left edge.
     FLOW_NODES: list[dict[str, any]] = [
         {"x": 12, "name": "Idea", "kind": "start", "cls": "text-step-sky"},
         {"x": 182, "name": "Build", "kind": "active", "cls": "text-step-amber"},
         {"x": 352, "name": "Review", "kind": "handoff", "cls": "text-step-indigo"},
         {"x": 522, "name": "Done", "kind": "done", "cls": "text-step-emerald"}
     ],
     BOARD_LANES: list[dict[str, any]] = [
         {
             "name": "Up next",
             "color": "bg-step-sky",
             "bar": "border-l-step-sky",
             "cards": [
                 {
                     "title": "Write the migration runbook",
                     "project": "Platform",
                     "dot": "bg-chart-3",
                     "who": ["Dev Fernando"],
                     "chip": "Docs"
                 }
             ]
         },
         {
             "name": "In progress",
             "color": "bg-step-amber",
             "bar": "border-l-step-amber",
             "cards": [
                 {
                     "title": "Ship the new landing page",
                     "project": "Launch Site",
                     "dot": "bg-chart-1",
                     "who": ["Amara Perera", "Kasun Silva"],
                     "chip": "Design"
                 },
                 {
                     "title": "Roll out the auth change",
                     "project": "Platform",
                     "dot": "bg-chart-3",
                     "who": ["Priya Raman"],
                     "chip": "Backend"
                 }
             ]
         },
         {
             "name": "Done",
             "color": "bg-step-emerald",
             "bar": "border-l-step-emerald",
             "cards": [
                 {
                     "title": "Pick the CDN region",
                     "project": "Launch Site",
                     "dot": "bg-chart-1",
                     "who": ["Amara Perera"],
                     "chip": "Infra"
                 }
             ]
         }
     ],
     LOG_ROWS: list[dict[str, str]] = [
         {
             "who": "Amara Perera",
             "project": "Launch Site",
             "what": "Shipped the hero rework and fixed the CDN redirect",
             "status": "Done",
             "link": "PR #142"
         },
         {
             "who": "Priya Raman",
             "project": "Platform",
             "what": "Auth change rolled out behind the flag, watching error rates",
             "status": "In progress",
             "link": ""
         },
         {
             "who": "Dev Fernando",
             "project": "Platform",
             "what": "Migration runbook drafted, ready for review",
             "status": "Review",
             "link": "#87"
         }
     ],
     STATUS_TINT: dict[str, str] = {
         "Done": "bg-step-emerald-wash text-step-emerald-ink",
         "In progress": "bg-step-amber-wash text-step-amber-ink",
         "Review": "bg-step-indigo-wash text-step-indigo-ink"
     };

def nodeMid(n: dict[str, any]) -> int {
    x: int = n["x"];
    return x + 59;
}

def:pub Tour -> JsxElement {
    has tab: str = "flow";

    return
        <section id="tour" className="mx-auto max-w-[1180px] scroll-mt-24 px-7 pt-24">
            <span
                className="text-xs font-semibold uppercase tracking-widest text-primary"
            >
                A quick look
            </span>
            <h2
                className="font-display mt-3 max-w-2xl text-[clamp(1.9rem,4vw,2.65rem)] font-bold leading-tight tracking-[-0.04em]"
            >
                The flow line, the board, the log.
            </h2>
            <p className="mt-4 max-w-2xl text-base text-muted-foreground">
                You design the flow line once. The board's columns are its steps, and the log is what each day looked like.
            </p>
            <div
                role="tablist"
                aria-label="Product tour"
                className="mt-8 flex flex-wrap gap-2"
            >
                {for t in TABS {
                    <button
                        key={t["key"]}
                        role="tab"
                        aria-selected={tab == t["key"]}
                        onClick={lambda { tab = t["key"]; }}
                        className={"rounded-full px-5 py-2 text-sm font-semibold transition-colors focus-visible:outline-2 focus-visible:outline-ring " + (
                            "bg-primary text-primary-foreground"
                                if tab == t["key"]
                                else "border bg-card text-muted-foreground hover:text-foreground"
                        )}
                    >
                        {t["label"]}
                    </button>
                }}
            </div>
            {if tab == "flow" {
                <div key="flow" className="animate-in fade-in mt-6 duration-300">
                    <div className="rounded-2xl border bg-card p-4 shadow-sm sm:p-8">
                        <svg
                            viewBox="0 0 652 168"
                            className="mx-auto block h-auto w-full max-w-3xl"
                            role="img"
                            aria-label="A flow line: Idea to Build to Review to Done, with a loop from Review back to Build"
                        >
                            {for n in FLOW_NODES {
                                <g key={n["name"]} className={n["cls"]}>
                                    <rect
                                        x={n["x"]}
                                        y={42}
                                        width={118}
                                        height={44}
                                        rx={10}
                                        stroke="currentColor"
                                        strokeWidth={1.5}
                                        style={{"fill": "var(--card)"}}
                                    />
                                    <text
                                        x={nodeMid(n)}
                                        y={62}
                                        textAnchor="middle"
                                        className="text-[13px] font-semibold"
                                        style={{"fill": "var(--foreground)"}}
                                    >
                                        {n["name"]}
                                    </text>
                                    <text
                                        x={nodeMid(n)}
                                        y={77}
                                        textAnchor="middle"
                                        className="text-[8.5px] font-medium uppercase tracking-widest"
                                        style={{"fill": "var(--muted-foreground)"}}
                                    >
                                        {n["kind"]}
                                    </text>
                                </g>
                            }}
                            <g
                                className="text-muted-foreground"
                                stroke="currentColor"
                                strokeWidth={1.4}
                                fill="none"
                                strokeLinecap="round"
                                strokeLinejoin="round"
                            >
                                <path d="M 130 64 L 176 64 m 0 0 l -7 -4 m 7 4 l -7 4"/>
                                <path d="M 300 64 L 346 64 m 0 0 l -7 -4 m 7 4 l -7 4"/>
                                <path d="M 470 64 L 516 64 m 0 0 l -7 -4 m 7 4 l -7 4"/>
                            </g>
                            <g
                                className="text-primary"
                                stroke="currentColor"
                                fill="none"
                                strokeLinecap="round"
                                strokeLinejoin="round"
                            >
                                <path
                                    d="M 396 90 C 370 134, 282 134, 254 92"
                                    strokeWidth={1.4}
                                    strokeDasharray="5 5"
                                />
                                <path
                                    d="M 254 92 l -1 9 m 1 -9 l 9 2"
                                    strokeWidth={1.4}
                                />
                            </g>
                            <text
                                x={325}
                                y={146}
                                textAnchor="middle"
                                className="text-[10px] font-semibold"
                                style={{"fill": "var(--primary)"}}
                            >
                                changes requested · loops on purpose
                            </text>
                        </svg>
                    </div>
                    <p className="mt-4 max-w-2xl text-sm text-muted-foreground">
                        <span className="font-semibold text-foreground">
                            You draw this once.
                        </span>{" "}
                        Name the steps your team actually uses and connect them the way work actually moves, loops included. The board's columns are these steps, so the two can never disagree.
                    </p>
                </div>
            }}
            {if tab == "board" {
                <div key="board" className="animate-in fade-in mt-6 duration-300">
                    <div className="rounded-2xl border bg-card p-4 shadow-sm sm:p-6">
                        <div className="grid grid-cols-3 gap-2.5">
                            {for lane in BOARD_LANES {
                                <div
                                    key={lane["name"]}
                                    className="relative flex min-h-36 flex-col gap-2 rounded-xl border bg-muted/40 p-2 pt-2.5"
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
                                            {len(lane["cards"])}
                                        </span>
                                    </div>
                                    {for c in lane["cards"] {
                                        <div
                                            key={c["title"]}
                                            className={"rounded-lg border-l-[3px] bg-card p-2 shadow-xs ring-1 ring-foreground/10 " + lane[
                                                "bar"
                                            ]}
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
                                                        if lane["name"] == "Done"
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
                                            </div>
                                        </div>
                                    }}
                                </div>
                            }}
                        </div>
                    </div>
                    <p className="mt-4 max-w-2xl text-sm text-muted-foreground">
                        <span className="font-semibold text-foreground">
                            Your steps become the columns.
                        </span>{" "}
                        Drag a card between them, and filter the board by project or assignee. Try it yourself in the hero above.
                    </p>
                </div>
            }}
            {if tab == "log" {
                <div key="log" className="animate-in fade-in mt-6 duration-300">
                    <div
                        className="rounded-2xl border bg-card px-4 py-2 shadow-sm sm:px-6"
                    >
                        <div
                            className="border-b py-3 text-[11px] font-semibold uppercase tracking-widest text-muted-foreground"
                        >
                            Mon · Aug 24
                        </div>
                        {for (i, r) in enumerate(LOG_ROWS) {
                            <div
                                key={r["who"]}
                                className={"flex items-center gap-3 py-3 " + (
                                    "border-b" if i < len(LOG_ROWS) - 1 else ""
                                )}
                            >
                                <Avatar name={r["who"]} size="sm"/>
                                <div className="min-w-0 flex-1">
                                    <div
                                        className="flex flex-wrap items-center gap-2 text-xs font-semibold"
                                    >
                                        {r["who"]}
                                        <span
                                            className="text-[10px] font-medium text-muted-foreground"
                                        >
                                            {r["project"]}
                                        </span>
                                    </div>
                                    <div
                                        className="mt-0.5 truncate text-xs text-muted-foreground"
                                    >
                                        {r["what"]}
                                    </div>
                                </div>
                                <div className="flex shrink-0 items-center gap-1.5">
                                    <span
                                        className={"rounded-full px-2 py-0.5 text-[9.5px] font-bold " + STATUS_TINT[
                                            r["status"]
                                        ]}
                                    >
                                        {r["status"]}
                                    </span>
                                    {if r["link"] {
                                        <span
                                            key="link"
                                            className="rounded-md border px-1.5 py-0.5 text-[9.5px] font-medium text-muted-foreground"
                                        >
                                            {r["link"]}
                                        </span>
                                    }}
                                </div>
                            </div>
                        }}
                    </div>
                    <p className="mt-4 max-w-2xl text-sm text-muted-foreground">
                        <span className="font-semibold text-foreground">
                            One line per person per weekday.
                        </span>{" "}
                        The work, the project, the status and the links. The week view is the summary you used to hold a meeting for, and unlike the meeting, it is still there next month.
                    </p>
                </div>
            }}
        </section>;
}
