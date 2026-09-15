"""The flow line as a diagram: step nodes over SVG transitions, purely
presentational (positions, zoom and pan come in as data, every gesture is the
page's). Everything is laid out in screen px from canvas px times the zoom, so
text never shrinks: the zoom picks how much a node shows instead."""

import from "react" { useEffect }
import from ...models { StepView }
import from .geometry {
    NODE_W,
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
import from .lanes { LANE_NODE_H, LANE_GUTTER, LANE_COL_W, LANE_LABEL_W, laneWires }
import from .kinds { KIND_LABEL, KIND_TONE, DOT_FILL, CARRY_LABEL, colorKey }
import from ..common.KindGlyph { KindGlyph }
import from ..ui.button { Button }
import from ..ui.input { Input }

glob CHIP_FONT: str = "12px 'Archivo Variable', Arial, sans-serif",
     NAME_FONT: str = "600 14px 'Archivo Variable', Arial, sans-serif",
     META_FONT: str = "12px 'Archivo Variable', Arial, sans-serif",
     COUNT_FONT: str = "12px 'IBM Plex Mono', Menlo, monospace",
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


def:pub FlowCanvas(
    steps: list[StepView],
    live: dict[str, list[float]] = {},
    selectedId: str = "",
    connectFrom: str = "",
    selectedEdge: str = "",
    edgeDraft: str = "",
    edgeCarry: str = "",
    zoom: float = 1.0,
    panX: float = 0.0,
    panY: float = 0.0,
    editing: bool = False,
    dragId: str = "",
    # Lane view bands from lanes.jac. Non-empty flips lane mode: elbow wires,
    # a fixed label column, and `live` holds the computed lane positions.
    lanes: list[dict[str, any]] = [],
    laneOf: dict[str, str] = {},
    # First task titles per step, shown on nodes above the high-detail zoom.
    stepTitles: dict[str, list[str]] = {},
    canvasRef: Ref[any] = None,
    # Receives the drawn node rects and the drawing's extent (chips included),
    # so the page hit-tests and fits exactly what is on screen.
    layoutRef: Ref[any] = None,
    viewportRef: Ref[any] = None,
    onSelect: Callable[[str], None] = None,
    onSelectEdge: Callable[[str, str, str], None] = None,
    onEdgeDraft: Callable[[str], None] = None,
    onEdgeCarry: Callable[[str], None] = None,
    onSaveEdgeLabel: Callable[[str, str, str, str], None] = None,
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
    footH = LANE_NODE_H if laneMode else NODE_H;
    ox = LANE_LABEL_W + 16.0 - LANE_GUTTER * zoom if laneMode else 0.0;
    # What each node's text needs at this detail: border and padding (20),
    # swatch and gap (16) beside the name, count, kind word and glyph below.
    need: dict[str, float] = {};
    metaNeed: dict[str, float] = {};
    for s in steps {
        wantName = 16.0 + textWidth(s.name, NAME_FONT, 8.0);
        kindWord = KIND_LABEL[s.kind] if s.kind in KIND_LABEL else s.kind;
        countText = str(s.task_count) + (" task" if s.task_count == 1 else " tasks");
        wantMeta = textWidth(countText, COUNT_FONT, 7.3)
            + 8.0
            + textWidth(kindWord, META_FONT, 6.6)
            + 18.0;
        metaNeed[s.id] = wantMeta + 22.0;
        want = wantName;
        if detail != "low" and wantMeta > want {
            want = wantMeta;
        }
        need[s.id] = want + 22.0;
    }
    rects = nodeRects(steps, live, zoom, stepTitles, ox, footH, need);

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
        colGap = LANE_COL_W * zoom - (NODE_W * zoom if NODE_W * zoom > 88.0 else 88.0);
        links = laneWires(steps, rects, colGap);
        for l in links {
            src = str(l["from"]);
            anchors: list[list[float]] = l["anchors"];
            if src in laneOf and laneOf[src] in bandOf {
                band = bandOf[laneOf[src]];
                l["band"] = band;
                # A trunk leaves its source row inside the source band, so
                # sliding its anchor into that band keeps it on the wire.
                lo = band[0] + CHIP_H / 2.0 + 2.0;
                hi = band[1] - CHIP_H / 2.0 - 2.0;
                for an in anchors {
                    if an[2] == 1.0 and lo < hi {
                        if an[1] < lo {
                            an[1] = lo;
                        }
                        if an[1] > hi {
                            an[1] = hi;
                        }
                    }
                }
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
                        "carries": s.next_carries[i] if i < len(s.next_carries) else ""
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
        text = tag + (" · " if tag and said else "") + said;
        l["tag"] = tag;
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
    edgeSaid = "";
    edgeHad = "";
    if activeFound {
        edgeFromName = byId[activeEdge["from"]].name;
        edgeToName = byId[activeEdge["to"]].name;
        edgeSaid = activeEdge["label"];
        edgeHad = str(activeEdge["carries"]);
    }
    carryPicks: list[dict[str, str]] = [
        {"key": "", "text": "None"},
        {"key": "issue", "text": "Issue"},
        {"key": "pr", "text": "PR"}
    ];
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
                                        onSelectEdge(
                                            l["key"], l["label"], str(l["carries"])
                                        );
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
                                    onSelectEdge(
                                        l["key"], l["label"], str(l["carries"])
                                    );
                                }}}
                            >
                                {if l["tag"] {
                                    <span key="tag" className="text-subtle">
                                        {l["tag"] + (" · " if l["label"] else "")}
                                    </span>
                                }}
                                {l["label"]}
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
                    <button
                        key={s.id}
                        type="button"
                        data-step={s.id}
                        title={s.name + (" · " + s.blurb if s.blurb else "")}
                        className={"group absolute flex flex-col overflow-hidden rounded-md border bg-card px-[9px] py-[7px] text-left transition-[border-color,box-shadow,opacity] duration-150 "
                            + (
                                "z-20 border-primary ring-1 ring-primary"
                                    if selectedId == s.id or connectFrom == s.id
                                    else "z-10 border-border"
                            )
                            + (" shadow-md" if dragId == s.id else "")
                            + (
                                " cursor-pointer hover:border-primary"
                                    if connecting and s.id != connectFrom
                                    else (
                                        ""
                                            if editing or selectedId == s.id
                                            else " cursor-pointer hover:border-input"
                                    )
                            )
                            + (" opacity-40" if dimStep(s.id) else "")}
                        style={{
                            "left": str(rects[s.id][0]) + "px",
                            "top": str(rects[s.id][1]) + "px",
                            "width": str(rects[s.id][2]) + "px",
                            "height": str(rects[s.id][3]) + "px"
                        }}
                        onClick={lambda (e: MouseEvent) {
                            e.stopPropagation();
                            if onSelect {
                                onSelect(s.id);
                            }
                        }}
                    >
                        <span className="flex min-w-0 items-center gap-1.5">
                            <span
                                className={"step-swatch " + DOT_FILL[colorKey(s.color)]}
                                aria-hidden="true"
                            />
                            <span
                                className="min-w-0 truncate text-sm leading-5 font-semibold text-foreground"
                            >
                                {s.name}
                            </span>
                        </span>
                        {if detail != "low" {
                            <span
                                key="meta"
                                className="mt-0.5 flex min-w-0 items-center justify-between gap-2 text-xs leading-[18px]"
                            >
                                <span className="num shrink-0 text-muted-foreground">
                                    {str(s.task_count)
                                        + (" task" if s.task_count == 1 else " tasks")}
                                </span>
                                <span
                                    className={"flex min-w-0 items-center gap-1 "
                                        + (
                                            KIND_TONE[s.kind]
                                                if s.kind in KIND_TONE
                                                else "text-subtle"
                                        )}
                                >
                                    {if rects[s.id][2] >= metaNeed[s.id] {
                                        <span key="word" className="truncate">
                                            {KIND_LABEL[s.kind]
                                                if s.kind in KIND_LABEL
                                                else s.kind}
                                        </span>
                                    }}
                                    <KindGlyph kind={s.kind} size={14}/>
                                </span>
                            </span>
                        }}
                        {if detail == "high" and s.id in stepTitles {
                            <span
                                key="titles"
                                className="mt-1 flex min-w-0 flex-col border-t pt-1"
                            >
                                {for tt in nodeTitles(s, stepTitles) {
                                    <span
                                        key={tt}
                                        className="truncate text-xs leading-[17px] text-foreground"
                                    >
                                        {tt}
                                    </span>
                                }}
                                {if s.task_count > len(nodeTitles(s, stepTitles)) {
                                    <span
                                        key="more"
                                        className="text-xs leading-[17px] text-subtle"
                                    >
                                        {str(
                                            s.task_count
                                                - len(nodeTitles(s, stepTitles))
                                        )
                                            + " more"}
                                    </span>
                                }}
                            </span>
                        }}
                        {if editing {
                            <span key="ports" aria-hidden="true">
                                <span
                                    className={"pointer-events-none absolute left-1/2 top-0 size-2 -translate-x-1/2 -translate-y-1/2 rounded-full border border-primary bg-card transition-opacity duration-150 "
                                        + (
                                            "opacity-100"
                                                if selectedId == s.id
                                                else "opacity-0 group-hover:opacity-100"
                                        )}
                                />
                                <span
                                    className={"pointer-events-none absolute bottom-0 left-1/2 size-2 -translate-x-1/2 translate-y-1/2 rounded-full border border-primary bg-card transition-opacity duration-150 "
                                        + (
                                            "opacity-100"
                                                if selectedId == s.id
                                                else "opacity-0 group-hover:opacity-100"
                                        )}
                                />
                                <span
                                    className={"pointer-events-none absolute left-0 top-1/2 size-2 -translate-x-1/2 -translate-y-1/2 rounded-full border border-primary bg-card transition-opacity duration-150 "
                                        + (
                                            "opacity-100"
                                                if selectedId == s.id
                                                else "opacity-0 group-hover:opacity-100"
                                        )}
                                />
                                <span
                                    className={"pointer-events-none absolute right-0 top-1/2 size-2 translate-x-1/2 -translate-y-1/2 rounded-full border border-primary bg-card transition-opacity duration-150 "
                                        + (
                                            "opacity-100"
                                                if selectedId == s.id
                                                else "opacity-0 group-hover:opacity-100"
                                        )}
                                />
                            </span>
                        }}
                    </button>
                }}
            </div>
            {if laneMode {
                <div
                    key="lanelabels"
                    className="absolute inset-y-0 z-30 border-r bg-background"
                    style={{
                        "left": str(labelLeft) + "px",
                        "width": str(LANE_LABEL_W) + "px"
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
                            {if lr["rows"] >= 3 {
                                <div
                                    key="totals"
                                    className="num truncate pl-4 text-xs leading-[18px] text-subtle"
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
                        className="flex max-w-sm flex-col items-center gap-1 rounded-md border border-dashed bg-card px-8 py-10 text-center"
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
                <div
                    key="edgeeditor"
                    className="absolute z-40 w-64 -translate-x-1/2 rounded-xl border bg-popover p-2.5 shadow-lg"
                    style={{
                        "left": str(float(activeEdge["mx"]) + panX) + "px",
                        "top": str(float(activeEdge["my"]) + panY + 14.0) + "px"
                    }}
                    onClick={lambda (e: MouseEvent) { e.stopPropagation(); }}
                    onPointerDown={lambda (e: any) { e.stopPropagation(); }}
                >
                    <div
                        className="mb-1.5 flex items-center gap-1 text-xs font-medium text-muted-foreground"
                    >
                        <span className="truncate">{edgeFromName}</span>
                        <span aria-hidden="true">→</span>
                        <span className="truncate">{edgeToName}</span>
                    </div>
                    <Input
                        autoFocus={True}
                        value={edgeDraft}
                        placeholder="What has to be true to move on"
                        className="h-8 text-[13px]"
                        onChange={lambda (e: any) { if onEdgeDraft {
                            onEdgeDraft(e.target.value);
                        }}}
                        onKeyDown={lambda (e: any) { if e.key == "Enter"
                            and onSaveEdgeLabel {
                            onSaveEdgeLabel(
                                activeEdge["from"],
                                activeEdge["to"],
                                edgeDraft,
                                edgeCarry
                            );
                        }}}
                    />
                    <div className="mt-2 flex items-center gap-1">
                        <span className="mr-1 text-xs text-muted-foreground">
                            Carries
                        </span>
                        {for pick in carryPicks {
                            <button
                                key={pick["text"]}
                                type="button"
                                aria-pressed={edgeCarry == pick["key"]}
                                className={"rounded-sm border px-1.5 py-0.5 text-xs transition-colors "
                                    + (
                                        "border-input bg-muted font-semibold text-foreground"
                                            if edgeCarry == pick["key"]
                                            else "border-transparent text-muted-foreground hover:text-foreground"
                                    )}
                                onClick={lambda { if onEdgeCarry {
                                    onEdgeCarry(pick["key"]);
                                }}}
                            >
                                {pick["text"]}
                            </button>
                        }}
                    </div>
                    <div className="mt-2 flex items-center justify-between gap-1">
                        <Button
                            size="sm"
                            onClick={lambda { if onSaveEdgeLabel {
                                onSaveEdgeLabel(
                                    activeEdge["from"],
                                    activeEdge["to"],
                                    edgeDraft,
                                    edgeCarry
                                );
                            }}}
                        >
                            Save
                        </Button>
                        <div className="flex items-center gap-1">
                            {if edgeSaid or edgeHad {
                                <Button
                                    key="clear"
                                    size="sm"
                                    variant="ghost"
                                    title="Take the wording and the tag off this transition, keep the transition"
                                    className="text-muted-foreground"
                                    onClick={lambda { if onSaveEdgeLabel {
                                        onSaveEdgeLabel(
                                            activeEdge["from"], activeEdge["to"], "", ""
                                        );
                                    }}}
                                >
                                    Clear
                                </Button>
                            }}
                            <Button
                                size="sm"
                                variant="ghost"
                                title="Remove this transition"
                                className="text-muted-foreground hover:text-destructive"
                                onClick={lambda { if onDeleteEdge {
                                    onDeleteEdge(activeEdge["from"], activeEdge["to"]);
                                }}}
                            >
                                Delete
                            </Button>
                        </div>
                    </div>
                </div>
            }}
        </div>;
}
