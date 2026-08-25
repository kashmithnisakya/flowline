"""The flow line as a small swimlane picture for the task dialog: lane per
owner role, column per flow depth, the task's step lit. Same laneLayout as the
Lanes page, so the two agree on lanes and columns, but drawn at its own size
(percent columns, fixed rows) so names stay readable in a 700px dialog. A name
wraps to two lines before it truncates; the caption above carries the current
step's name in full."""

import from ...models { StepView, RoleView, MemberView }
import from ..flowlines.lanes { laneLayout }
import from ..flowlines.kinds { DOT_FILL, CARD_TINT, CARD_BAR, colorKey }

# Compact geometry in px: the lane label gutter, a card, a stacked row gap,
# the band padding, and how far a wire's port sits from the card's middle so
# a two-way pair reads as two wires. Columns are percentages of what is left
# after the gutter, so the picture fits whatever width the dialog has.
glob MINI_GUTTER: float = 84.0,
     MINI_CARD_H: float = 24.0,
     MINI_ROW_GAP: float = 6.0,
     MINI_PAD: float = 6.0,
     MINI_PORT: float = 4.0,
     # Card inset inside its column, as a fraction of the column: the wire
     # maths and the CSS calc below must agree on where a card's edge is.
     MINI_INSET: float = 0.04;


def:pub MiniLanes(
    steps: list[StepView],
    roles: list[RoleView],
    members: list[MemberView],
    currentKey: str = "",
    className: str = ""
) -> JsxElement {
    plan = laneLayout(steps, roles, members);
    bands: list[dict[str, any]] = plan["lanes"];
    laneOf: dict[str, str] = plan["laneOf"];
    colOf: dict[str, int] = plan["colOf"];
    slotOf: dict[str, int] = plan["slotOf"];
    nCols: int = plan["cols"];
    if nCols < 1 {
        nCols = 1;
    }

    # Rows per lane, then the compact band stack top to bottom.
    rowsIn: dict[str, int] = {};
    for b in bands {
        rowsIn[str(b["key"])] = 1;
    }
    for s in steps {
        if s.id in slotOf and slotOf[s.id] + 1 > rowsIn[laneOf[s.id]] {
            rowsIn[laneOf[s.id]] = slotOf[s.id] + 1;
        }
    }
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

    # Which lane is the task's, and which steps are one hop from it: those
    # stay readable, everything further back steps into the background so
    # the eye lands on the task's step and what it can move to.
    hereLane = laneOf[currentKey] if currentKey in laneOf else "";
    near: dict[str, bool] = {};
    for s in steps {
        if s.id == currentKey {
            for nid in s.next_ids {
                near[nid] = True;
            }
            for pid in s.prev_ids {
                near[pid] = True;
            }
        }
    }

    # Card geometry: left/width as CSS calc over the post-gutter width, top
    # in px. Materialised here; the JSX only reads strings.
    cards: list[dict[str, str]] = [];
    cy: dict[str, float] = {};
    colPct = "((100% - " + str(MINI_GUTTER) + "px) / " + str(nCols) + ")";
    for s in steps {
        if s.id not in colOf {
            continue;
        }
        col = colOf[s.id];
        lane = laneOf[s.id];
        top = miniTop[lane]
            + MINI_PAD
            + float(slotOf[s.id]) * (MINI_CARD_H + MINI_ROW_GAP);
        cy[s.id] = top + MINI_CARD_H / 2.0;
        isHere = s.id == currentKey;
        isNear = s.id in near;
        cards.append(
            {
                "id": s.id,
                "name": s.name,
                "left": "calc("
                    + str(MINI_GUTTER)
                    + "px + "
                    + colPct
                    + " * ("
                    + str(col)
                    + " + "
                    + str(MINI_INSET)
                    + "))",
                "width": "calc(" + colPct + " * " + str(1.0 - MINI_INSET * 2.0) + ")",
                "top": str(top) + "px",
                "cls": CARD_BAR[colorKey(s.color)]
                    + " "
                    + (
                        "z-10 ring-2 ring-primary/70 shadow-sm "
                            + CARD_TINT[colorKey(s.color)]
                            if isHere
                            else (
                                "border-border bg-card"
                                    if isNear
                                    else "border-border/60 bg-card/70 opacity-60"
                            )
                    ),
                "nameCls": "font-semibold text-foreground"
                    if isHere
                    else "text-foreground/85"
            }
        );
    }

    # Wires in an SVG stretched over the card area: x in column units, y in
    # px, preserveAspectRatio none so both map straight onto the layout, and
    # non-scaling strokes so the lines do not thicken with the stretch. The
    # arrowheads are HTML triangles placed with the same calc as the cards,
    # because a stretched SVG would squash them.
    wires: list[dict[str, str]] = [];
    heads: list[dict[str, str]] = [];
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
            twoWay = False;
            for t in steps {
                if t.id == nid and s.id in t.next_ids {
                    twoWay = True;
                }
            }
            isBack = tc < fc or (tc == fc and ty < fy);
            touches = s.id == currentKey or nid == currentKey;
            # A two-way pair parts vertically: the forward wire rides above
            # the card's middle, the send-back below.
            off = 0.0;
            if twoWay {
                off = MINI_PORT if isBack else 0.0 - MINI_PORT;
            }
            d = "";
            headLeft = "";
            headTop = 0.0;
            headDir = "";
            if tc > fc {
                # Forward: leave the right edge, elbow in the gap, enter left.
                ex = fc + 1.0 - MINI_INSET;
                ix = tc + MINI_INSET;
                mx = fc + 1.0 - (0.012 if twoWay else 0.0);
                d = (
                    "M "
                    + str(ex)
                    + " "
                    + str(fy + off)
                    + " L "
                    + str(mx)
                    + " "
                    + str(fy + off)
                    + " L "
                    + str(mx)
                    + " "
                    + str(ty + off)
                    + " L "
                    + str(ix)
                    + " "
                    + str(ty + off)
                );
                headLeft = "calc("
                    + str(MINI_GUTTER)
                    + "px + "
                    + colPct
                    + " * "
                    + str(ix)
                    + " - 5px)";
                headTop = ty + off;
                headDir = "r";
            } elif tc < fc {
                # Send-back: leave the left edge, elbow on the near side of
                # the gap so the pair does not share a trunk, enter the right.
                ex = fc + MINI_INSET;
                ix = tc + 1.0 - MINI_INSET;
                mx = fc + (0.012 if twoWay else 0.0);
                d = (
                    "M "
                    + str(ex)
                    + " "
                    + str(fy + off)
                    + " L "
                    + str(mx)
                    + " "
                    + str(fy + off)
                    + " L "
                    + str(mx)
                    + " "
                    + str(ty + off)
                    + " L "
                    + str(ix)
                    + " "
                    + str(ty + off)
                );
                headLeft = "calc("
                    + str(MINI_GUTTER)
                    + "px + "
                    + colPct
                    + " * "
                    + str(ix)
                    + ")";
                headTop = ty + off;
                headDir = "l";
            } else {
                # Stacked in one column: straight down (or up) the middle.
                x = fc + 0.5;
                down = ty > fy;
                sy = fy + MINI_CARD_H / 2.0 if down else fy - MINI_CARD_H / 2.0;
                ey = ty - MINI_CARD_H / 2.0 if down else ty + MINI_CARD_H / 2.0;
                d = "M " + str(x) + " " + str(sy) + " L " + str(x) + " " + str(ey);
                headLeft = "calc("
                    + str(MINI_GUTTER)
                    + "px + "
                    + colPct
                    + " * "
                    + str(x)
                    + " - 4px)";
                headTop = ey - 5.0 if down else ey;
                headDir = "d" if down else "u";
            }
            tone = (
                "text-primary"
                    if touches
                    else (
                        "text-destructive/55" if isBack else "text-muted-foreground/45"
                    )
            );
            wires.append(
                {
                    "key": s.id + ">" + nid,
                    "d": d,
                    "cls": tone,
                    "dash": "4 3" if isBack else "",
                    "w": "2" if touches else "1.5"
                }
            );
            heads.append(
                {
                    "key": "h" + s.id + ">" + nid,
                    "left": headLeft,
                    "top": str(headTop - 4.0) + "px",
                    "cls": tone
                        + " "
                        + (
                            "border-y-4 border-l-[5px] border-y-transparent border-l-current"
                                if headDir == "r"
                                else (
                                    "border-y-4 border-r-[5px] border-y-transparent border-r-current"
                                        if headDir == "l"
                                        else (
                                            "border-x-4 border-t-[5px] border-x-transparent border-t-current"
                                                if headDir == "d"
                                                else "border-x-4 border-b-[5px] border-x-transparent border-b-current"
                                        )
                                )
                        )
                }
            );
        }
    }

    # Lane bands and their labels, alternating tint, the task's lane lifted
    # a shade so the eye lands on the right row first.
    rects: list[dict[str, str]] = [];
    for (i, b) in enumerate(bands) {
        k = str(b["key"]);
        isHereLane = k == hereLane;
        rects.append(
            {
                "key": k,
                "top": str(miniTop[k]) + "px",
                "h": str(miniH[k]) + "px",
                "cls": "absolute inset-x-0"
                    + (
                        " bg-primary/10"
                            if isHereLane
                            else (" bg-foreground/[0.045]" if i % 2 == 1 else "")
                    )
                    + ("" if i == 0 else " border-t border-border/60"),
                "label": str(b["label"]),
                "sub": str(b["sub"]),
                "subCls": "truncate text-[9.5px] leading-tight "
                    + ("text-warning" if b["warn"] else "text-muted-foreground"),
                "dot": DOT_FILL[colorKey(str(b["color"]))],
                "labelCls": "truncate text-[11px] font-semibold leading-tight "
                    + ("text-foreground" if isHereLane else "text-foreground/75")
            }
        );
    }

    return
        <div
            className={"relative w-full overflow-hidden rounded-lg border bg-muted/30 "
                + className}
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
                                className={"h-1.5 w-1.5 shrink-0 rounded-full "
                                    + r["dot"]}
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
            {for hd in heads {
                <span
                    key={hd["key"]}
                    className={"pointer-events-none absolute h-0 w-0 " + hd["cls"]}
                    style={{"left": hd["left"], "top": hd["top"]}}
                />
            }}
            {for c in cards {
                <div
                    key={c["id"]}
                    className={"absolute flex items-center rounded-md border pl-1.5 pr-1 text-[10.5px] leading-[11px] "
                        + c["cls"]}
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
