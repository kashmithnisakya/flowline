"""The workflow as a diagram: free-form step cards over SVG transitions.

Purely presentational, positions come in as data (persisted x/y plus the
page's live drag overrides) and every interaction is a callback. Unlike the
roadmap's Flow, edges travel in any direction and loops are legal. Every
transition is drawn the same way: the arrowhead already says which way work
moves, and a second style for "backwards" needed a legend to mean anything.

The viewport never scrolls. It fills its box and a zoom control shrinks the
drawing to fit instead: a scrollbar hides
half the graph behind a gesture, where a zoom level tells you at a glance
that there is more and puts it back on screen in one click. The control
sends a DELTA rather than a target, because two quick clicks would both
read the same render-time zoom and only one would count.
"""

import from ...models { StepView }
import from .geometry { NODE_W, NODE_H, stepXY, canvasSize, wire }
import from .kinds { KIND_LABEL, DOT_FILL, CARD_TINT, colorKey }
import from ..ui.button { Button }


def:pub FlowCanvas(
    steps: list[StepView],
    live: dict[str, list[float]] = {},
    selectedId: str = "",
    connectFrom: str = "",
    selectedEdge: str = "",
    zoom: float = 1.0,
    panX: float = 0.0,
    panY: float = 0.0,
    animate: bool = True,
    showGrid: bool = True,
    canvasRef: Ref[any] = None,
    viewportRef: Ref[any] = None,
    onSelect: Callable[[str], None] = None,
    onSelectEdge: Callable[[str], None] = None,
    onDeleteEdge: Callable[[str, str], None] = None,
    onCanvasClick: Callable[[], None] = None,
    onZoomBy: Callable[[float], None] = None,
    onZoomFit: Callable[[], None] = None,
    onAddStep: Callable[[], None] = None
) -> JsxElement {
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

    # Flatten the transitions once so the SVG is one pass. Both ends must be
    # on this canvas to draw.
    links: list[dict[str, any]] = [];
    for s in steps {
        pos = stepXY(s, live);
        for (i, nid) in enumerate(s.next_ids) {
            if nid not in byId {
                continue;
            }
            target = byId[nid];
            tpos = stepXY(target, live);
            twoWay = s.id in target.next_ids;
            curve = wire(pos[0], pos[1], tpos[0], tpos[1], twoWay);
            # next_labels comes from the same traversal as next_ids, so
            # position i is the wording on this particular arrow.
            said = s.next_labels[i] if i < len(s.next_labels) else "";
            # A→B and B→A share a midpoint, and wire() only parts the curves
            # by 10px, which is thinner than a label chip. Push the two chips
            # off the line in opposite directions, across whichever axis the
            # pair does NOT travel along, so they can never collide.
            # A send-back is an arrow to an EARLIER step, which is a question
            # about the workflow's order, not about which way the curve
            # happens to point on the canvas. curve["back"] only means "travels
            # up or left", so a forward arrow drawn upwards would wrongly read
            # as rework.
            isReturn = target.sort_order < s.sort_order;
            lx = curve["mx"];
            ly = curve["my"];
            if twoWay {
                dx = tpos[0] - pos[0];
                dy = tpos[1] - pos[1];
                spanX = dx if dx >= 0.0 else 0.0 - dx;
                spanY = dy if dy >= 0.0 else 0.0 - dy;
                # Mirror the rule wire() uses to part the two curves, which
                # keys on the DIRECTION OF TRAVEL, so a label always lands on
                # the same side as its own arrow. Keying on "is this a
                # send-back" instead only agrees by luck: for a horizontal
                # pair the two rules coincide, for a vertical pair they invert
                # and every label ends up on the wrong line.
                if spanX >= spanY {
                    # Parted vertically, and a chip is only ~18px tall.
                    ly = ly + (-18.0 if dx >= 0.0 else 18.0);
                } else {
                    # Parted horizontally, where a chip can run 60-90px wide.
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
                    "label": said
                }
            );
        }
    }

    connecting = bool(connectFrom);
    # The grid scales with the drawing, so zooming reads as moving away from
    # the board rather than the cards changing size against a fixed mesh.
    gridPitch = 22.0 * zoom;

    # The grid is an editing affordance: it says the cards can be dragged and
    # gives them something to line up against. The read-only view has nothing
    # to align, so there it is only texture behind the diagram.
    # Height fills whatever the viewport leaves under the header, title row
    # and legend (~15rem of chrome), with a floor for short windows.
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
                className={"absolute inset-0 origin-top-left"
                    + (
                        " transition-transform duration-200 ease-out"
                            if settled and animate
                            else ""
                    )}
                style={{
                    "transform": "translate(" + str(panX) + "px, "
                        + str(panY) + "px) scale(" + str(zoom) + ")"
                }}
            >
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
                                    else "text-muted-foreground/60 hover:text-foreground/70"
                            ) + " transition-colors duration-150"}
                        >
                            <path
                                d={l["d"]}
                                fill="none"
                                stroke="currentColor"
                                strokeWidth={2.5 if selectedEdge == l["key"] else 2.0}
                                strokeLinecap="round"
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
                                        onSelectEdge(l["key"]);
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
                                className={"pointer-events-none absolute z-10 -translate-x-1/2 -translate-y-1/2 whitespace-nowrap rounded-full border px-2 py-0.5 text-[10px] leading-none shadow-sm "
                                    + (
                                        "border-destructive/40 bg-background text-destructive"
                                            if l["back"]
                                            else "border-border bg-background text-muted-foreground"
                                    )}
                                style={{
                                    "left": str(l["lx"]) + "px",
                                    "top": str(l["ly"]) + "px"
                                }}
                            >
                                {l["label"]}
                            </span>
                        }}
                        {if selectedEdge == l["key"] {
                            <button
                                key="del"
                                type="button"
                                title="Remove this transition"
                                className="absolute z-20 flex h-5 w-5 items-center justify-center rounded-full border bg-background text-muted-foreground shadow-sm transition-colors hover:text-destructive animate-in fade-in zoom-in-75 duration-150"
                                style={{
                                    "left": str(l["mx"] - 10.0) + "px",
                                    "top": str(l["my"] - 10.0) + "px"
                                }}
                                onClick={lambda (e: MouseEvent) {
                                    e.stopPropagation();
                                    if onDeleteEdge {
                                        onDeleteEdge(l["from"], l["to"]);
                                    }
                                }}
                            >
                                <svg
                                    width={11}
                                    height={11}
                                    viewBox="0 0 24 24"
                                    fill="none"
                                    stroke="currentColor"
                                    strokeWidth={2}
                                    strokeLinecap="round"
                                    strokeLinejoin="round"
                                >
                                    <path d="M18 6 6 18"/>
                                    <path d="m6 6 12 12"/>
                                </svg>
                            </button>
                        }}
                    </div>
                }}
                {for s in steps {
                    <button
                        key={s.id}
                        type="button"
                        className={"absolute z-10 rounded-lg border px-3 py-2 text-left shadow-sm hover:shadow-md "
                            + (
                                "transition-[left,top,box-shadow,border-color] duration-200 ease-out "
                                    if settled
                                    else "transition-[box-shadow,border-color] duration-150 "
                            )
                            + CARD_TINT[colorKey(s.color)]
                            + (
                                " border-primary shadow-md ring-2 ring-primary/40"
                                    if selectedId == s.id
                                    else ""
                            )
                            + (
                                " opacity-70"
                                    if connecting and s.id == connectFrom
                                    else ""
                            )
                            + (
                                " cursor-pointer ring-1 ring-primary/60"
                                    if connecting and s.id != connectFrom
                                    else ""
                            )}
                        style={{
                            "left": str(stepXY(s, live)[0]) + "px",
                            "top": str(stepXY(s, live)[1]) + "px",
                            "width": str(NODE_W) + "px",
                            "height": str(NODE_H) + "px"
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
                                className={"h-2 w-2 shrink-0 rounded-full "
                                    + DOT_FILL[colorKey(s.color)]}
                            />
                            <span className="truncate" title={s.name}>{s.name}</span>
                            <span
                                className={"ml-auto shrink-0 rounded-full px-1.5 text-xs font-medium tabular-nums "
                                    + (
                                        "bg-foreground/10"
                                            if s.task_count > 0
                                            else "bg-foreground/5 text-muted-foreground"
                                    )}
                                title={str(s.task_count)
                                    + (" task" if s.task_count == 1 else " tasks")
                                    + " here"}
                            >
                                {str(s.task_count)}
                            </span>
                        </div>
                        <div
                            className="mt-0.5 pl-4 text-[10px] font-medium uppercase tracking-wider text-muted-foreground"
                        >
                            {KIND_LABEL[s.kind] if s.kind in KIND_LABEL else s.kind}
                        </div>
                        {if s.owner {
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
