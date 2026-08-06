"""The workflow as a diagram: free-form step cards over SVG transitions.

Purely presentational — positions come in as data (persisted x/y plus the
page's live drag overrides) and every interaction is a callback. Unlike the
roadmap's Flow, edges travel in any direction and loops are legal; an edge
that runs right-to-left or bottom-to-top is drawn dashed in the warning
tone, because it reads as work flowing backwards on purpose.
"""

import from ...models { StepView }
import from .geometry { NODE_W, NODE_H, stepXY, canvasSize, wire }
import from .kinds { KIND_LABEL, DOT_FILL, colorKey }


def:pub FlowCanvas(
    steps: list[StepView],
    live: dict[str, list[float]] = {},
    selectedId: str = "",
    connectFrom: str = "",
    selectedEdge: str = "",
    canvasRef: Ref[any] = None,
    onSelect: Callable[[str], None] = None,
    onSelectEdge: Callable[[str], None] = None,
    onDeleteEdge: Callable[[str, str], None] = None,
    onCanvasClick: Callable[[], None] = None
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

    return
        <div
            className="select-none overflow-auto rounded-lg border bg-card"
            style={{"height": "min(74vh, 44rem)"}}
            onClick={lambda { if onCanvasClick { onCanvasClick(); }}}
        >
            <div
                ref={canvasRef}
                className="relative"
                style={{
                    "width": str(size[0]) + "px",
                    "height": str(size[1]) + "px",
                    "backgroundImage": "radial-gradient(var(--color-muted-foreground) 1px, transparent 1px)",
                    "backgroundSize": "22px 22px",
                    "backgroundPosition": "8px 8px"
                }}
            >
                <svg
                    width={size[0]}
                    height={size[1]}
                    className="absolute inset-0"
                    style={{"pointerEvents": "none"}}
                >
                    {for l in links {
                        <g
                            key={l["key"]}
                            className={"text-primary"
                                if selectedEdge == l["key"]
                                else (
                                    "text-amber-700 dark:text-warning/80"
                                        if l["back"]
                                        else "text-muted-foreground/60"
                                )}
                        >
                            <path
                                d={l["d"]}
                                fill="none"
                                stroke="currentColor"
                                strokeWidth={2}
                                strokeLinecap="round"
                                strokeDasharray={"6 5" if l["back"] else "0"}
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
                        className={"absolute z-10 rounded-lg border bg-card px-3 py-2 text-left shadow-sm transition-shadow hover:shadow-md "
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
                {if len(steps) == 0 {
                    <div
                        key="empty"
                        className="absolute inset-0 flex items-center justify-center"
                    >
                        <div
                            className="rounded-lg border border-dashed p-8 text-center"
                        >
                            <p className="text-sm font-medium">A blank canvas.</p>
                            <p className="mt-1 text-sm text-muted-foreground">
                                Add a step, then drag from its border to another step to draw how work flows.
                            </p>
                        </div>
                    </div>
                }}
            </div>
        </div>;
}
