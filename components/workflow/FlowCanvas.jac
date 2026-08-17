"""The workflow as a diagram: step cards over SVG transitions, purely
presentational (positions come in as data, every interaction is a callback).
Edges travel any direction and loops are legal. The viewport never scrolls: it
zooms to fit, and the control sends a DELTA so two quick clicks both count."""

import from ...models { StepView }
import from .geometry { NODE_W, NODE_H, stepXY, canvasSize, wire }
import from .lanes { LANE_NODE_H, laneWires }
import from .kinds { KIND_LABEL, DOT_FILL, CARD_TINT, colorKey }
import from ..ui.button { Button }
import from ..ui.input { Input }


def:pub FlowCanvas(
    steps: list[StepView],
    live: dict[str, list[float]] = {},
    selectedId: str = "",
    connectFrom: str = "",
    selectedEdge: str = "",
    edgeDraft: str = "",
    zoom: float = 1.0,
    panX: float = 0.0,
    panY: float = 0.0,
    animate: bool = True,
    showGrid: bool = True,
    # Lane view bands drawn behind the steps, from lanes.jac. Non-empty flips
    # lane mode: elbow wires, compact cards, dashed send-backs, and labels
    # with holders and totals. `laneOf` maps step id to lane key so hovering
    # a lane can fade everything outside it.
    lanes: list[dict[str, any]] = [],
    laneOf: dict[str, str] = {},
    canvasRef: Ref[any] = None,
    viewportRef: Ref[any] = None,
    onSelect: Callable[[str], None] = None,
    onSelectEdge: Callable[[str, str], None] = None,
    onEdgeDraft: Callable[[str], None] = None,
    onSaveEdgeLabel: Callable[[str, str, str], None] = None,
    onDeleteEdge: Callable[[str, str], None] = None,
    onCanvasClick: Callable[[], None] = None,
    onZoomBy: Callable[[float], None] = None,
    onZoomFit: Callable[[], None] = None,
    onAddStep: Callable[[], None] = None
) -> JsxElement {
    # Lane view only: the lane under the pointer. Cards and wires outside it
    # fade, so one role's touchpoints read without a click.
    has hoverLane: str = "";

    byId: dict[str, StepView] = {};
    for s in steps {
        byId[s.id] = s;
    }

    # Is a drag or wire gesture in flight? `live` only carries entries while
    # a card is being dragged, and connectFrom is set for the whole wire
    # gesture. Checked via `in` per step because len() on a dict compiles to
    # a JS .length read that is always undefined.
    dragging = False;
    for s in steps {
        if s.id in live {
            dragging = True;
        }
    }
    settled = (not dragging) and (not bool(connectFrom));

    size = canvasSize(steps, live);

    laneMode = len(lanes) > 0;
    cardH = LANE_NODE_H if laneMode else NODE_H;
    # Materialized ahead of the JSX so the alternating tint and the top
    # border can key off the index without enumerate() in the tree.
    laneRects: list[dict[str, str]] = [];
    for (i, ln) in enumerate(lanes) {
        lk = str(ln["key"]);
        laneRects.append(
            {
                "key": "lane-" + lk,
                "lane": lk,
                "cls": "absolute left-0 transition-colors duration-150" + (
                    " bg-primary/10"
                        if hoverLane == lk
                        else (" bg-foreground/[0.045]" if i % 2 == 1 else "")
                ) + ("" if i == 0 else " border-t border-border/60"),
                "top": str(ln["y"]) + "px",
                "h": str(ln["h"]) + "px",
                "label": str(ln["label"]),
                "sub": str(ln["sub"]),
                "subCls": "mt-0.5 truncate pl-3.5 text-[10px] " + (
                    "text-warning" if ln["warn"] else "text-muted-foreground"
                ),
                "totals": str(ln["totals"]),
                "manage": "y" if ln["manage"] else "",
                "dot": DOT_FILL[colorKey(str(ln["color"]))]
            }
        );
    }
    # Fade rule for hover-focus: a card is dim when a lane is hovered and
    # the card is not in it; a wire is dim when neither end is.
    def dimStep(sid: str) -> bool {
        if not hoverLane {
            return False;
        }
        return (laneOf[sid] if sid in laneOf else "") != hoverLane;
    }

    # Flatten the transitions once so the SVG is one pass. Both ends must be
    # on this canvas to draw. Lane mode gets elbows from lanes.jac; the
    # freeform canvas keeps its curves.
    links: list[dict[str, any]] = [];
    if laneMode {
        links = laneWires(steps, live);
    }
    for s in steps {
        if laneMode {
            break;
        }
        pos = stepXY(s, live);
        for (i, nid) in enumerate(s.next_ids) {
            if nid not in byId {
                continue;
            }
            target = byId[nid];
            tpos = stepXY(target, live);
            twoWay = s.id in target.next_ids;
            curve = wire(pos[0], pos[1], tpos[0], tpos[1], twoWay);
            said = s.next_labels[i] if i < len(s.next_labels) else "";
            # A send-back is an arrow to an EARLIER step, not one that happens
            # to point left: curve["back"] is geometry, this is the workflow.
            isReturn = target.sort_order < s.sort_order;
            lx = curve["mx"];
            ly = curve["my"];
            if twoWay {
                dx = tpos[0] - pos[0];
                dy = tpos[1] - pos[1];
                spanX = dx if dx >= 0.0 else 0.0 - dx;
                spanY = dy if dy >= 0.0 else 0.0 - dy;
                # A→B and B→A share a midpoint, so part the chips the same way
                # wire() parts the curves: by direction of travel, or each
                # label lands on the other one's arrow.
                if spanX >= spanY {
                    ly = ly + (-18.0 if dx >= 0.0 else 18.0);
                } else {
                    lx = lx + (-48.0 if dy >= 0.0 else 48.0);
                }
            }
            links.append(
                {
                    "key": s.id + ">" + nid,
                    "from": s.id,
                    "to": nid,
                    "d": curve["d"],
                    "arrow": curve["arrow"],
                    "mx": curve["mx"],
                    "my": curve["my"],
                    "lx": lx,
                    "ly": ly,
                    "back": isReturn,
                    "label": said,
                    "side": 0
                }
            );
        }
    }

    # The selected transition, so its label editor can be drawn in screen
    # space OUTSIDE the zoom transform (an input inside it scales with the
    # drawing). Tracked with a bool: len() on a dict is undefined in JS.
    activeEdge: dict[str, any] = {};
    activeFound = False;
    for l in links {
        if l["key"] == selectedEdge {
            activeEdge = l;
            activeFound = True;
        }
    }
    # Seeded outside the branch: a name first assigned inside an `if` is
    # block-scoped in the compiled JS and unreachable after it.
    edgeFromName = "";
    edgeToName = "";
    edgeSaid = "";
    if activeFound {
        # Both ends are on the canvas by construction, links are only built
        # when byId holds each end.
        edgeFromName = byId[activeEdge["from"]].name;
        edgeToName = byId[activeEdge["to"]].name;
        edgeSaid = activeEdge["label"];
    }

    connecting = bool(connectFrom);
    # The grid scales with the drawing, so zooming reads as moving away from
    # the board rather than the cards changing size against a fixed mesh.
    gridPitch = 22.0 * zoom;

    # The grid is an editing affordance (something to drag against); the
    # read-only view skips it. Height fills what the viewport leaves under
    # ~15rem of chrome, with a floor for short windows.
    boxStyle: dict[str, str] = {"height": "max(26rem, calc(100dvh - 15rem))"};
    if showGrid {
        boxStyle["backgroundImage"] = "radial-gradient(color-mix(in oklab, var(--color-muted-foreground) 20%, transparent) 1px, transparent 1px)";
        boxStyle["backgroundSize"] = str(gridPitch) + "px " + str(gridPitch) + "px";
        # The mesh tracks the centering offset so a dragged card lines up
        # against the same dots wherever the diagram is panned to.
        boxStyle["backgroundPosition"] = (
            str(panX % gridPitch) + "px " + str(panY % gridPitch) + "px"
        );
    }

    return
        <div
            ref={viewportRef}
            className="relative select-none overflow-hidden rounded-lg border bg-card"
            style={boxStyle}
            onClick={lambda { if onCanvasClick { onCanvasClick(); }}}
        >
            <div
                ref={canvasRef}
                className={"absolute inset-0 origin-top-left" + (
                    " transition-transform duration-200 ease-out"
                        if settled and animate
                        else ""
                )}
                style={{
                    "transform": "translate(" + str(panX) + "px, " + str(panY) + "px) scale(" + str(
                        zoom
                    ) + ")"
                }}
            >
                {for lr in laneRects {
                    <div
                        key={lr["key"]}
                        className={lr["cls"]}
                        style={{
                            "top": lr["top"],
                            "height": lr["h"],
                            "width": str(size[0]) + "px"
                        }}
                        onMouseEnter={lambda { hoverLane = lr["lane"]; }}
                        onMouseLeave={lambda { hoverLane = ""; }}
                    >
                        <div
                            className="pointer-events-auto absolute left-3 top-1/2 w-[9.5rem] -translate-y-1/2 pr-2"
                            onClick={lambda (e: MouseEvent) { e.stopPropagation(); }}
                        >
                            {if lr["manage"] {
                                <a
                                    key="name-link"
                                    href="/workspace?tab=roles"
                                    title="Manage roles on the Workspace"
                                    className="group/lane flex items-center gap-1.5 text-xs font-semibold text-foreground no-underline"
                                >
                                    <span
                                        className={"h-2 w-2 shrink-0 rounded-full " + lr[
                                            "dot"
                                        ]}
                                    />
                                    <span
                                        className="truncate underline-offset-2 group-hover/lane:underline"
                                    >
                                        {lr["label"]}
                                    </span>
                                    <span
                                        className="ml-auto hidden shrink-0 text-[10px] font-normal text-muted-foreground group-hover/lane:inline"
                                    >
                                        ↗
                                    </span>
                                </a>
                            } else {
                                <div
                                    key="name"
                                    className="flex items-center gap-1.5 text-xs font-semibold"
                                >
                                    <span
                                        className={"h-2 w-2 shrink-0 rounded-full " + lr[
                                            "dot"
                                        ]}
                                    />
                                    <span className="truncate" title={lr["label"]}>
                                        {lr["label"]}
                                    </span>
                                </div>
                            } }
                            {if lr["sub"] {
                                <div
                                    key="sub"
                                    className={lr["subCls"]}
                                    title={lr["sub"]}
                                >
                                    {lr["sub"]}
                                </div>
                            }}
                            <div
                                className="mt-0.5 truncate pl-3.5 text-[10px] tabular-nums text-muted-foreground/80"
                            >
                                {lr["totals"]}
                            </div>
                        </div>
                    </div>
                }}
                <svg
                    width={size[0]}
                    height={size[1]}
                    className="absolute left-0 top-0"
                    style={{"pointerEvents": "none"}}
                >
                    {for l in links {
                        <g
                            key={l["key"]}
                            className={(
                                "text-primary"
                                    if selectedEdge == l["key"]
                                    else (
                                        "text-destructive/70"
                                            if laneMode and l["back"]
                                            else "text-muted-foreground/60 hover:text-foreground/70"
                                    )
                            ) + " transition-[color,opacity] duration-150" + (
                                " opacity-20"
                                    if laneMode
                                    and dimStep(l["from"])
                                    and dimStep(l["to"])
                                    else ""
                            )}
                        >
                            <path
                                d={l["d"]}
                                fill="none"
                                stroke="currentColor"
                                strokeWidth={2.5 if selectedEdge == l["key"] else 2.0}
                                strokeLinecap="round"
                                strokeLinejoin="round"
                                strokeDasharray={"6 5"
                                    if laneMode and l["back"]
                                    else ""}
                                className="transition-[stroke-width] duration-150"
                            />
                            <path d={l["arrow"]} fill="currentColor" stroke="none"/>
                            <path
                                d={l["d"]}
                                fill="none"
                                stroke="transparent"
                                strokeWidth={18}
                                style={{"pointerEvents": "stroke", "cursor": "pointer"}}
                                onClick={lambda (e: MouseEvent) {
                                    e.stopPropagation();
                                    if onSelectEdge {
                                        onSelectEdge(l["key"], l["label"]);
                                    }
                                }}
                            />
                        </g>
                    }}
                </svg>
                {for l in links {
                    <div key={"chip-" + l["key"]}>
                        {if l["label"] and selectedEdge != l["key"] {
                            <span
                                key="lab"
                                className={"pointer-events-none absolute z-10 -translate-y-1/2 whitespace-nowrap rounded-full border px-2 py-0.5 text-[10px] leading-none shadow-sm transition-opacity duration-150 " + (
                                    "-translate-x-full"
                                        if l["side"] == -1
                                        else (
                                            "" if l["side"] == 1 else "-translate-x-1/2"
                                        )
                                ) + " " + (
                                    "border-destructive/40 bg-background text-destructive"
                                        if l["back"]
                                        else "border-border bg-background text-muted-foreground"
                                ) + (
                                    " opacity-20"
                                        if laneMode
                                        and dimStep(l["from"])
                                        and dimStep(l["to"])
                                        else ""
                                )}
                                style={{
                                    "left": str(
                                        l["lx"] + (
                                            -8.0
                                                if l["side"] == -1
                                                else (8.0 if l["side"] == 1 else 0.0)
                                        )
                                    ) + "px",
                                    "top": str(l["ly"]) + "px"
                                }}
                            >
                                {l["label"]}
                            </span>
                        }}
                        {if selectedEdge == l["key"] {
                            <span
                                key="dot"
                                className="pointer-events-none absolute z-10 block h-2 w-2 -translate-x-1/2 -translate-y-1/2 rounded-full bg-primary"
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
                        className={"absolute z-10 rounded-lg border px-3 py-2 text-left shadow-sm hover:shadow-md " + (
                            "transition-[left,top,box-shadow,border-color] duration-200 ease-out "
                                if settled
                                else "transition-[box-shadow,border-color] duration-150 "
                        ) + CARD_TINT[colorKey(s.color)] + (
                            " border-primary shadow-md ring-2 ring-primary/40"
                                if selectedId == s.id
                                else ""
                        ) + (
                            " opacity-70" if connecting and s.id == connectFrom else ""
                        ) + (
                            " cursor-pointer ring-1 ring-primary/60"
                                if connecting and s.id != connectFrom
                                else ""
                        ) + (" opacity-30" if laneMode and dimStep(s.id) else "")}
                        style={{
                            "left": str(stepXY(s, live)[0]) + "px",
                            "top": str(stepXY(s, live)[1]) + "px",
                            "width": str(NODE_W) + "px",
                            "height": str(cardH) + "px"
                        }}
                        onClick={lambda (e: MouseEvent) {
                            e.stopPropagation();
                            if onSelect {
                                onSelect(s.id);
                            }
                        }}
                    >
                        <div className="flex items-center gap-2 text-sm font-semibold">
                            <span
                                className={"h-2 w-2 shrink-0 rounded-full " + DOT_FILL[
                                    colorKey(s.color)
                                ]}
                            />
                            <span className="truncate" title={s.name}>{s.name}</span>
                            <span
                                className={"ml-auto shrink-0 rounded-full px-1.5 text-xs font-medium tabular-nums " + (
                                    "bg-foreground/10"
                                        if s.task_count > 0
                                        else "bg-foreground/5 text-muted-foreground"
                                )}
                                title={str(s.task_count) + (
                                    " task" if s.task_count == 1 else " tasks"
                                ) + " here"}
                            >
                                {str(s.task_count)}
                            </span>
                        </div>
                        <div
                            className="mt-0.5 pl-4 text-[10px] font-medium uppercase tracking-wider text-muted-foreground"
                        >
                            {KIND_LABEL[s.kind] if s.kind in KIND_LABEL else s.kind}
                        </div>
                        {if s.owner and not laneMode {
                            <div
                                key="owner"
                                className="mt-1 truncate pl-4 text-[11px] text-foreground/70"
                                title={"Held by: " + s.owner}
                            >
                                {s.owner}
                            </div>
                        }}
                    </button>
                }}
            </div>
            {if len(steps) == 0 {
                <div
                    key="empty"
                    className="pointer-events-none absolute inset-0 flex items-center justify-center"
                >
                    <div
                        className="flex max-w-sm flex-col items-center gap-1 rounded-xl border border-dashed bg-card/80 px-8 py-10 text-center"
                    >
                        <svg
                            className="mb-2 text-muted-foreground"
                            width={28}
                            height={28}
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth={2}
                            strokeLinecap="round"
                            strokeLinejoin="round"
                        >
                            <rect width={8} height={8} x={3} y={3} rx={2}/>
                            <path d="M7 11v4a2 2 0 0 0 2 2h4"/>
                            <rect width={8} height={8} x={13} y={13} rx={2}/>
                        </svg>
                        <p className="text-sm font-medium">A blank canvas.</p>
                        <p className="text-sm text-muted-foreground">
                            Add a step, then drag from its border to another step to draw how work flows.
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
                                <svg
                                    width={14}
                                    height={14}
                                    viewBox="0 0 24 24"
                                    fill="none"
                                    stroke="currentColor"
                                    strokeWidth={2}
                                    strokeLinecap="round"
                                    strokeLinejoin="round"
                                >
                                    <path d="M5 12h14"/>
                                    <path d="M12 5v14"/>
                                </svg>
                                Add your first step
                            </Button>
                        }}
                    </div>
                </div>
            }}
            {if activeFound {
                <div
                    key="edgeeditor"
                    className="absolute z-40 w-64 -translate-x-1/2 rounded-lg border bg-background/95 p-2.5 shadow-lg backdrop-blur animate-in fade-in zoom-in-95 duration-150"
                    style={{
                        "left": str(activeEdge["mx"] * zoom + panX) + "px",
                        "top": str(activeEdge["my"] * zoom + panY + 14.0) + "px"
                    }}
                    onClick={lambda (e: MouseEvent) { e.stopPropagation(); }}
                    onMouseDown={lambda (e: MouseEvent) { e.stopPropagation(); }}
                >
                    <div
                        className="mb-1.5 flex items-center gap-1 text-[11px] font-medium text-muted-foreground"
                    >
                        <span className="truncate">{edgeFromName}</span>
                        <span aria-hidden="true">→</span>
                        <span className="truncate">{edgeToName}</span>
                    </div>
                    <Input
                        autoFocus={True}
                        value={edgeDraft}
                        placeholder="what has to be true to cross"
                        className="h-8 text-xs"
                        onChange={lambda (e: any) { if onEdgeDraft {
                            onEdgeDraft(e.target.value);
                        }}}
                        onKeyDown={lambda (e: any) { if e.key == "Enter"
                        and onSaveEdgeLabel {
                            onSaveEdgeLabel(
                                activeEdge["from"], activeEdge["to"], edgeDraft
                            );
                        }}}
                    />
                    <div className="mt-2 flex items-center justify-between gap-1">
                        <Button
                            size="sm"
                            className="h-7 px-2.5 text-xs"
                            onClick={lambda { if onSaveEdgeLabel {
                                onSaveEdgeLabel(
                                    activeEdge["from"], activeEdge["to"], edgeDraft
                                );
                            }}}
                        >
                            Save
                        </Button>
                        <div className="flex items-center gap-1">
                            {if edgeSaid {
                                <Button
                                    key="clear"
                                    size="sm"
                                    variant="ghost"
                                    title="Take the wording off this arrow, keep the arrow"
                                    className="h-7 px-2 text-xs text-muted-foreground"
                                    onClick={lambda { if onSaveEdgeLabel {
                                        onSaveEdgeLabel(
                                            activeEdge["from"], activeEdge["to"], ""
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
                                className="h-7 px-2 text-xs text-muted-foreground hover:text-destructive"
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
            <div
                className="absolute bottom-4 left-4 z-30 flex items-center gap-1 rounded-full border bg-background/95 px-1 py-1 shadow-sm backdrop-blur"
                onClick={lambda (e: MouseEvent) { e.stopPropagation(); }}
            >
                <button
                    type="button"
                    title="Zoom out"
                    className="flex h-7 w-7 items-center justify-center rounded-full text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
                    onClick={lambda { if onZoomBy { onZoomBy(-0.1); }}}
                >
                    <svg
                        width={14}
                        height={14}
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth={2}
                        strokeLinecap="round"
                        strokeLinejoin="round"
                    >
                        <path d="M5 12h14"/>
                    </svg>
                </button>
                <button
                    type="button"
                    title="Fit the whole workflow"
                    className="min-w-14 rounded-full px-2 text-xs font-medium tabular-nums text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
                    onClick={lambda { if onZoomFit { onZoomFit(); }}}
                >
                    {str(int(zoom * 100.0 + 0.5)) + "%"}
                </button>
                <button
                    type="button"
                    title="Zoom in"
                    className="flex h-7 w-7 items-center justify-center rounded-full text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
                    onClick={lambda { if onZoomBy { onZoomBy(0.1); }}}
                >
                    <svg
                        width={14}
                        height={14}
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth={2}
                        strokeLinecap="round"
                        strokeLinejoin="round"
                    >
                        <path d="M5 12h14"/>
                        <path d="M12 5v14"/>
                    </svg>
                </button>
            </div>
        </div>;
}
