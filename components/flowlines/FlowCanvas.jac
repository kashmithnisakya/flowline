"""The flow line as a diagram: step nodes over SVG transitions, purely
presentational (positions, zoom and pan come in as data, every gesture is the
page's). Everything is laid out in screen px from canvas px times the zoom, so
text never shrinks: the zoom picks how much a node shows instead."""

import from "react" { useEffect }
import from ...models { StepView }
import from .geometry {
    NODE_H,
    CHIP_H,
    CHIP_PAD_X,
    detailOf,
    nodeRects,
    nodeTitles,
    link,
    cubicAt,
    cubicSamples,
    placeChips
}
import from .lanes { LANE_LABEL_W, laneRects, laneWires }
import from .kinds { DOT_FILL, CARRY_LABEL, colorKey, triggerNote }
import from .EdgeEditor { EdgeEditor }
import from .StepNode { StepNode }
import from ..ui.button { Button }

glob EDGE_EDITOR_H: float = 310.0,
     CHIP_FONT: str = "12px 'Geist Variable', Arial, sans-serif",
     NAME_FONT: str = "600 12.5px 'Geist Variable', Arial, sans-serif",
     META_FONT: str = "12px 'Geist Variable', Arial, sans-serif",
     COUNT_FONT: str = "12px 'Geist Mono Variable', Menlo, monospace",
     # Below this zoom the transitions keep their lines but drop their words:
     # at a whole-line overview the chips would bury the steps.
     CHIP_MIN_ZOOM: float = 0.45;

# Measured text widths, keyed by font and text. Cleared once web fonts load.
glob MEASURE: dict[str, any] = {"ctx": None, "cache": {}};


# Width of `text` in screen px for a CSS font shorthand. A canvas measures it;
# without one a per-character estimate stands in. Local to this component: a
# window-touching helper imported from another module is not exported.
def textWidth(text: str, font: str, perChar: float) -> float {
    key = font + "|" + text;
    cache: dict[str, float] = MEASURE["cache"];
    if key in cache {
        return cache[key];
    }
    width = float(len(text)) * perChar;
    w: any = window;
    if w and w.document {
        ctx: any = MEASURE["ctx"];
        if not ctx {
            cv: any = w.document.createElement("canvas");
            ctx = cv.getContext("2d");
            MEASURE["ctx"] = ctx;
        }
        if ctx {
            ctx.font = font;
            width = float(ctx.measureText(text).width);
        }
    }
    cache[key] = width;
    return width;
}


def clearMeasure {
    MEASURE["cache"] = {};
}


# Label anchors kept inside the source lane's band ([lo, hi] for a chip's
# centre). A trunk anchor ([5] and [6] its span, [7] its start) becomes spots
# along the part of the trunk inside the band: below or above the card row.
def bandAnchors(anchors: list[list[float]], lo: float, hi: float) -> list[list[float]] {
    out: list[list[float]] = [];
    for an in anchors {
        if lo >= hi or an[2] != 1.0 {
            out.append(an);
            continue;
        }
        if len(an) > 7 {
            a0 = an[5] if an[5] > lo else lo;
            a1 = an[6] if an[6] < hi else hi;
            if a0 <= a1 {
                far = a1 if an[6] > an[7] + 0.5 else a0;
                for y in [far, (far + an[7]) / 2.0, (a0 + a1) / 2.0] {
                    out.append([an[0], y, 1.0, 0.0, an[4]]);
                }
                continue;
            }
        }
        y = an[1];
        if y < lo {
            y = lo;
        }
        if y > hi {
            y = hi;
        }
        out.append([an[0], y, an[2], an[3], an[4]]);
    }
    return out;
}


# A drawn transition's stored fields, the edge editor's starting draft.
def edgeFields(l: dict[str, any]) -> dict[str, str] {
    return {
        "label": str(l["label"]),
        "carries": str(l["carries"]),
        "trigger": str(l["trigger"]),
        "trigger_label": str(l["trigger_label"])
    };
}


def:pub FlowCanvas(
    steps: list[StepView],
    live: dict[str, list[float]] = {},
    selectedId: str = "",
    connectFrom: str = "",
    selectedEdge: str = "",
    # The selected transition's draft: label, carries, trigger, trigger_label.
    edgeForm: dict[str, str] = {},
    zoom: float = 1.0,
    panX: float = 0.0,
    panY: float = 0.0,
    editing: bool = False,
    dragId: str = "",
    # Lane view bands from lanes.jac. Non-empty flips lane mode: elbow wires,
    # a fixed label column, and `live` holds the computed lane positions.
    lanes: list[dict[str, any]] = [],
    laneOf: dict[str, str] = {},
    # Column per step from the same plan, and the label gutter's screen width.
    laneCols: dict[str, int] = {},
    laneLabelW: float = LANE_LABEL_W,
    # First task titles per step, shown on nodes above the high-detail zoom.
    stepTitles: dict[str, list[str]] = {},
    canvasRef: Ref[any] = None,
    # Receives the drawn node rects and the drawing's extent (chips included),
    # so the page hit-tests and fits exactly what is on screen.
    layoutRef: Ref[any] = None,
    viewportRef: Ref[any] = None,
    onSelect: Callable[[str], None] = None,
    onSelectEdge: Callable[[str, dict[str, str]], None] = None,
    onEdgeField: Callable[[str, str], None] = None,
    onSaveEdge: Callable[[str, str, dict[str, str]], None] = None,
    onDeleteEdge: Callable[[str, str], None] = None,
    onCanvasClick: Callable[[], None] = None,
    onAddStep: Callable[[], None] = None
) -> JsxElement {
    # The lane whose label is under the pointer: its steps stay, the rest
    # fade, so one role's touchpoints read without a click.
    has hoverLane: str = "",
        fontTick: int = 0;

    # Widths are measured on a canvas; once the web fonts arrive, measure
    # again so chips fit their real text.
    useEffect(
        lambda {
            w: any = window;
            live_: any = {"on": True};
            if w.document and w.document.fonts {
                w.document.fonts.ready.then(
                    lambda { if live_["on"] {
                        clearMeasure();
                        fontTick = fontTick + 1;
                    }}
                );
            }
            return lambda { live_["on"] = False; };
        },
        []
    );

    byId: dict[str, StepView] = {};
    for s in steps {
        byId[s.id] = s;
    }
    laneMode = len(lanes) > 0;
    detail = detailOf(zoom);
    # What each node's text needs (StepNode's anatomy): padding (22) around
    # the pill (padding 20, glyph and gap 17, name); above LOW detail the
    # count chip beside it, and in flow mode room for the owner below.
    needLow: dict[str, float] = {};
    needMid: dict[str, float] = {};
    needLane: dict[str, float] = {};
    need: dict[str, float] = {};
    for s in steps {
        wantPill = 37.0 + textWidth(s.name, NAME_FONT, 7.6);
        countText = str(s.task_count) + (" done" if s.kind == "done" else " open");
        wantRow = wantPill + 8.0 + textWidth(countText, COUNT_FONT, 7.3) + 12.0;
        owner = s.owner.strip() if s.owner else "";
        wantOwner = textWidth("Anyone" if owner == "anyone" else owner, META_FONT, 6.6);
        needLow[s.id] = wantPill + 22.0;
        needLane[s.id] = wantRow + 22.0;
        needMid[s.id] = (wantOwner if wantOwner > wantRow else wantRow) + 22.0;
        if detail == "low" {
            need[s.id] = needLow[s.id];
        } else {
            need[s.id] = needLane[s.id] if laneMode else needMid[s.id];
        }
    }
    rects: dict[str, list[float]] = {};
    if laneMode {
        rects = laneRects(
            steps, live, laneCols, zoom, stepTitles, need, laneLabelW + 16.0
        )["rects"];
    } else {
        rects = nodeRects(steps, live, zoom, stepTitles, 0.0, NODE_H, need);
    }

    # The SVG covers the drawing; a little slack keeps arrowheads and chips
    # that sit past the last node inside it.
    svgW = 320.0;
    svgH = 240.0;
    obstacles: list[list[float]] = [];
    for s in steps {
        r = rects[s.id];
        if r[0] + r[2] + 240.0 > svgW {
            svgW = r[0] + r[2] + 240.0;
        }
        if r[1] + r[3] + 120.0 > svgH {
            svgH = r[1] + r[3] + 120.0;
        }
        obstacles.append([r[0] - 6.0, r[1] - 6.0, r[2] + 12.0, r[3] + 12.0]);
    }
    # The lane label column covers the left of the drawing at the fitted pan;
    # a chip placed under it would be hidden. It carries no 6px margin.
    if laneMode {
        obstacles.append([-100000.0, -100000.0, 100006.0 + laneLabelW, 200000.0]);
    }

    # The lane band each step sits in, in screen px, so a chip prefers the
    # band its wire leaves from.
    bandOf: dict[str, list[float]] = {};
    for ln in lanes {
        bandOf[str(ln["key"])] = [
            float(ln["y"]) * zoom + 4.0,
            (float(ln["y"]) + float(ln["h"])) * zoom - 4.0
        ];
    }

    links: list[dict[str, any]] = [];
    if laneMode {
        links = laneWires(steps, rects, 24.0, laneCols);
        for l in links {
            src = str(l["from"]);
            anchors: list[list[float]] = l["anchors"];
            if src in laneOf and laneOf[src] in bandOf {
                band = bandOf[laneOf[src]];
                l["band"] = band;
                lo = band[0] + CHIP_H / 2.0 + 2.0;
                hi = band[1] - CHIP_H / 2.0 - 2.0;
                l["anchors"] = bandAnchors(anchors, lo, hi);
            }
            l["mx"] = anchors[0][0] if len(anchors) > 0 else 0.0;
            l["my"] = anchors[0][1] if len(anchors) > 0 else 0.0;
        }
    } else {
        for s in steps {
            for (i, nid) in enumerate(s.next_ids) {
                if nid not in byId {
                    continue;
                }
                target = byId[nid];
                twoWay = s.id in target.next_ids;
                curve = link(rects[s.id], rects[nid], twoWay);
                pts: list[float] = curve["pts"];
                side = float(curve["side"]);
                # +1 is above a flat stretch of wire and right of a steep
                # one. A one-way chip prefers that side; a two-way pair takes
                # the side its own curve was parted to, so the two labels
                # land on opposite sides.
                pref = 1.0;
                if twoWay {
                    pref = 0.0 - side if curve["horizontal"] else side;
                }
                anchors: list[list[float]] = [];
                for t in [0.5, 0.4, 0.6, 0.3, 0.7, 0.2, 0.8] {
                    at = cubicAt(pts, t);
                    anx = at[2] if at[2] >= 0.0 else 0.0 - at[2];
                    any_ = at[3] if at[3] >= 0.0 else 0.0 - at[3];
                    anchors.append([at[0], at[1], anx, any_, pref]);
                }
                mid = cubicAt(pts, 0.5);
                links.append(
                    {
                        "key": s.id + ">" + nid,
                        "from": s.id,
                        "to": nid,
                        "d": curve["d"],
                        "arrow": curve["arrow"],
                        "anchors": anchors,
                        "samples": cubicSamples(pts),
                        "mx": mid[0],
                        "my": mid[1],
                        "back": target.sort_order < s.sort_order,
                        "label": s.next_labels[i] if i < len(s.next_labels) else "",
                        "carries": s.next_carries[i] if i < len(s.next_carries) else "",
                        "trigger": s.next_triggers[i]
                            if i < len(s.next_triggers)
                            else "",
                        "trigger_label": s.next_trigger_labels[i]
                            if i < len(s.next_trigger_labels)
                            else ""
                    }
                );
            }
        }
    }

    # Chip text and width, then one placement pass over every chip.
    showChips = zoom >= CHIP_MIN_ZOOM;
    for l in links {
        carried = str(l["carries"]);
        said = str(l["label"]);
        tag = CARRY_LABEL[carried] if carried in CARRY_LABEL else "";
        # A transition that moves work on its own says so after its words.
        auto = " · auto" if l["trigger"] else "";
        text = tag + (" · " if tag and said else "") + said + auto;
        l["tag"] = tag;
        l["auto"] = auto;
        l["note"] = triggerNote(str(l["trigger"]), str(l["trigger_label"]));
        l["text"] = text if showChips and selectedEdge != l["key"] else "";
        l["cw"] = textWidth(text, CHIP_FONT, 6.2) + CHIP_PAD_X * 2.0 + 1.0
            if text
            else 0.0;
        l["lit"] = bool(selectedId)
            and (l["from"] == selectedId or l["to"] == selectedId);
        l["cx"] = -9999.0;
        l["cy"] = -9999.0;
    }
    placeChips(links, obstacles);
    if layoutRef {
        ex0 = 0.0;
        ey0 = 0.0;
        ex1 = 0.0;
        ey1 = 0.0;
        nx0 = 0.0;
        ny0 = 0.0;
        nx1 = 0.0;
        ny1 = 0.0;
        firstRect = True;
        for s in steps {
            r = rects[s.id];
            if firstRect or r[0] < nx0 {
                nx0 = r[0];
            }
            if firstRect or r[1] < ny0 {
                ny0 = r[1];
            }
            if firstRect or r[0] + r[2] > nx1 {
                nx1 = r[0] + r[2];
            }
            if firstRect or r[1] + r[3] > ny1 {
                ny1 = r[1] + r[3];
            }
            firstRect = False;
        }
        ex0 = nx0;
        ey0 = ny0;
        ex1 = nx1;
        ey1 = ny1;
        for l in links {
            if l["text"] and float(l["cx"]) > -9000.0 {
                half = float(l["cw"]) / 2.0;
                if float(l["cx"]) - half < ex0 {
                    ex0 = float(l["cx"]) - half;
                }
                if float(l["cx"]) + half > ex1 {
                    ex1 = float(l["cx"]) + half;
                }
                if float(l["cy"]) - CHIP_H / 2.0 < ey0 {
                    ey0 = float(l["cy"]) - CHIP_H / 2.0;
                }
                if float(l["cy"]) + CHIP_H / 2.0 > ey1 {
                    ey1 = float(l["cy"]) + CHIP_H / 2.0;
                }
            }
        }
        layoutRef.current = {
            "rects": rects,
            "need": need,
            "needLow": needLow,
            "needMid": needMid,
            "needLane": needLane,
            "zoom": zoom,
            "nodes": [nx0, ny0, nx1, ny1],
            "extent": [ex0, ey0, ex1, ey1]
        };
    }

    def dimStep(sid: str) -> bool {
        if not hoverLane or sid == selectedId {
            return False;
        }
        return (laneOf[sid] if sid in laneOf else "") != hoverLane;
    }

    # The selected transition, so its label editor can be drawn over the
    # canvas. Tracked with a bool: len() on a dict is undefined in JS.
    activeEdge: dict[str, any] = {};
    activeFound = False;
    for l in links {
        if l["key"] == selectedEdge {
            activeEdge = l;
            activeFound = True;
        }
    }
    edgeFromName = "";
    edgeToName = "";
    edgeHad = False;
    # The editor opens below the arrow, lifted as far as it must be to stay
    # inside the viewport: the canvas clips what overflows, Save included.
    edgeTop = 0.0;
    if activeFound {
        edgeTop = float(activeEdge["my"]) + panY + 14.0;
        pane: any = viewportRef.current if viewportRef else None;
        paneH = float(pane.clientHeight) if pane else 0.0;
        if paneH > 0.0 and edgeTop + EDGE_EDITOR_H > paneH {
            edgeTop = paneH - EDGE_EDITOR_H - 8.0;
        }
        if edgeTop < 8.0 {
            edgeTop = 8.0;
        }
        edgeFromName = byId[activeEdge["from"]].name;
        edgeToName = byId[activeEdge["to"]].name;
        edgeHad = bool(
            activeEdge["label"] or activeEdge["carries"] or activeEdge["trigger"]
        );
    }
    connecting = bool(connectFrom);

    # Lane bands and labels in viewport px: the bands follow the pan, the
    # label column stays pinned to the left edge.
    laneRows: list[dict[str, any]] = [];
    for (i, ln) in enumerate(lanes) {
        lk = str(ln["key"]);
        top = float(ln["y"]) * zoom + panY;
        hgt = float(ln["h"]) * zoom;
        laneRows.append(
            {
                "key": "lane-" + lk,
                "lane": lk,
                "top": str(top) + "px",
                "h": str(hgt) + "px",
                "first": i == 0,
                "label": str(ln["label"]),
                "short": str(ln["short"]) if "short" in ln else str(ln["sub"]),
                "sub": str(ln["sub"]),
                "warn": bool(ln["warn"]),
                "totals": str(ln["totals"]),
                "manage": bool(ln["manage"]),
                "dot": DOT_FILL[colorKey(str(ln["color"]))],
                "rows": 3 if hgt >= 66.0 else (2 if hgt >= 46.0 else 1),
                "hover": hoverLane == lk
            }
        );
    }
    labelLeft = panX if panX > 0.0 else 0.0;

    return
        <div
            ref={viewportRef}
            data-canvas="flow"
            className={"relative h-full w-full touch-none select-none overflow-hidden bg-background"
                + (
                    " outline-2 -outline-offset-2 outline-primary/30"
                        if editing
                        else " cursor-grab active:cursor-grabbing"
                )}
            onClick={lambda { if onCanvasClick { onCanvasClick(); }}}
        >
            {for lr in laneRows {
                <div
                    key={lr["key"]}
                    className={"pointer-events-none absolute inset-x-0"
                        + ("" if lr["first"] else " border-t border-border")}
                    style={{"top": lr["top"], "height": lr["h"]}}
                />
            }}
            <div
                ref={canvasRef}
                className="absolute left-0 top-0 z-10"
                style={{
                    "transform": "translate(" + str(panX) + "px, " + str(panY) + "px)"
                }}
            >
                <svg
                    width={svgW}
                    height={svgH}
                    className="absolute left-0 top-0 overflow-visible"
                    style={{"pointerEvents": "none"}}
                    aria-hidden="true"
                >
                    {for l in links {
                        <g
                            key={l["key"]}
                            data-wire={l["key"]}
                            className={(
                                "text-primary"
                                    if selectedEdge == l["key"]
                                    else (
                                        "text-foreground" if l["lit"] else "text-wire"
                                    )
                            )
                                + (
                                    " opacity-30"
                                        if dimStep(l["from"]) and dimStep(l["to"])
                                        else ""
                                )}
                        >
                            <path
                                d={l["d"]}
                                fill="none"
                                stroke="currentColor"
                                strokeWidth={2.2
                                    if selectedEdge == l["key"] or l["lit"]
                                    else 1.6}
                                strokeLinecap="round"
                                strokeLinejoin="round"
                                strokeDasharray={"5 4" if l["back"] else ""}
                            />
                            <path d={l["arrow"]} fill="currentColor" stroke="none"/>
                            {if editing and onSelectEdge {
                                <path
                                    key="hit"
                                    d={l["d"]}
                                    fill="none"
                                    stroke="transparent"
                                    strokeWidth={14}
                                    style={{
                                        "pointerEvents": "stroke",
                                        "cursor": "pointer"
                                    }}
                                    onClick={lambda (e: MouseEvent) {
                                        e.stopPropagation();
                                        onSelectEdge(l["key"], edgeFields(l));
                                    }}
                                />
                            }}
                        </g>
                    }}
                </svg>
                {for l in links {
                    <div key={"chip-" + l["key"]}>
                        {if l["text"] and float(l["cx"]) > -9000.0 {
                            <span
                                key="lab"
                                data-chip="label"
                                data-for={l["key"]}
                                className={"absolute whitespace-nowrap rounded-sm bg-background text-xs leading-5"
                                    + (
                                        " cursor-pointer hover:text-foreground"
                                            if editing
                                            else " pointer-events-none"
                                    )
                                    + (
                                        " text-foreground"
                                            if l["lit"]
                                            else " text-muted-foreground"
                                    )
                                    + (
                                        " opacity-30"
                                            if dimStep(l["from"]) and dimStep(l["to"])
                                            else ""
                                    )}
                                style={{
                                    "left": str(float(l["cx"]) - float(l["cw"]) / 2.0)
                                        + "px",
                                    "top": str(float(l["cy"]) - CHIP_H / 2.0) + "px",
                                    "width": str(l["cw"]) + "px",
                                    "height": str(CHIP_H) + "px",
                                    "paddingLeft": str(CHIP_PAD_X) + "px"
                                }}
                                onClick={lambda (e: MouseEvent) { if editing
                                    and onSelectEdge {
                                    e.stopPropagation();
                                    onSelectEdge(l["key"], edgeFields(l));
                                }}}
                            >
                                {if l["tag"] {
                                    <span key="tag" className="text-subtle">
                                        {l["tag"] + (" · " if l["label"] else "")}
                                    </span>
                                }}
                                {l["label"]}
                                {if l["auto"] {
                                    <span
                                        key="auto"
                                        className="text-primary"
                                        title={l["note"]}
                                    >
                                        {l["auto"]}
                                    </span>
                                }}
                            </span>
                        }}
                        {if selectedEdge == l["key"] {
                            <span
                                key="dot"
                                className="pointer-events-none absolute block size-2 -translate-x-1/2 -translate-y-1/2 rounded-full bg-primary"
                                style={{
                                    "left": str(l["mx"]) + "px",
                                    "top": str(l["my"]) + "px"
                                }}
                            />
                        }}
                    </div>
                }}
                {for s in steps {
                    <StepNode
                        key={s.id}
                        step={s}
                        rect={rects[s.id]}
                        detail={detail}
                        titles={nodeTitles(s, stepTitles)}
                        showTitles={detail == "high" and s.id in stepTitles}
                        showOwner={not laneMode}
                        selected={selectedId == s.id or connectFrom == s.id}
                        portsOn={selectedId == s.id}
                        target={connecting and s.id != connectFrom}
                        editing={editing}
                        dragging={dragId == s.id}
                        dim={dimStep(s.id)}
                        onSelect={onSelect}
                    />
                }}
            </div>
            {if laneMode {
                <div
                    key="lanelabels"
                    className="absolute inset-y-0 z-30 border-r bg-background"
                    style={{
                        "left": str(labelLeft) + "px",
                        "width": str(laneLabelW) + "px"
                    }}
                    onClick={lambda (e: MouseEvent) { e.stopPropagation(); }}
                    onPointerDown={lambda (e: any) { e.stopPropagation(); }}
                >
                    {for lr in laneRows {
                        <div
                            key={lr["key"]}
                            className={"absolute inset-x-0 flex flex-col justify-center overflow-hidden px-4"
                                + ("" if lr["first"] else " border-t border-border")
                                + (" bg-accent" if lr["hover"] else "")}
                            style={{"top": lr["top"], "height": lr["h"]}}
                            onMouseEnter={lambda { hoverLane = lr["lane"]; }}
                            onMouseLeave={lambda { hoverLane = ""; }}
                        >
                            {if lr["manage"] {
                                <a
                                    key="name-link"
                                    href="/workspace?tab=roles"
                                    title="Manage roles in Workspace"
                                    className="flex min-w-0 items-center gap-1.5 text-sm leading-5 font-semibold text-foreground no-underline underline-offset-2 hover:underline"
                                >
                                    <span className={"step-swatch " + lr["dot"]}/>
                                    <span className="truncate">{lr["label"]}</span>
                                </a>
                            } else {
                                <div
                                    key="name"
                                    className="flex min-w-0 items-center gap-1.5 text-sm leading-5 font-semibold"
                                >
                                    <span className={"step-swatch " + lr["dot"]}/>
                                    <span className="truncate">{lr["label"]}</span>
                                </div>
                            } }
                            {if lr["rows"] >= 2 and lr["short"] {
                                <div
                                    key="sub"
                                    className={"truncate pl-4 text-xs leading-[18px] "
                                        + (
                                            "text-warning"
                                                if lr["warn"]
                                                else "text-muted-foreground"
                                        )}
                                    title={lr["sub"]}
                                >
                                    {lr["short"]}
                                </div>
                            }}
                            {if lr["rows"] >= 3 and laneLabelW >= LANE_LABEL_W {
                                <div
                                    key="totals"
                                    className={"num truncate pl-4 text-xs leading-[18px] "
                                        + (
                                            "text-muted-foreground"
                                                if lr["hover"]
                                                else "text-subtle"
                                        )}
                                >
                                    {lr["totals"]}
                                </div>
                            }}
                        </div>
                    }}
                </div>
            }}
            {if len(steps) == 0 {
                <div
                    key="empty"
                    className="pointer-events-none absolute inset-0 z-30 flex items-center justify-center p-4"
                >
                    <div
                        className="flex max-w-sm flex-col items-center gap-1 rounded-2xl border border-dashed bg-card px-8 py-10 text-center"
                    >
                        <p className="text-sm font-semibold">A blank canvas</p>
                        <p className="text-sm text-muted-foreground">
                            Add a step, then drag from its edge to another step to draw how work moves.
                        </p>
                        {if onAddStep {
                            <Button
                                key="cta"
                                size="sm"
                                className="pointer-events-auto mt-3"
                                onClick={lambda (e: MouseEvent) {
                                    e.stopPropagation();
                                    onAddStep();
                                }}
                            >
                                Add your first step
                            </Button>
                        }}
                    </div>
                </div>
            }}
            {if activeFound {
                <EdgeEditor
                    key="edgeeditor"
                    fromName={edgeFromName}
                    toName={edgeToName}
                    form={edgeForm}
                    left={float(activeEdge["mx"]) + panX}
                    top={edgeTop}
                    clearable={edgeHad}
                    onField={onEdgeField}
                    onSave={lambda { if onSaveEdge {
                        onSaveEdge(activeEdge["from"], activeEdge["to"], edgeForm);
                    }}}
                    onClear={lambda { if onSaveEdge {
                        onSaveEdge(activeEdge["from"], activeEdge["to"], {});
                    }}}
                    onDelete={lambda { if onDeleteEdge {
                        onDeleteEdge(activeEdge["from"], activeEdge["to"]);
                    }}}
                />
            }}
        </div>;
}
