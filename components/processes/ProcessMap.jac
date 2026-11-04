"""Read-only storyboards on the native flow canvas. Presentation adapters
never create operational steps, task counts or automation runs."""

import from "react" { useEffect }
import from ...models { ProcessView, StepView }
import from ..flowlines.FlowCanvas { FlowCanvas }
import from ..flowlines.StepListRow { StepListRow }
import from ..flowlines.geometry { MIN_NODE_W, detailOf, nodeHeight }

def nodeById(steps: list[dict[str, str]], key: str) -> dict[str, str] {
    for s in steps {
        if s["id"] == key {
            return s;
        }
    }
    return {};
}

def processSteps(
    process: ProcessView,
    zoom: float = 1.0,
    mainOnly: bool = False,
    compact: bool = False
) -> list[StepView] {
    rows: list[StepView] = [];
    branchIds = [
        s["id"]
        for s in process.steps
        if s.get("path", "main") == "branch"
    ];
    shown = [
        s
        for s in process.steps
        if not mainOnly or s["id"] not in branchIds
    ];
    xs: list[float] = [];
    ys: list[float] = [];
    for item in shown {
        x = float(item["x"]);
        if x not in xs {
            xs.append(x);
        }
        y = float(item["y"]);
        if y not in ys {
            ys.append(y);
        }
    }
    xs.sort();
    stretch = 1.0;
    if len(xs) > 1 {
        gap = min([xs[i] - xs[i - 1] for i in range(1, len(xs))]);
        # Node text stays screen-sized even when the diagram layout shrinks.
        stretch = max(1.0, (MIN_NODE_W + 20.0) / (gap * zoom));
    }
    # Preserve readable row and optional group-heading clearance at every zoom.
    yScale = 1.0;
    if mainOnly and len(ys) > 1 {
        ys.sort();
        rowGap = min([ys[i] - ys[i - 1] for i in range(1, len(ys))]);
        h = nodeHeight(detailOf(zoom), 0, False);
        yScale = max(0.7, (h + 16.0) / (rowGap * zoom));
        stageYs = [
            float(s["y"])
            for s in shown
            if s.get("stage", "")
        ];
        beforeStage = [
            y
            for y in ys
            if stageYs and y < min(stageYs)
        ];
        if beforeStage {
            yScale = max(
                yScale, (h + 48.0) / ((min(stageYs) - max(beforeStage)) * zoom)
            );
        }
    }
    for (index, item) in enumerate(shown) {
        kind = item.get("kind", "active");
        title = item.get("short_title", "") if compact else "";
        title = title or item["title"];
        if not compact
            and item["status"] in ["Planned", "Placeholder", "Unverified", "POC"] {
            title = item["status"] + " · " + title;
        }
        outgoing = [
            t
            for t in process.transitions
            if t["source"] == item["id"]
                and (
                    not mainOnly
                    or (t["kind"] == "forward" and t["target"] not in branchIds)
                )
        ];
        owner = item["owner"];
        rows.append(
            StepView(
                id=item["id"],
                name=title,
                kind=kind,
                color="slate",
                x=float(item["x"]) * stretch,
                y=float(item["y"]) * yScale,
                sort_order=float(index),
                owner=owner,
                blurb="",
                next_ids=[t["target"] for t in outgoing],
                next_labels=[t["label"] for t in outgoing]
            )
        );
    }
    return rows;
}

def:pub ProcessMap(
    process: ProcessView,
    selectedId: str,
    onSelect: Callable[[str], None],
    listView: bool = False,
    allPaths: bool = False,
    zoom: float = 0.75,
    fitTick: int = 0,
    focusTick: int = 0,
    focusId: str = "",
    onZoom: Callable[[float], None] = None,
    onFit: Callable[[], None] = None
) -> JsxElement {
    has viewport: Ref[any] = Ref(),
        layout: Ref[any] = Ref(),
        drag: Ref[any] = Ref(),
        pose: Ref[any] = Ref(),
        previousZoom: Ref[float] = Ref(zoom),
        panX: float = 0.0,
        panY: float = 24.0,
        width: float = 800.0,
        height: float = 600.0;

    pose.current = {"x": panX, "y": panY, "zoom": zoom};

    useEffect(
        lambda {
            el = viewport.current;
            if not el or listView {
                return;
            }
            w: any = window;
            observer = new(
                w.ResizeObserver,
                lambda {
                    width = float(el.clientWidth);
                    height = float(el.clientHeight);
                }
            );
            observer.observe(el);
            return lambda { observer.disconnect(); };
        },
        [listView]
    );

    useEffect(
        lambda {
            prior = previousZoom.current;
            if prior > 0.0 and prior != zoom {
                ratio = zoom / prior;
                panX = width / 2.0 + (panX - width / 2.0) * ratio;
                panY = height / 2.0 + (panY - height / 2.0) * ratio;
            }
            previousZoom.current = zoom;
        },
        [zoom]
    );

    useEffect(
        lambda { if layout.current and not listView {
            bounds = layout.current["extent"];
            panX = width / 2.0 - (float(bounds[0]) + float(bounds[2])) / 2.0;
            panY = 24.0 - float(bounds[1]);
        }},
        [process.id, fitTick, width, listView, allPaths]
    );

    useEffect(
        lambda { if focusTick > 0 and focusId and layout.current and not listView {
            rects = layout.current["rects"];
            if focusId in rects {
                r = rects[focusId];
                panX = width / 2.0 - float(r[0]) - float(r[2]) / 2.0;
                panY = height / 2.0 - float(r[1]) - float(r[3]) / 2.0;
            }
        }},
        [focusTick, process.id, listView]
    );

    useEffect(
        lambda {
            el = viewport.current;
            if not el or listView {
                return;
            }
            handler = lambda (e: any) {
                e.preventDefault();
                if e.ctrlKey or e.metaKey {
                    if onZoom {
                        onZoom(
                            float(pose.current["zoom"]) * (0.9 if e.deltaY > 0 else 1.1)
                        );
                    }
                } else {
                    panX = float(pose.current["x"]) - float(e.deltaX);
                    panY = float(pose.current["y"]) - float(e.deltaY);
                    pose.current = {"x": panX, "y": panY, "zoom": zoom};
                }
            };
            el.addEventListener("wheel", handler, {"passive": False});
            return lambda { el.removeEventListener("wheel", handler); };
        },
        [zoom, listView]
    );

    def pointerDown(e: PointerEvent) {
        target: any = e.target;
        el = viewport.current;
        if not el or e.button != 0 or target.closest("button") {
            return;
        }
        drag.current = {"x": e.clientX, "y": e.clientY, "panX": panX, "panY": panY};
        el.setPointerCapture(e.pointerId);
    }

    def pointerMove(e: PointerEvent) {
        if drag.current {
            panX = float(drag.current["panX"]) + float(e.clientX)
                - float(drag.current["x"]);
            panY = float(drag.current["panY"]) + float(e.clientY)
                - float(drag.current["y"]);
        }
    }

    def keyDown(e: KeyboardEvent) {
        if e.target != e.currentTarget {
            return;
        }
        if e.key in ["f", "F"] and onFit {
            e.preventDefault();
            onFit();
        } elif e.key in ["+", "="] and onZoom {
            e.preventDefault();
            onZoom(zoom * 1.2);
        } elif e.key == "-" and onZoom {
            e.preventDefault();
            onZoom(zoom / 1.2);
        } elif e.key in ["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"] {
            e.preventDefault();
            if e.key == "ArrowUp" {
                panY = panY + 80.0;
            } elif e.key == "ArrowDown" {
                panY = panY - 80.0;
            } elif e.key == "ArrowLeft" {
                panX = panX + 80.0;
            } else {
                panX = panX - 80.0;
            }
        }
    }

    rows = processSteps(process, zoom, not allPaths and not listView, not listView);
    stageLabels = [
        s.get("stage", "")
        for s in process.steps
        if s.get("stage", "")
    ];
    stageLabel = stageLabels[0] if stageLabels else "";
    stageIds = [
        s["id"]
        for s in process.steps
        if stageLabel and s.get("stage", "") == stageLabel
    ];
    if listView {
        return
            <ol
                className="process-step-list flex min-h-0 flex-col gap-1 overflow-y-auto p-2"
                aria-label={process.title + " steps"}
            >
                {for row in rows {
                    if stageIds and row.id == stageIds[0] {
                        <li
                            key="stage"
                            className="px-3 pt-2 pb-1 text-xs font-medium text-muted-foreground"
                        >
                            {stageLabel}
                        </li>
                    }
                    <StepListRow
                        key={row.id}
                        step={row}
                        outs={[]}
                        selected={selectedId == row.id}
                        showCounts={False}
                        onOpen={onSelect}
                    />
                }}
            </ol>;
    }
    return
        <div
            ref={viewport}
            className="process-map relative min-h-0 flex-1 overflow-hidden outline-none focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-ring"
            role="region"
            aria-label={process.title + " diagram"}
            tabIndex={0}
            onPointerDown={pointerDown}
            onPointerMove={pointerMove}
            onPointerUp={lambda { drag.current = None; }}
            onPointerCancel={lambda { drag.current = None; }}
            onKeyDown={keyDown}
        >
            <FlowCanvas
                steps={rows}
                selectedId={selectedId}
                showCounts={False}
                stageIds={stageIds}
                stageLabel={stageLabel}
                avoidNodeCrossings={True}
                zoom={zoom}
                panX={panX}
                panY={panY}
                layoutRef={layout}
                onSelect={onSelect}
            />
            {if stageIds {
                <span key="stage-description" className="sr-only">
                    {stageLabel + " group"}
                </span>
            }}
        </div>;
}
