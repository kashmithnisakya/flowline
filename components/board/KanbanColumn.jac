"""One board column: header with live count, drop target, card list, add row.
Columns come from the org's workflow, so a column is addressed by an opaque
key (step jid, or the legacy status when no workflow exists) with its own
label and colour. On md+ the lane is viewport-high (--lane-h, set by the
board) and the card list scrolls inside it, so header and add row stay put.
"""

import from ...models { TaskView }
import from .TaskCard { TaskCard }
import from .LaneHeader { LaneHeader }
import from ..workflow.kinds { LANE_BAR, RING_TINT, colorKey }


def:pub KanbanColumn(
    columnKey: str,
    label: str,
    kind: str,
    color: str = "",
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
    # Opens the task dialog with this column preselected.
    onAddTask: Callable[[str], None] = None,
    # Overdue cards in this column, for the header signal.
    overdueCount: int = 0
) -> JsxElement {
    has dragOver: bool = False;

    return
        <div
            className={"relative flex min-h-44 w-full min-w-0 snap-start flex-col gap-2 rounded-xl border bg-muted/30 p-2 transition-[box-shadow,background-color] duration-150 md:h-[var(--lane-h)]" + (
                # Neutral ground; the step colour lives in the top rule, the
                # dot and the count, and floods the panel only while a drop
                # is live.
                (
                    (" " + RING_TINT[colorKey(color)])
                        if color
                        else " bg-accent ring-2 ring-foreground/20"
                )
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
                # dragleave fires when entering a child card too, only clear
                # the highlight when the pointer actually left the column.
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
                count={len(tasks)}
                overdueCount={overdueCount}
            />
            <div
                className="flex min-h-0 flex-1 flex-col gap-2 overflow-y-auto overflow-x-hidden px-0.5 pt-0.5 pb-1 -mx-0.5"
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
                        className="flex flex-1 items-center justify-center rounded-lg border border-dashed p-4 text-center text-xs text-muted-foreground"
                    >
                        {"Nothing here yet" if onAddTask else "Drop a task here"}
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
            </div>
            {if onAddTask {
                <button
                    key="add"
                    type="button"
                    className="flex shrink-0 items-center gap-1.5 rounded-lg px-2 py-1.5 text-left text-xs font-medium text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
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
