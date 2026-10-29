"""Read-only storyboards on the native flow canvas. Presentation adapters
never create operational steps, task counts or automation runs."""

import from "react" { useEffect }
import from ...models { ProcessView, StepView }
import from ..flowlines.FlowCanvas { FlowCanvas }
import from ..flowlines.StepListRow { StepListRow }

def nodeById(steps: list[dict[str, str]], key: str) -> dict[str, str] {
    for s in steps {
        if s["id"] == key {
            return s;
        }
    }
    return {};
}

def processSteps(process: ProcessView) -> list[StepView] {
    rows: list[StepView] = [];
    for (index, item) in enumerate(process.steps) {
        kind = "active";
        if item["id"] == "intake" {
            kind = "start";
        } elif item["id"] == "production" {
            kind = "done";
        } elif item["id"] == "exception" {
            kind = "blocked";
        } elif item["id"]
            in ["approval", "story_approval", "design_approval", "final", "uat"] {
            kind = "handoff";
        }
        title = item["title"];
        if item["status"] in ["Planned", "Placeholder"] {
            title = item["status"] + " · " + title;
        }
        outgoing = [
            t
            for t in process.transitions
            if t["source"] == item["id"]
        ];
        rows.append(
            StepView(
                id=item["id"],
                name=title,
                kind=kind,
                color="slate",
                x=float(item["x"]),
                y=float(item["y"]),
                sort_order=float(index),
                owner=item["owner"],
                blurb=item["status"],
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
            bounds = layout.current["nodes"];
            panX = width / 2.0 - (float(bounds[0]) + float(bounds[2])) / 2.0;
            panY = 24.0 - float(bounds[1]);
        }},
        [process.id, fitTick, width, listView]
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

    rows = processSteps(process);
    if listView {
        return
            <ol
                className="process-step-list flex min-h-0 flex-col gap-1 overflow-y-auto p-2"
                aria-label={process.title + " steps"}
            >
                {for row in rows {
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
                zoom={zoom}
                panX={panX}
                panY={panY}
                layoutRef={layout}
                onSelect={onSelect}
            />
        </div>;
}
