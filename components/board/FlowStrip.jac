"""The flow line as one rail for the task dialog: a pip per step in board
order, the lane colour under each, the task's step lit. Position, not history:
pips left of here are outlined, pips right of here fade, and only the current
step's send-backs are drawn, so the strip never turns into a graph."""

import from ...models { StepView }
import from ..flowlines.kinds { DOT_FILL, PIP_EDGE, colorKey }

# Rail geometry in px. The rail is 100% wide; pips sit at percentage stops,
# so the strip fits whatever width the dialog has.
glob STRIP_H: float = 62.0,
     PIP_Y: float = 24.0,
     NAME_Y: float = 47.0,
     BAR_Y: float = 56.0,
     # Past this many steps the names would collide, so only the current
     # step and its neighbours keep theirs (the rest have titles).
     NAME_LIMIT: int = 8;


def:pub FlowStrip(
    steps: list[StepView], currentKey: str = "", className: str = ""
) -> JsxElement {
    n = len(steps);
    herePos = -1;
    for (i, s) in enumerate(steps) {
        if s.id == currentKey {
            herePos = i;
        }
    }
    # Stop i sits at the centre of the i-th of n equal slots, as a percent.
    stops: list[float] = [];
    for (i, s) in enumerate(steps) {
        stops.append((float(i) + 0.5) * 100.0 / float(n) if n > 0 else 50.0);
    }
    showNames = n <= NAME_LIMIT;

    # The rail segments between neighbours. Walked (left of here) in the
    # foreground tone, ahead in the muted one.
    segs: list[dict[str, str]] = [];
    for (i, s) in enumerate(steps) {
        if i >= n - 1 {
            continue;
        }
        walked = herePos >= 0 and i < herePos;
        segs.append(
            {
                "key": "seg" + str(i),
                "x1": str(stops[i]) + "%",
                "x2": str(stops[i + 1]) + "%",
                "cls": "text-foreground/45" if walked else "text-border"
            }
        );
    }

    # Pips and their labels, materialised so the JSX only reads strings.
    pips: list[dict[str, str]] = [];
    for (i, s) in enumerate(steps) {
        tone = colorKey(s.color);
        isHere = i == herePos;
        before = herePos >= 0 and i < herePos;
        nameShown = showNames or isHere or i == herePos - 1 or i == herePos + 1;
        pips.append(
            {
                "key": s.id,
                "name": s.name,
                "x": str(stops[i]) + "%",
                "tone": tone,
                "pipCls": (
                    "h-3.5 w-3.5 ring-4 ring-primary/20 " + DOT_FILL[tone]
                        if isHere
                        else (
                            "h-2.5 w-2.5 border-2 bg-card " + (
                                PIP_EDGE[tone]
                                    if before
                                    else "border-muted-foreground/40 opacity-60"
                            )
                        )
                ),
                "nameCls": (
                    "font-semibold text-foreground"
                        if isHere
                        else (
                            "text-muted-foreground"
                                if before
                                else "text-muted-foreground/60"
                        )
                ),
                "showName": "y" if nameShown else "",
                "bar": DOT_FILL[tone]
            }
        );
    }

    # The send-backs that exist FROM the current step, as dashed arcs under
    # the rail back to the earlier step. Drawn in viewBox percent units so
    # they land on the stops regardless of width.
    arcs: list[dict[str, str]] = [];
    if herePos >= 0 {
        here = steps[herePos];
        for nid in here.next_ids {
            for (j, t) in enumerate(steps) {
                if t.id == nid and j < herePos {
                    x1 = stops[herePos];
                    x2 = stops[j];
                    # Depth scales with span so a long send-back dips lower.
                    dip = 6.0 + 2.0 * float(herePos - j);
                    arcs.append(
                        {
                            "key": "back" + str(j),
                            "d": (
                                "M " + str(x1) + " " + str(PIP_Y + 8.0) + " C " + str(
                                    x1
                                ) + " " + str(PIP_Y + 8.0 + dip) + ", " + str(x2) + " " + str(
                                    PIP_Y + 8.0 + dip
                                ) + ", " + str(x2) + " " + str(PIP_Y + 8.0)
                            ),
                            "title": here.name + " → " + t.name + " (send-back)"
                        }
                    );
                }
            }
        }
    }

    return
        <div
            className={"relative w-full overflow-hidden rounded-lg border bg-muted/30 " + className}
            style={{"height": str(STRIP_H) + "px"}}
        >
            <svg
                className="pointer-events-none absolute inset-0"
                width="100%"
                height="100%"
                viewBox={"0 0 100 " + str(STRIP_H)}
                preserveAspectRatio="none"
            >
                {for sg in segs {
                    <line
                        key={sg["key"]}
                        x1={sg["x1"]}
                        x2={sg["x2"]}
                        y1={PIP_Y}
                        y2={PIP_Y}
                        className={sg["cls"]}
                        stroke="currentColor"
                        strokeWidth={2}
                        vectorEffect="non-scaling-stroke"
                    />
                }}
                {for a in arcs {
                    <g key={a["key"]} className="text-destructive/70">
                        <title>{a["title"]}</title>
                        <path
                            d={a["d"]}
                            fill="none"
                            stroke="currentColor"
                            strokeWidth={1.5}
                            strokeDasharray="4 3"
                            vectorEffect="non-scaling-stroke"
                        />
                    </g>
                }}
            </svg>
            {for p in pips {
                <div
                    key={p["key"]}
                    className="absolute top-0 flex -translate-x-1/2 flex-col items-center"
                    style={{"left": p["x"], "width": str(100.0 / float(n)) + "%"}}
                    title={p["name"]}
                >
                    <span
                        className={"block rounded-full " + p["pipCls"]}
                        style={{"marginTop": str(PIP_Y - 7.0) + "px"}}
                    />
                </div>
            }}
            {for p in pips {
                <div
                    key={"n" + p["key"]}
                    className={"pointer-events-none absolute flex -translate-x-1/2 justify-center px-0.5 text-center text-[10.5px] leading-none " + p[
                        "nameCls"
                    ]}
                    style={{
                        "left": p["x"],
                        "top": str(NAME_Y - 5.0) + "px",
                        "width": str(100.0 / float(n)) + "%"
                    }}
                >
                    {if p["showName"] {
                        <span key="t" className="max-w-full truncate">{p["name"]}</span>
                    }}
                </div>
            }}
            {for p in pips {
                <span
                    key={"b" + p["key"]}
                    className={"absolute h-[3px] -translate-x-1/2 rounded-full " + p[
                        "bar"
                    ]}
                    style={{
                        "left": p["x"],
                        "top": str(BAR_Y) + "px",
                        "width": "calc(" + str(100.0 / float(n)) + "% - 14px)"
                    }}
                />
            }}
        </div>;
}
