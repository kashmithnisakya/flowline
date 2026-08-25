"""One board column: header with live count, drop target, card list, add row.
Columns come from the org's flow line, so a column is addressed by an opaque
key (step jid, or the legacy status when no flow line exists) with its own
label and colour. On md+ the lane is viewport-high (--lane-h, set by the
board) and the card list scrolls inside it, so header and add row stay put.
"""

import from ...models { TaskView }
import from ...constants { KIND_COLORS }
import from .TaskCard { TaskCard }
import from ..ui.badge { Badge }
import from ..flowlines.kinds { DOT_VAR, LANE_BAR, RING_TINT, COUNT_TINT, colorKey }


# A legacy status column has no step colour of its own; it borrows the
# kind's default so it reads the same as the flow line legend in both themes
# (the old chart-4 fallback was grey in light and sky blue in dark).
def kindDot(kind: str) -> str {
    return DOT_VAR[colorKey(KIND_COLORS[kind] if kind in KIND_COLORS else "slate")];
}


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
    # Older Done history for the Done lane: how many rows exist (-1 while
    # unknown under a filter), whether they are shown, how many are in,
    # whether the server holds more, and the two ways to ask for them.
    extraCount: int = 0,
    showingAll: bool = False,
    onToggleOlder: Callable[[], None] = None,
    olderShown: int = 0,
    moreOlder: bool = False,
    loadingOlder: bool = False,
    onMoreOlder: Callable[[], None] = None,
    # Opens the task dialog with this column preselected.
    onAddTask: Callable[[str], None] = None,
    # False for viewers: cards render without move/drag affordances.
    canEdit: bool = True,
    # Overdue cards in this column, for the header signal.
    overdueCount: int = 0
) -> JsxElement {
    has dragOver: bool = False;

    return
        <div
            className={"relative flex min-h-44 w-full min-w-0 snap-start flex-col gap-2 rounded-xl border bg-muted/30 p-2 transition-[box-shadow,background-color] duration-150 md:h-[var(--lane-h)]"
                + (
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
                    className={"pointer-events-none absolute inset-x-3 top-0 h-[3px] rounded-b-full "
                        + LANE_BAR[colorKey(color)]}
                />
            }}
            <div className="flex shrink-0 items-center justify-between px-1 py-1">
                <span
                    className="flex min-w-0 items-center gap-1.5 text-sm font-semibold"
                >
                    <span
                        className="h-2 w-2 shrink-0 rounded-full"
                        style={{
                            "background": (
                                DOT_VAR[colorKey(color)] if color else kindDot(kind)
                            )
                        }}
                    />
                    <span className="truncate" title={label}>{label}</span>
                </span>
                <span className="flex shrink-0 items-center gap-1.5">
                    {if overdueCount > 0 {
                        <span
                            key="overdue"
                            className="text-[11px] font-semibold tabular-nums text-destructive"
                            title={str(overdueCount) + " overdue"}
                        >
                            {str(overdueCount) + " over"}
                        </span>
                    }}
                    <Badge
                        variant="secondary"
                        className={"tabular-nums "
                            + (COUNT_TINT[colorKey(color)] if color else "")}
                        aria-label={str(len(tasks))
                            + (" task" if len(tasks) == 1 else " tasks")}
                    >
                        {len(tasks)}
                    </Badge>
                </span>
            </div>
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
                        canEdit={canEdit}
                    />
                }}
                {if len(tasks) == 0 {
                    <div
                        key="empty"
                        className="flex flex-1 items-center justify-center rounded-lg border border-dashed p-4 text-center text-xs text-muted-foreground"
                    >
                        {"Drop a task here"
                            if (not onAddTask and canEdit)
                            else "Nothing here yet"}
                    </div>
                }}
                {if showingAll and (moreOlder or loadingOlder) {
                    <button
                        key="more"
                        type="button"
                        disabled={loadingOlder}
                        className="rounded-lg py-1 text-xs tabular-nums text-muted-foreground transition-colors hover:bg-accent hover:text-foreground disabled:opacity-60"
                        onClick={lambda { if onMoreOlder { onMoreOlder(); }}}
                    >
                        {"Loading…"
                            if loadingOlder
                            else "Show more"
                                + (
                                    " ("
                                        + str(olderShown)
                                        + " of "
                                        + str(extraCount)
                                        + ")"
                                        if extraCount > 0
                                        else ""
                                )}
                    </button>
                }}
                {if extraCount != 0 or showingAll {
                    <button
                        key="older"
                        type="button"
                        className="rounded-lg py-1 text-xs tabular-nums text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
                        onClick={lambda { if onToggleOlder { onToggleOlder(); }}}
                    >
                        {(
                            ("Show " + str(extraCount) + " completed earlier")
                                if extraCount > 0
                                else "Show completed earlier"
                        )
                            if not showingAll
                            else "Show recent only"}
                    </button>
                }}
            </div>
            {if onAddTask and canEdit {
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
