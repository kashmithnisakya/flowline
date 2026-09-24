"""Product tour: the flow line, the board and the log as three always-visible
rows, each a short statement beside a rendering in the product's own system.
The diagram grows with its column to about 960px, so its labels stay near the
row heading's size, and scrolls sideways on phones rather than shrinking.
"""

import from ..common.Avatar { Avatar, AvatarStack }
import from ..common.KindGlyph { KindGlyph }
import from ..common.StepName { StepName }

glob NODE_W: int = 116,
     NODE_H: int = 54,
     SWATCH_FILL: dict[str, str] = {
         "sky": "var(--step-sky)",
         "amber": "var(--step-amber)",
         "indigo": "var(--step-indigo)",
         "rose": "var(--step-rose)",
         "emerald": "var(--step-emerald)"
     },
     FLOW_NODES: list[dict[str, any]] = [
         {
             "name": "Specify",
             "kind": "start",
             "color": "sky",
             "owner": "Anyone",
             "x": 6,
             "y": 110
         },
         {
             "name": "Design",
             "kind": "active",
             "color": "amber",
             "owner": "Architect",
             "x": 160,
             "y": 18
         },
         {
             "name": "Build",
             "kind": "active",
             "color": "indigo",
             "owner": "Model Pilot Engineer",
             "x": 314,
             "y": 110
         },
         {
             "name": "Review",
             "kind": "handoff",
             "color": "rose",
             "owner": "Reviewer",
             "x": 468,
             "y": 110
         },
         {
             "name": "Done",
             "kind": "done",
             "color": "emerald",
             "owner": "",
             "x": 622,
             "y": 110
         }
     ],
     BOARD: list[dict[str, any]] = [
         {
             "name": "Specify",
             "color": "sky",
             "cards": [
                 {
                     "title": "Push notification opt-in screen",
                     "meta": "Mobile app",
                     "who": ["Nina Park"]
                 },
                 {
                     "title": "Tax ID field for EU customers",
                     "meta": "Billing",
                     "who": ["Ravi Kumar"]
                 }
             ]
         },
         {
             "name": "Design",
             "color": "amber",
             "cards": [
                 {
                     "title": "Proration for mid-cycle plan changes",
                     "meta": "Billing",
                     "who": ["Dev Fernando"]
                 }
             ]
         },
         {
             "name": "Build",
             "color": "indigo",
             "cards": [
                 {
                     "title": "Invoice PDF redesign",
                     "meta": "Billing · due Thu",
                     "who": ["Priya Raman"]
                 },
                 {
                     "title": "Dark mode polish on settings",
                     "meta": "Mobile app",
                     "who": ["Kasun Silva"]
                 }
             ]
         },
         {
             "name": "Review",
             "color": "rose",
             "cards": [
                 {
                     "title": "Webhook for cancelled subscriptions",
                     "meta": "Billing · #412",
                     "who": ["Priya Raman", "Dev Fernando"]
                 }
             ]
         },
         {
             "name": "Done",
             "color": "emerald",
             "cards": [
                 {
                     "title": "Stripe SDK upgrade",
                     "meta": "Billing",
                     "who": ["Priya Raman"]
                 }
             ]
         }
     ],
     LOG_ROWS: list[dict[str, str]] = [
         {
             "at": "09:15",
             "kind": "done",
             "who": "Priya Raman",
             "what": "Moved to Done · issue closed",
             "task": "Receipt emails missing VAT number",
             "link": "#398"
         },
         {
             "at": "09:42",
             "kind": "active",
             "who": "Priya Raman",
             "what": "Moved to Build",
             "task": "Invoice PDF redesign",
             "link": ""
         },
         {
             "at": "10:30",
             "kind": "handoff",
             "who": "Dev Fernando",
             "what": "Moved to Review · Priya Raman",
             "task": "Webhook for cancelled subscriptions",
             "link": "PR #412"
         },
         {
             "at": "11:05",
             "kind": "active",
             "who": "Kasun Silva",
             "what": "Checked off: Reproduce on a Pixel 8 (2/5)",
             "task": "Crash when rotating on Android 14",
             "link": ""
         },
         {
             "at": "14:20",
             "kind": "active",
             "who": "Leo Martins",
             "what": "Wrote up the Lighthouse fixes for the pricing page",
             "task": "",
             "link": ""
         }
     ];

def TourRow(title: str, body: str, children: any = None) -> JsxElement {
    return
        <div
            className="grid gap-5 border-t py-10 xl:grid-cols-[minmax(0,1fr)_minmax(0,3fr)] xl:gap-10"
        >
            <div className="grid content-start gap-2">
                <h3 className="text-lg leading-snug font-semibold tracking-[-0.01em]">
                    {title}
                </h3>
                <p
                    className="max-w-[54ch] text-[15px] leading-relaxed text-muted-foreground"
                >
                    {body}
                </p>
            </div>
            <div className="min-w-0">{children}</div>
        </div>;
}

def FlowDiagram -> JsxElement {
    return
        <div className="overflow-x-auto rounded-xl border bg-background">
            <svg
                viewBox="0 0 744 236"
                className="mx-auto block h-auto w-full max-w-[960px] min-w-[744px]"
                role="img"
                aria-label="A flow line: Specify goes to Build, or through Design for big changes; Build goes to Review, Review to Done, and Review can send work back to Build."
            >
                <g
                    className="text-wire"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={1.6}
                >
                    <path d="M122 137H307"/>
                    <path d="M64 110C64 72 96 45 153 45"/>
                    <path d="M276 45C336 45 372 58 372 103"/>
                    <path d="M430 137H461"/>
                    <path d="M584 137H615"/>
                    <path d="M526 164C526 208 372 208 372 171" strokeDasharray="5 4"/>
                </g>
                <g className="text-wire" fill="currentColor">
                    <path d="M307 133l7 4-7 4z"/>
                    <path d="M153 41l7 4-7 4z"/>
                    <path d="M368 103l4 7 4-7z"/>
                    <path d="M461 133l7 4-7 4z"/>
                    <path d="M615 133l7 4-7 4z"/>
                    <path d="M368 171l4-7 4 7z"/>
                </g>
                <g
                    className="font-mono text-xs"
                    style={{"fill": "var(--subtle)"}}
                    textAnchor="middle"
                >
                    <text x={218} y={129}>Issue</text>
                    <text x={449} y={129}>PR</text>
                    <text x={603} y={129}>PR</text>
                    <text x={94} y={90} textAnchor="start">Big changes</text>
                    <text x={449} y={226}>Changes requested</text>
                </g>
                {for n in FLOW_NODES {
                    <g key={n["name"]}>
                        <rect
                            x={n["x"]}
                            y={n["y"]}
                            width={NODE_W}
                            height={NODE_H}
                            rx={4}
                            style={{"fill": "var(--card)", "stroke": "var(--border)"}}
                        />
                        <rect
                            x={int(n["x"]) + 10}
                            y={int(n["y"]) + 13}
                            width={10}
                            height={10}
                            rx={2}
                            style={{"fill": SWATCH_FILL[n["color"]]}}
                        />
                        <text
                            x={int(n["x"]) + 26}
                            y={int(n["y"]) + 22}
                            className="text-[13px] font-semibold"
                            style={{"fill": "var(--foreground)"}}
                        >
                            {n["name"]}
                        </text>
                        <g
                            transform={"translate("
                                + str(int(n["x"]) + NODE_W - 24)
                                + " "
                                + str(int(n["y"]) + 11)
                                + ")"}
                            className="text-muted-foreground"
                        >
                            <KindGlyph kind={n["kind"]}/>
                        </g>
                        {if n["owner"] {
                            <text
                                key="owner"
                                x={int(n["x"]) + 10}
                                y={int(n["y"]) + 42}
                                className="text-xs"
                                style={{"fill": "var(--subtle)"}}
                            >
                                {n["owner"]}
                            </text>
                        }}
                    </g>
                }}
            </svg>
        </div>;
}

def BoardFragment -> JsxElement {
    return
        <div className="overflow-x-auto rounded-xl border bg-card">
            <div className="grid min-w-[700px] grid-cols-5">
                {for col in BOARD {
                    <div
                        key={col["name"]}
                        className="flex min-h-[210px] flex-col gap-2 border-r p-2.5 last:border-r-0"
                    >
                        <div
                            className="flex items-center gap-1.5 text-[13px] font-semibold"
                        >
                            <StepName name={col["name"]} color={col["color"]}/>
                            <span
                                className="ml-auto font-mono text-xs font-medium text-subtle tabular-nums"
                            >
                                {len(col["cards"])}
                            </span>
                        </div>
                        {for c in col["cards"] {
                            <div
                                key={c["title"]}
                                className="grid gap-1.5 rounded-md border bg-card p-2"
                            >
                                <span
                                    className="text-[13px] leading-[1.35] font-medium"
                                >
                                    {c["title"]}
                                </span>
                                <span
                                    className="flex min-w-0 flex-wrap items-center gap-1 text-xs text-muted-foreground"
                                >
                                    <span className="whitespace-nowrap">
                                        {c["meta"]}
                                    </span>
                                    <span className="ml-auto inline-flex shrink-0">
                                        <AvatarStack names={c["who"]} max={2}/>
                                    </span>
                                </span>
                            </div>
                        }}
                    </div>
                }}
            </div>
        </div>;
}

def LogLedger -> JsxElement {
    return
        <div className="overflow-hidden rounded-xl border bg-card">
            <div
                className="flex items-baseline justify-between gap-3 border-b px-4 py-2.5"
            >
                <span className="text-sm font-semibold">Tuesday</span>
                <span className="font-mono text-xs text-subtle tabular-nums">
                    5 entries · 4 people
                </span>
            </div>
            <ol className="divide-y">
                {for r in LOG_ROWS {
                    <li
                        key={r["at"]}
                        className="grid grid-cols-[44px_minmax(0,1fr)] gap-x-3 gap-y-1 px-4 py-2.5 text-[13.5px] sm:grid-cols-[48px_150px_minmax(0,1fr)]"
                    >
                        <time
                            className="pt-px font-mono text-[12.5px] text-subtle tabular-nums"
                        >
                            {r["at"]}
                        </time>
                        <span className="flex min-w-0 items-center gap-2 font-medium">
                            <Avatar name={r["who"]} size="xs"/>
                            <span className="truncate">{r["who"]}</span>
                        </span>
                        <span
                            className="col-start-2 flex min-w-0 items-start gap-2 sm:col-start-3"
                        >
                            <KindGlyph
                                kind={r["kind"]}
                                className="mt-[3px] text-muted-foreground"
                            />
                            <span className="min-w-0">
                                {r["what"]}
                                {if r["task"] {
                                    <span key="task" className="text-muted-foreground">
                                        {" · " + r["task"]}
                                    </span>
                                }}
                                {if r["link"] {
                                    <span key="link" className="text-muted-foreground">
                                        {" · "}
                                        <span className="font-mono text-[12.5px]">
                                            {r["link"]}
                                        </span>
                                    </span>
                                }}
                            </span>
                        </span>
                    </li>
                }}
            </ol>
        </div>;
}

def:pub Tour -> JsxElement {
    return
        <section id="tour" className="landing-wrap scroll-mt-16 pt-16 sm:pt-24">
            <p className="section-eyebrow">The tour</p>
            <h2
                className="mt-3 max-w-[28ch] text-[clamp(1.75rem,3.4vw,2.5rem)] leading-[1.1] font-bold tracking-[-0.025em]"
            >
                One flow line, three views of the same work
            </h2>
            <p
                className="mt-3 max-w-[62ch] text-base leading-relaxed text-muted-foreground"
            >
                You draw the steps once. The board and the log read from them, so the three can never disagree.
            </p>
            <div className="mt-8">
                <TourRow
                    title="Flow line"
                    body="Name the steps your team really uses and connect them the way work moves, branches and loops included. Each step says what it means (start, active, handoff, blocked or done) and can name who owns it; a connection can say whether it carries an issue or a pull request."
                >
                    <FlowDiagram/>
                    <p className="mt-2 text-xs text-subtle min-[792px]:hidden">
                        Scroll sideways to see the whole flow line.
                    </p>
                </TourRow>
                <TourRow
                    title="Board"
                    body="The board's columns are those steps, in order. Drag a card to move it, filter by project or person, and open a card for its details, checklist and GitHub links. Moving a card to Review can ask for a reviewer and a pull request; a blocked card asks for a note."
                >
                    <BoardFragment/>
                    <p className="mt-2 text-xs text-subtle min-[748px]:hidden">
                        Scroll sideways to see every column.
                    </p>
                </TourRow>
                <TourRow
                    title="Log"
                    body="Every move lands in the day's log with the time, the people on the card and its issue or pull request. Add what happened off the board by hand. The week view is the summary a standup used to be for, and it is still there next month."
                >
                    <LogLedger/>
                </TourRow>
            </div>
        </section>;
}
