"""The roadmap as a diagram: a spine of steps with branches either side.

Every position here comes from the server (`depth` is the row, `lane` the
column, 0 being the spine), so the picture is a pure function of the arrows
somebody drew. Nothing is dragged and no coordinate is stored: add an arrow
and the shape re-forms around it, which is the only way the drawing and the
app's own "what can we start" answer can never disagree.

The SVG deliberately carries no viewBox and no transform, so one SVG unit is
one CSS pixel and the same helpers place both the curves and the cards. That
is what keeps this free of coordinate-space conversion.
"""

import from ...models { MilestoneView }
import from ..ui.badge { Badge }

# The step stores a colour KEY; class strings must stay literal in these
# tables or Tailwind's scanner drops them from the build.
glob SPINE_TINT: dict[str, str] = {
    "violet": "border-violet-500/60 bg-violet-500/20",
    "sky": "border-sky-500/60 bg-sky-500/20",
    "emerald": "border-emerald-500/60 bg-emerald-500/20",
    "amber": "border-amber-500/60 bg-amber-500/20",
    "rose": "border-rose-500/60 bg-rose-500/20",
    "slate": "border-slate-500/60 bg-slate-500/20"
};

glob BRANCH_TINT: dict[str, str] = {
    "violet": "border-violet-500/30 bg-violet-500/5",
    "sky": "border-sky-500/30 bg-sky-500/5",
    "emerald": "border-emerald-500/30 bg-emerald-500/5",
    "amber": "border-amber-500/30 bg-amber-500/5",
    "rose": "border-rose-500/30 bg-rose-500/5",
    "slate": "border-slate-500/30 bg-slate-500/5"
};

glob DOT_FILL: dict[str, str] = {
    "violet": "bg-violet-500",
    "sky": "bg-sky-500",
    "emerald": "bg-emerald-500",
    "amber": "bg-amber-500",
    "rose": "bg-rose-500",
    "slate": "bg-slate-500"
};

# Card box and grid pitch, in px. Node height is uniform, which is what makes
# every edge endpoint exact arithmetic rather than a measurement.
glob NODE_W: int = 208;
glob NODE_W_B: int = 184;
glob NODE_H: int = 76;
glob LANE_PX: int = 240;
glob ROW_PX: int = 140;
glob PAD: int = 40;


def colorKey(raw: str) -> str {
    if raw in SPINE_TINT {
        return raw;
    }
    return "slate";
}


def:pub Flow(
    steps: list[MilestoneView],
    selectedId: str = "",
    connectFrom: str = "",
    selectedEdge: str = "",
    blockedTargets: list[str] = [],
    onSelect: Callable[[str], None] = None,
    onSelectEdge: Callable[[str], None] = None,
    onDeleteEdge: Callable[[str, str], None] = None,
    onCanvasClick: Callable[[], None] = None
) -> JsxElement {
    grid = [s for s in steps if s.depth >= 0];
    tray = [s for s in steps if s.depth < 0];

    # Explicit loops: max() over a list compiles to Math.max(array), which is
    # NaN. Seeded at 0 so a lone spine step still centres.
    minLane = 0;
    maxLane = 0;
    maxDepth = 0;
    for s in grid {
        if s.lane < minLane {
            minLane = s.lane;
        }
        if s.lane > maxLane {
            maxLane = s.lane;
        }
        if s.depth > maxDepth {
            maxDepth = s.depth;
        }
    }
    laneSpan = maxLane - minLane + 1;
    canvasW = PAD * 2 + laneSpan * LANE_PX;
    canvasH = PAD * 2 + (maxDepth + 1) * ROW_PX;

    def centreX(s: MilestoneView) -> float {
        return PAD + (s.lane - minLane) * LANE_PX + LANE_PX / 2;
    }

    def widthOf(s: MilestoneView) -> int {
        return NODE_W if s.lane == 0 else NODE_W_B;
    }

    def topY(s: MilestoneView) -> float {
        return PAD + s.depth * ROW_PX;
    }

    byId: dict[str, MilestoneView] = {};
    for s in grid {
        byId[s.id] = s;
    }

    # Flatten the arrows once so the SVG can be one pass. Only edges whose
    # both ends are on this canvas are drawable.
    links: list[dict[str, any]] = [];
    for s in grid {
        for nid in s.next_ids {
            if nid not in byId {
                continue;
            }
            target = byId[nid];
            x1 = centreX(s);
            y1 = topY(s) + NODE_H;
            x2 = centreX(target);
            y2 = topY(target);
            bend = (y2 - y1) * 0.4;
            if bend < 30.0 {
                bend = 30.0;
            }
            # Vertical control handles: every edge leaves and enters travelling
            # straight down, so the flow reads downward even across a wide
            # branch, and direction needs no arrowhead.
            path = (
                "M " + str(x1) + " " + str(y1)
                + " C " + str(x1) + " " + str(y1 + bend)
                + ", " + str(x2) + " " + str(y2 - bend)
                + ", " + str(x2) + " " + str(y2)
            );
            onSpine = s.lane == 0 and target.lane == 0;
            crossing = s.lane * target.lane < 0;
            tone = "text-muted-foreground/50";
            if s.status == "Done" and target.status == "Done" {
                tone = "text-emerald-600/40";
            } elif onSpine {
                tone = "text-primary";
            } elif crossing {
                tone = "text-muted-foreground/25";
            }
            links.append({
                "key": s.id + ">" + nid,
                "from": s.id,
                "to": nid,
                "d": path,
                "spine": onSpine,
                "tone": tone,
                # Symmetric control offsets make the curve midpoint exactly
                # the midpoint of the endpoints, so the delete chip needs no
                # curve sampling.
                "mx": (x1 + x2) / 2,
                "my": (y1 + y2) / 2
            });
        }
    }

    connecting = bool(connectFrom);

    return <div className="space-y-3">
        <div
            className="overflow-auto rounded-lg border bg-card"
            style={{"maxHeight": "72vh"}}
            onClick={lambda { if onCanvasClick { onCanvasClick(); } }}
        >
            <div
                className="relative"
                style={{"width": str(canvasW) + "px", "height": str(canvasH) + "px"}}
            >
                <svg
                    width={canvasW}
                    height={canvasH}
                    className="absolute inset-0"
                    style={{"pointerEvents": "none"}}
                >
                    {for l in links {
                        <g key={l["key"]} className={l["tone"]}>
                            <path
                                d={l["d"]}
                                fill="none"
                                stroke="currentColor"
                                strokeWidth={2.5 if l["spine"] else 2}
                                strokeLinecap="round"
                                strokeDasharray={"0" if l["spine"] else "3 7"}
                            />
                            <path
                                d={l["d"]}
                                fill="none"
                                stroke="transparent"
                                strokeWidth={18}
                                style={{"pointerEvents": "stroke", "cursor": "pointer"}}
                                onClick={lambda (e: MouseEvent) {
                                    e.stopPropagation();
                                    if onSelectEdge { onSelectEdge(l["key"]); }
                                }}
                            />
                        </g>
                    }}
                </svg>

                {for l in links {
                    <div key={"chip-" + l["key"]}>
                        {if selectedEdge == l["key"] {
                            <button
                                key="del"
                                type="button"
                                title="Remove this connection"
                                className="absolute z-20 flex h-5 w-5 items-center justify-center rounded-full border bg-background text-xs text-muted-foreground shadow-sm hover:text-destructive"
                                style={{
                                    "left": str(l["mx"] - 10) + "px",
                                    "top": str(l["my"] - 10) + "px"
                                }}
                                onClick={lambda (e: MouseEvent) {
                                    e.stopPropagation();
                                    if onDeleteEdge { onDeleteEdge(l["from"], l["to"]); }
                                }}
                            >
                                ✕
                            </button>
                        }}
                    </div>
                }}

                {for s in grid {
                    <button
                        key={s.id}
                        type="button"
                        className={
                            "absolute z-10 rounded-lg px-3 py-2 text-left transition-shadow hover:shadow-md "
                            + (
                                "border-2 font-semibold text-sm "
                                    + SPINE_TINT[colorKey(s.color)]
                                if s.lane == 0
                                else "border text-xs " + BRANCH_TINT[colorKey(s.color)]
                            )
                            + (" opacity-70" if s.status == "Done" else "")
                            + (" ring-2 ring-ring" if selectedId == s.id else "")
                            + (
                                " ring-1 ring-emerald-500/40"
                                if s.ready and selectedId != s.id
                                else ""
                            )
                            + (
                                " opacity-30 pointer-events-none"
                                if connecting and s.id in blockedTargets
                                else ""
                            )
                            + (
                                " cursor-pointer ring-1 ring-primary/60"
                                if connecting and s.id not in blockedTargets
                                else ""
                            )
                        }
                        style={{
                            "left": str(centreX(s) - widthOf(s) / 2) + "px",
                            "top": str(topY(s)) + "px",
                            "width": str(widthOf(s)) + "px",
                            "height": str(NODE_H) + "px"
                        }}
                        onClick={lambda (e: MouseEvent) {
                            e.stopPropagation();
                            if onSelect { onSelect(s.id); }
                        }}
                    >
                        <div className="flex items-start gap-1.5">
                            <span
                                className={
                                    "mt-1 h-2 w-2 shrink-0 rounded-full "
                                    + DOT_FILL[colorKey(s.color)]
                                }
                            />
                            <span className="line-clamp-2 leading-snug">{s.title}</span>
                        </div>
                        <div className="mt-1 flex items-center gap-1.5 text-[11px] text-muted-foreground">
                            {if s.status == "Done" {
                                <span key="done" className="text-emerald-600">Done</span>
                            } else {
                                <span key="state">
                                    {
                                        "Ready" if s.ready
                                        else (
                                            "Waiting on " + str(s.blocked_by)
                                            if s.blocked_by > 0 else s.status
                                        )
                                    }
                                </span>
                            }}
                            {if s.task_count > 0 {
                                <span key="tasks">
                                    {"· " + str(s.done_count) + "/" + str(s.task_count)}
                                </span>
                            }}
                        </div>
                        {if s.task_count > 0 {
                            <div
                                key="bar"
                                className="absolute inset-x-0 bottom-0 h-0.5 overflow-hidden rounded-b-lg bg-border"
                            >
                                <div
                                    className={"h-full " + DOT_FILL[colorKey(s.color)]}
                                    style={{
                                        "width": str(s.done_count * 100 / s.task_count) + "%"
                                    }}
                                />
                            </div>
                        }}
                    </button>
                }}
            </div>
        </div>

        {if len(tray) > 0 {
            <div key="tray" className="rounded-lg border border-dashed bg-muted/20 p-3">
                <div className="mb-2 text-xs font-medium uppercase tracking-wide text-muted-foreground">
                    {"Not connected yet (" + str(len(tray)) + ")"}
                </div>
                <div className="flex flex-wrap gap-2">
                    {for s in tray {
                        <button
                            key={s.id}
                            type="button"
                            className={
                                "rounded-lg border px-2.5 py-1.5 text-xs transition-shadow hover:shadow-sm "
                                + BRANCH_TINT[colorKey(s.color)]
                                + (" ring-2 ring-ring" if selectedId == s.id else "")
                                + (
                                    " opacity-30 pointer-events-none"
                                    if connecting and s.id in blockedTargets
                                    else ""
                                )
                                + (
                                    " cursor-pointer ring-1 ring-primary/60"
                                    if connecting and s.id not in blockedTargets
                                    else ""
                                )
                            }
                            onClick={lambda (e: MouseEvent) {
                                e.stopPropagation();
                                if onSelect { onSelect(s.id); }
                            }}
                        >
                            {s.title}
                        </button>
                    }}
                </div>
                <p className="mt-2 text-xs text-muted-foreground">
                    These steps have no connections. Select one and use Connect to put
                    it on the roadmap.
                </p>
            </div>
        }}

        {if len(grid) == 0 and len(tray) == 0 {
            <div key="empty" className="rounded-lg border border-dashed p-8 text-center">
                <p className="text-sm font-medium">No steps on this roadmap yet.</p>
                <p className="mt-1 text-sm text-muted-foreground">
                    A step is a chunk of work. Add a few, then connect them to show what
                    has to happen before what.
                </p>
            </div>
        }}
    </div>;
}
