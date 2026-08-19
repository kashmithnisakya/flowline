"""The flow line as a small swimlane picture for the task dialog: lane per
owner role, column per flow depth, the task's step lit. Same laneLayout as the
Lanes page, so the two agree on lanes and columns, but drawn at its own size
(percent columns, fixed rows) so names stay readable in a 700px dialog. A
name wraps to two lines before it truncates; the caption above carries the
current step's name in full."""

import from ...models { StepView, RoleView, MemberView }
import from ..flowlines.lanes {
    laneLayout,
    LANE_GUTTER,
    LANE_COL_W,
    LANE_PAD,
    LANE_NODE_H,
    LANE_ROW_GAP
}
import from ..flowlines.kinds { DOT_FILL, CARD_TINT, CARD_BAR, colorKey }

# Compact geometry in px: the lane label gutter, a card, a stacked row gap,
# and the band padding. Columns are percentages of what is left after the
# gutter, so the picture fits whatever width the dialog has.
glob MINI_GUTTER: float = 84.0,
     MINI_CARD_H: float = 26.0,
     MINI_ROW_GAP: float = 6.0,
     MINI_PAD: float = 8.0;


def:pub MiniLanes(
    steps: list[StepView],
    roles: list[RoleView],
    members: list[MemberView],
    currentKey: str = "",
    className: str = ""
) -> JsxElement {
    plan = laneLayout(steps, roles, members);
    positions: dict[str, list[float]] = plan["positions"];
    bands: list[dict[str, any]] = plan["lanes"];
    laneOf: dict[str, str] = plan["laneOf"];

    # Recover column, lane and row slot from the canvas-px layout: it is the
    # one source of truth for where a step sits, and this only re-sizes it.
    colOf: dict[str, int] = {};
    slotOf: dict[str, int] = {};
    rowsIn: dict[str, int] = {};
    nCols = 1;
    bandTop: dict[str, float] = {};
    for b in bands {
        bandTop[str(b["key"])] = float(b["y"]);
        rowsIn[str(b["key"])] = 1;
    }
    for s in steps {
        if s.id not in positions {
            continue;
        }
        pos = positions[s.id];
        col = int((pos[0] - LANE_GUTTER) / LANE_COL_W + 0.5);
        lane = laneOf[s.id];
        slot = int(
            (pos[1] - bandTop[lane] - LANE_PAD) / (LANE_NODE_H + LANE_ROW_GAP) + 0.5
        );
        colOf[s.id] = col;
        slotOf[s.id] = slot;
        if col + 1 > nCols {
            nCols = col + 1;
        }
        if slot + 1 > rowsIn[lane] {
            rowsIn[lane] = slot + 1;
        }
    }

    # Compact band stack, top to bottom in lane order.
    miniTop: dict[str, float] = {};
    miniH: dict[str, float] = {};
    total = 0.0;
    for b in bands {
        k = str(b["key"]);
        rows = rowsIn[k];
        h = MINI_PAD * 2.0 + float(rows) * MINI_CARD_H + float(rows - 1) * MINI_ROW_GAP;
        miniTop[k] = total;
        miniH[k] = h;
        total = total + h;
    }

    # Card geometry: left/width as CSS calc over the post-gutter width, top
    # in px. Materialised here; the JSX only reads strings.
    cards: list[dict[str, str]] = [];
    cy: dict[str, float] = {};
    for s in steps {
        if s.id not in colOf {
            continue;
        }
        col = colOf[s.id];
        lane = laneOf[s.id];
        top = miniTop[lane] + MINI_PAD + float(slotOf[s.id]) * (
            MINI_CARD_H + MINI_ROW_GAP
        );
        cy[s.id] = top + MINI_CARD_H / 2.0;
        isHere = s.id == currentKey;
        cards.append(
            {
                "id": s.id,
                "name": s.name,
                "left": "calc(" + str(MINI_GUTTER) + "px + (100% - " + str(
                    MINI_GUTTER
                ) + "px) * " + str(col) + " / " + str(nCols) + " + 3px)",
                "width": "calc((100% - " + str(MINI_GUTTER) + "px) / " + str(nCols) + " - 6px)",
                "top": str(top) + "px",
                "cls": CARD_BAR[colorKey(s.color)] + " " + (
                    "ring-2 ring-primary/70 shadow-sm " + CARD_TINT[colorKey(s.color)]
                        if isHere
                        else "border-border/70 bg-card/80 opacity-80"
                ),
                "nameCls": "font-semibold text-foreground"
                    if isHere
                    else "text-foreground/80"
            }
        );
    }

    # Wires in an SVG stretched over the card area: x in column units, y in
    # px, preserveAspectRatio none so both map straight onto the layout, and
    # non-scaling strokes so the lines do not thicken with the stretch.
    wires: list[dict[str, str]] = [];
    for s in steps {
        if s.id not in colOf {
            continue;
        }
        for nid in s.next_ids {
            if nid not in colOf {
                continue;
            }
            fc = float(colOf[s.id]);
            tc = float(colOf[nid]);
            fy = cy[s.id];
            ty = cy[nid];
            isBack = tc < fc or (tc == fc and ty < fy);
            d = "";
            if tc > fc {
                # Forward: leave the right edge, elbow in the gap, enter left.
                ex = fc + 0.96;
                ix = tc + 0.04;
                mx = fc + 1.0 - 0.015;
                d = (
                    "M " + str(ex) + " " + str(fy - 3.0) + " L " + str(mx) + " " + str(
                        fy - 3.0
                    ) + " L " + str(mx) + " " + str(ty - 3.0) + " L " + str(ix) + " " + str(
                        ty - 3.0
                    )
                );
            } elif tc < fc {
                # Send-back: leave the left edge, elbow on the other side of
                # the same gap so a two-way pair does not share a trunk.
                ex = fc + 0.04;
                ix = tc + 0.96;
                mx = fc + 0.015;
                d = (
                    "M " + str(ex) + " " + str(fy + 3.0) + " L " + str(mx) + " " + str(
                        fy + 3.0
                    ) + " L " + str(mx) + " " + str(ty + 3.0) + " L " + str(ix) + " " + str(
                        ty + 3.0
                    )
                );
            } else {
                # Stacked in one column: straight down (or up) the middle.
                x = fc + 0.5;
                sy = fy + MINI_CARD_H / 2.0 if ty > fy else fy - MINI_CARD_H / 2.0;
                ey = ty - MINI_CARD_H / 2.0 if ty > fy else ty + MINI_CARD_H / 2.0;
                d = "M " + str(x) + " " + str(sy) + " L " + str(x) + " " + str(ey);
            }
            touches = s.id == currentKey or nid == currentKey;
            wires.append(
                {
                    "key": s.id + ">" + nid,
                    "d": d,
                    "cls": (
                        "text-primary"
                            if touches
                            else (
                                "text-destructive/60"
                                    if isBack
                                    else "text-muted-foreground/50"
                            )
                    ),
                    "dash": "4 3" if isBack else "",
                    "w": "2" if touches else "1.5"
                }
            );
        }
    }

    # Lane bands and their labels, alternating tint, the current step's lane
    # lifted a shade so the eye lands on the right row first.
    rects: list[dict[str, str]] = [];
    hereLane = laneOf[currentKey] if currentKey in laneOf else "";
    for (i, b) in enumerate(bands) {
        k = str(b["key"]);
        rects.append(
            {
                "key": k,
                "top": str(miniTop[k]) + "px",
                "h": str(miniH[k]) + "px",
                "cls": "absolute inset-x-0" + (
                    " bg-primary/10"
                        if k == hereLane
                        else (" bg-foreground/[0.045]" if i % 2 == 1 else "")
                ) + ("" if i == 0 else " border-t border-border/60"),
                "label": str(b["label"]),
                "sub": str(b["sub"]),
                "subCls": "truncate text-[9.5px] leading-tight " + (
                    "text-warning" if b["warn"] else "text-muted-foreground"
                ),
                "dot": DOT_FILL[colorKey(str(b["color"]))],
                "labelCls": "truncate text-[11px] font-semibold leading-tight " + (
                    "text-foreground" if k == hereLane else "text-foreground/80"
                )
            }
        );
    }

    return
        <div
            className={"relative w-full overflow-hidden rounded-lg border bg-muted/30 " + className}
            style={{"height": str(total) + "px"}}
        >
            {for r in rects {
                <div
                    key={r["key"]}
                    className={r["cls"]}
                    style={{"top": r["top"], "height": r["h"]}}
                >
                    <div
                        className="absolute left-2 top-1/2 flex w-[4.75rem] -translate-y-1/2 flex-col"
                    >
                        <div className="flex items-center gap-1.5">
                            <span
                                className={"h-1.5 w-1.5 shrink-0 rounded-full " + r[
                                    "dot"
                                ]}
                            />
                            <span className={r["labelCls"]} title={r["label"]}>
                                {r["label"]}
                            </span>
                        </div>
                        {if r["sub"] {
                            <span
                                key="sub"
                                className={"pl-3 " + r["subCls"]}
                                title={r["sub"]}
                            >
                                {r["sub"]}
                            </span>
                        }}
                    </div>
                </div>
            }}
            <svg
                className="pointer-events-none absolute inset-y-0 right-0"
                style={{
                    "left": str(MINI_GUTTER) + "px",
                    "width": "calc(100% - " + str(MINI_GUTTER) + "px)"
                }}
                viewBox={"0 0 " + str(nCols) + " " + str(total)}
                preserveAspectRatio="none"
            >
                {for w in wires {
                    <path
                        key={w["key"]}
                        d={w["d"]}
                        className={w["cls"]}
                        fill="none"
                        stroke="currentColor"
                        strokeWidth={w["w"]}
                        strokeDasharray={w["dash"]}
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        vectorEffect="non-scaling-stroke"
                    />
                }}
            </svg>
            {for c in cards {
                <div
                    key={c["id"]}
                    className={"absolute flex items-center rounded-md border pl-1.5 pr-1 text-[10.5px] leading-[11px] " + c[
                        "cls"
                    ]}
                    style={{
                        "left": c["left"],
                        "width": c["width"],
                        "top": c["top"],
                        "height": str(MINI_CARD_H) + "px"
                    }}
                    title={c["name"]}
                >
                    <span className={"line-clamp-2 break-words " + c["nameCls"]}>
                        {c["name"]}
                    </span>
                </div>
            }}
        </div>;
}
