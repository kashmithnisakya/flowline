"""The board as swimlanes, the shape of the Workflow's Lanes view: one band
per owner role (lane order and labels from lanes.jac's laneLayout), the
steps left to right in flow order as columns, and a step's cards inside its
owner's band. Only the owner cell and the column header take drops; the
rest of the band is just band. Header row and lane gutter stay pinned while
the grid scrolls in either direction.
"""

import from ...models { TaskView }
import from .TaskCard { TaskCard }
import from .LaneHeader { LaneHeader }
import from ..workflow.kinds { DOT_FILL, LANE_BAR, RING_TINT, colorKey }

glob GUTTER: str = "11.5rem",
     COL: str = "minmax(16rem, 18rem)";


# One drop target: a step's cell in its owner's band, or its header.
def:pub StepCell(
    columnKey: str,
    color: str,
    tasks: list[TaskView],
    onOpen: Callable[[TaskView], None],
    onArrowMove: Callable[[TaskView, str], None],
    onDropTask: Callable[[str, str], None],
    prevKey: str = "",
    prevLabel: str = "",
    nextKey: str = "",
    nextLabel: str = "",
    doneKey: str = "",
    extraCount: int = 0,
    showingAll: bool = False,
    onToggleOlder: Callable[[], None] = None,
    onAddTask: Callable[[str], None] = None
) -> JsxElement {
    has dragOver: bool = False;

    return
        <div
            className={"flex min-h-28 flex-col gap-2 rounded-xl border p-2 transition-[box-shadow,background-color] duration-150 " + (
                (
                    RING_TINT[colorKey(color)]
                        if color
                        else "bg-accent ring-2 ring-foreground/20"
                )
                    if dragOver
                    else "border-border/70 bg-card/40"
            )}
            onDragOver={lambda (e: DragEvent) {
                e.preventDefault();
                dt = e.dataTransfer;
                if dt {
                    dt.dropEffect = "move";
                }
                dragOver = True;
            }}
            onDragLeave={lambda (e: DragEvent) {
                e.preventDefault();
                ct: any = e.currentTarget;
                rt: any = e.relatedTarget;
                if not (ct and rt and ct.contains(rt)) {
                    dragOver = False;
                }
            }}
            onDrop={lambda (e: DragEvent) {
                e.preventDefault();
                dt = e.dataTransfer;
                taskId = dt.getData("text/x-standup-task") if dt else "";
                dragOver = False;
                if taskId {
                    onDropTask(taskId, columnKey);
                }
            }}
        >
            {for t in tasks {
                <TaskCard
                    key={t.id}
                    task={t}
                    onOpen={onOpen}
                    onArrowMove={onArrowMove}
                    color={color}
                    prevKey={prevKey}
                    prevLabel={prevLabel}
                    nextKey={nextKey}
                    nextLabel={nextLabel}
                    doneKey={doneKey}
                />
            }}
            {if len(tasks) == 0 {
                <div
                    key="empty"
                    className="flex flex-1 items-center justify-center rounded-lg border border-dashed border-border/70 p-3 text-center text-xs text-muted-foreground"
                >
                    Nothing here yet
                </div>
            }}
            {if extraCount > 0 or showingAll {
                <button
                    key="older"
                    type="button"
                    className="rounded-lg py-1 text-xs tabular-nums text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
                    onClick={lambda { if onToggleOlder { onToggleOlder(); }}}
                >
                    {("Show " + str(extraCount) + " completed earlier")
                        if not showingAll
                        else "Show recent only"}
                </button>
            }}
            {if onAddTask {
                <button
                    key="add"
                    type="button"
                    className="flex shrink-0 items-center gap-1.5 rounded-lg px-2 py-1 text-left text-xs font-medium text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
                    onClick={lambda { onAddTask(columnKey); }}
                >
                    <svg
                        width={12}
                        height={12}
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth={2.5}
                        strokeLinecap="round"
                        aria-hidden="true"
                    >
                        <path d="M12 5v14"/>
                        <path d="M5 12h14"/>
                    </svg>
                    Add task
                </button>
            }}
        </div>;
}


# A column header that also accepts a drop, so a card can be filed under a
# step without scrolling to its owner's band.
def HeaderCell(
    label: str,
    kind: str,
    color: str,
    count: int,
    overdueCount: int,
    columnKey: str,
    onDropTask: Callable[[str, str], None]
) -> JsxElement {
    has dragOver: bool = False;

    return
        <div
            className={"relative sticky top-0 z-20 border-b border-border/70 bg-background/95 px-1 pt-2 pb-1 backdrop-blur" + (
                ((" " + RING_TINT[colorKey(color)]) if color else " bg-accent")
                    if dragOver
                    else ""
            )}
            onDragOver={lambda (e: DragEvent) {
                e.preventDefault();
                dt = e.dataTransfer;
                if dt {
                    dt.dropEffect = "move";
                }
                dragOver = True;
            }}
            onDragLeave={lambda (e: DragEvent) {
                e.preventDefault();
                ct: any = e.currentTarget;
                rt: any = e.relatedTarget;
                if not (ct and rt and ct.contains(rt)) {
                    dragOver = False;
                }
            }}
            onDrop={lambda (e: DragEvent) {
                e.preventDefault();
                dt = e.dataTransfer;
                taskId = dt.getData("text/x-standup-task") if dt else "";
                dragOver = False;
                if taskId {
                    onDropTask(taskId, columnKey);
                }
            }}
        >
            {if color {
                <span
                    key="bar"
                    aria-hidden="true"
                    className={"pointer-events-none absolute inset-x-3 top-0 h-[3px] rounded-b-full " + LANE_BAR[
                        colorKey(color)
                    ]}
                />
            }}
            <LaneHeader
                label={label}
                kind={kind}
                color={color}
                count={count}
                overdueCount={overdueCount}
            />
        </div>;
}


def:pub SwimlaneBoard(
    # Columns in flow order: key, label, kind, color, and the lane key of
    # the step's owner (from laneLayout's laneOf).
    columns: list[dict[str, str]],
    # Bands in lane order: key, label, sub, warn ("y" or ""), color.
    lanes: list[dict[str, str]],
    tasksByKey: dict[str, list[TaskView]],
    overdueByKey: dict[str, int],
    onOpen: Callable[[TaskView], None],
    onArrowMove: Callable[[TaskView, str], None],
    onDropTask: Callable[[str, str], None],
    onAddTask: Callable[[str], None],
    doneKey: str = "",
    doneExtra: int = 0,
    showingAllDone: bool = False,
    onToggleOlder: Callable[[], None] = None
) -> JsxElement {
    n = len(columns);
    template = GUTTER + " repeat(" + str(n) + ", " + COL + ")";

    def keyAt(i: int) -> str {
        return columns[i]["key"] if i >= 0 and i < n else "";
    }
    def labelAt(i: int) -> str {
        return columns[i]["label"] if i >= 0 and i < n else "";
    }
    def tasksOf(key: str) -> list[TaskView] {
        return tasksByKey[key] if key in tasksByKey else [];
    }
    def overdueOf(key: str) -> int {
        return overdueByKey[key] if key in overdueByKey else 0;
    }

    return
        <div
            className="h-[var(--lane-h)] min-h-[24rem] overflow-auto rounded-xl border bg-muted/20"
        >
            <div className="grid min-w-max" style={{"gridTemplateColumns": template}}>
                <div
                    className="sticky top-0 left-0 z-30 border-b border-border/70 bg-background/95 backdrop-blur"
                />
                {for c in columns {
                    <HeaderCell
                        key={"h-" + c["key"]}
                        label={c["label"]}
                        kind={c["kind"]}
                        color={c["color"]}
                        count={len(tasksOf(c["key"]))}
                        overdueCount={overdueOf(c["key"])}
                        columnKey={c["key"]}
                        onDropTask={onDropTask}
                    />
                }}
                {for (li, lane) in enumerate(lanes) {
                    <div key={"lane-" + lane["key"]} className="contents">
                        <div
                            className={"sticky left-0 z-10 flex min-h-32 flex-col justify-center gap-0.5 border-r border-border/60 px-3 py-3 backdrop-blur " + (
                                "bg-muted/60" if li % 2 == 1 else "bg-background/95"
                            ) + ("" if li == 0 else " border-t border-border/60")}
                        >
                            <div
                                className="flex items-center gap-1.5 text-xs font-semibold"
                            >
                                <span
                                    className={"h-2 w-2 shrink-0 rounded-full " + DOT_FILL[
                                        colorKey(lane["color"])
                                    ]}
                                />
                                <span className="truncate" title={lane["label"]}>
                                    {lane["label"]}
                                </span>
                            </div>
                            {if lane["sub"] {
                                <div
                                    key="sub"
                                    className={"truncate pl-3.5 text-[10px] " + (
                                        "text-warning"
                                            if lane["warn"]
                                            else "text-muted-foreground"
                                    )}
                                    title={lane["sub"]}
                                >
                                    {lane["sub"]}
                                </div>
                            }}
                            <div className="pl-3.5 text-[10px] text-muted-foreground">
                                {lane["totals"]}
                            </div>
                        </div>
                        {for (ci, c) in enumerate(columns) {
                            <div
                                key={"cell-" + lane["key"] + "-" + c["key"]}
                                className={"p-2 " + (
                                    "bg-foreground/[0.03]" if li % 2 == 1 else ""
                                ) + ("" if li == 0 else " border-t border-border/60")}
                            >
                                {if c["lane"] == lane["key"] {
                                    <StepCell
                                        key="cell"
                                        columnKey={c["key"]}
                                        color={c["color"]}
                                        tasks={tasksOf(c["key"])}
                                        onOpen={onOpen}
                                        onArrowMove={onArrowMove}
                                        onDropTask={onDropTask}
                                        prevKey={keyAt(ci - 1)}
                                        prevLabel={labelAt(ci - 1)}
                                        nextKey={keyAt(ci + 1)}
                                        nextLabel={labelAt(ci + 1)}
                                        doneKey={doneKey}
                                        extraCount={doneExtra
                                            if c["key"] == doneKey
                                            else 0}
                                        showingAll={showingAllDone
                                            if c["key"] == doneKey
                                            else False}
                                        onToggleOlder={onToggleOlder}
                                        onAddTask={onAddTask}
                                    />
                                }}
                            </div>
                        }}
                    </div>
                }}
            </div>
        </div>;
}
