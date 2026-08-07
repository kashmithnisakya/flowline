"""The workflow as a diagram: free-form step cards over SVG transitions.

Purely presentational — positions come in as data (persisted x/y plus the
page's live drag overrides) and every interaction is a callback. Unlike the
roadmap's Flow, edges travel in any direction and loops are legal. Every
transition is drawn the same way: the arrowhead already says which way work
moves, and a second style for "backwards" needed a legend to mean anything.

The viewport never scrolls. It fills its box, the dot grid covers all of it,
and a zoom control shrinks the drawing to fit instead: a scrollbar hides
half the graph behind a gesture, where a zoom level tells you at a glance
that there is more and puts it back on screen in one click. The control
sends a DELTA rather than a target, because two quick clicks would both
read the same render-time zoom and only one would count.
"""

import from ...models { StepView }
import from .geometry { NODE_W, NODE_H, stepXY, canvasSize, wire }
import from .kinds { KIND_LABEL, DOT_FILL, CARD_TINT, colorKey }


def:pub FlowCanvas(
    steps: list[StepView],
    live: dict[str, list[float]] = {},
    selectedId: str = "",
    connectFrom: str = "",
    selectedEdge: str = "",
    zoom: float = 1.0,
    canvasRef: Ref[any] = None,
    viewportRef: Ref[any] = None,
    onSelect: Callable[[str], None] = None,
    onSelectEdge: Callable[[str], None] = None,
    onDeleteEdge: Callable[[str, str], None] = None,
    onCanvasClick: Callable[[], None] = None,
    onZoomBy: Callable[[float], None] = None,
    onZoomFit: Callable[[], None] = None
) -> JsxElement {
    byId: dict[str, StepView] = {};
    for s in steps {
        byId[s.id] = s;
    }

    size = canvasSize(steps, live);

    # Flatten the transitions once so the SVG is one pass. Both ends must be
    # on this canvas to draw.
    links: list[dict[str, any]] = [];
    for s in steps {
        pos = stepXY(s, live);
        for nid in s.next_ids {
            if nid not in byId {
                continue;
            }
            target = byId[nid];
            tpos = stepXY(target, live);
            twoWay = s.id in target.next_ids;
            curve = wire(pos[0], pos[1], tpos[0], tpos[1], twoWay);
            links.append(
                {
                    "key": s.id + ">" + nid,
                    "from": s.id,
                    "to": nid,
                    "d": curve["d"],
                    "arrow": curve["arrow"],
                    "mx": curve["mx"],
                    "my": curve["my"],
                    "back": curve["back"]
                }
            );
        }
    }

    connecting = bool(connectFrom);
    # The grid scales with the drawing, so zooming reads as moving away from
    # the board rather than the cards changing size against a fixed mesh.
    gridPitch = 22.0 * zoom;

    return
        <div
            ref={viewportRef}
            className="relative select-none overflow-hidden rounded-lg border bg-card"
            style={{
                "height": "min(74vh, 44rem)",
                "backgroundImage": "radial-gradient(var(--color-muted-foreground) 1px, transparent 1px)",
                "backgroundSize": str(gridPitch) + "px " + str(gridPitch) + "px",
                "backgroundPosition": "8px 8px"
            }}
            onClick={lambda { if onCanvasClick { onCanvasClick(); }}}
        >
            <div
                ref={canvasRef}
                className="absolute inset-0 origin-top-left"
                style={{"transform": "scale(" + str(zoom) + ")"}}
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
                            className={"text-primary"
                                if selectedEdge == l["key"]
                                else "text-muted-foreground/60"}
                        >
                            <path
                                d={l["d"]}
                                fill="none"
                                stroke="currentColor"
                                strokeWidth={2}
                                strokeLinecap="round"
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
                        {if selectedEdge == l["key"] {
                            <button
                                key="del"
                                type="button"
                                title="Remove this transition"
                                className="absolute z-20 flex h-5 w-5 items-center justify-center rounded-full border bg-background text-xs text-muted-foreground shadow-sm hover:text-destructive"
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
                                ✕
                            </button>
                        }}
                    </div>
                }}
                {for s in steps {
                    <button
                        key={s.id}
                        type="button"
                        className={"absolute z-10 rounded-lg border px-3 py-2 text-left shadow-sm transition-shadow hover:shadow-md "
                            + CARD_TINT[colorKey(s.color)]
                            + (
                                " border-primary ring-2 ring-primary/40"
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
                            <span className="truncate">{s.name}</span>
                        </div>
                        <div
                            className="mt-0.5 pl-4 text-[10px] font-medium uppercase tracking-wider text-muted-foreground"
                        >
                            {KIND_LABEL[s.kind] if s.kind in KIND_LABEL else s.kind}
                        </div>
                    </button>
                }}
            </div>
            {if len(steps) == 0 {
                <div
                    key="empty"
                    className="pointer-events-none absolute inset-0 flex items-center justify-center"
                >
                    <div
                        className="rounded-lg border border-dashed bg-card/80 p-8 text-center"
                    >
                        <p className="text-sm font-medium">A blank canvas.</p>
                        <p className="mt-1 text-sm text-muted-foreground">
                            Add a step, then drag from its border to another step to draw how work flows.
                        </p>
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
                    −
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
                    +
                </button>
            </div>
        </div>;
}
