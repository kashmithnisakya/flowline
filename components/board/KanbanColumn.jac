"""One board lane on the page ground: kind glyph, step name, count and an add
button over a 2px rule in the step colour (the lane's only colour), then the
cards. A column is addressed by an opaque key (step jid, or the legacy
status with no flow line). On md+ the board sets the lane height and the
card list scrolls inside it."""

import from ...models { TaskView, StepView }
import from ...constants { KIND_COLORS }
import from .TaskCard { TaskCard }
import from ..common.KindGlyph { KindGlyph }
import from ..flowlines.kinds { DOT_VAR, colorKey }

# A legacy status column has no step colour; it borrows its kind's default.
def ruleColor(color: str, kind: str) -> str {
    if color {
        return DOT_VAR[colorKey(color)];
    }
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
    # A drop on a card's half, threaded to TaskCard: insert beside that card.
    onDropBeside: Callable[[str, str, bool], None] = None,
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
    # Opens the task sheet with this column preselected.
    onAddTask: Callable[[str], None] = None,
    overdueCount: int = 0,
    # The board's columns and steps, for each card's move menu.
    keys: list[str] = [],
    labels: list[str] = [],
    colors: list[str] = [],
    steps: list[StepView] = [],
    selectedId: str = "",
    doneHidden: bool = False
) -> JsxElement {
    has dragOver: bool = False;

    # Work arrives in Done by moving, so that lane has no add button.
    canAdd = bool(onAddTask) and columnKey != doneKey;

    return
        <section
            data-lane={columnKey}
            aria-label={label}
            className={"flex min-w-0 snap-start flex-col rounded-md transition-colors duration-150 md:h-full"
                + (" bg-accent/70" if dragOver else "")}
            onDragOver={lambda (e: DragEvent) {
                e.preventDefault();
                dt = e.dataTransfer;
                if dt {
                    dt.dropEffect = "move";
                }
                if not dragOver {
                    dragOver = True;
                }
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
                taskId = dt.getData("text/x-flowline-task") if dt else "";
                dragOver = False;
                if taskId {
                    onDropTask(taskId, columnKey);
                }
            }}
        >
            <div
                className="mx-0.5 flex h-9 shrink-0 items-center gap-1.5 border-b-2 pl-0.5 text-[13px] font-semibold"
                style={{"borderBottomColor": ruleColor(color, kind)}}
            >
                <span className="text-subtle [--kind-knockout:var(--background)]">
                    <KindGlyph kind={kind} size={13}/>
                </span>
                <span className="min-w-0 truncate" title={label}>{label}</span>
                <span className="num shrink-0 text-xs font-medium text-subtle">
                    {len(tasks)}
                </span>
                {if overdueCount > 0 {
                    <span
                        key="overdue"
                        className="shrink-0 text-xs font-medium whitespace-nowrap text-destructive"
                    >
                        {"· " + str(overdueCount) + " overdue"}
                    </span>
                }}
                {if canAdd {
                    <button
                        key="add"
                        type="button"
                        aria-label={"Add a task to " + label}
                        title="Add a task here"
                        className="ml-auto inline-flex size-6 shrink-0 items-center justify-center rounded-sm text-subtle hover:bg-accent hover:text-foreground"
                        onClick={lambda { onAddTask(columnKey); }}
                    >
                        <svg
                            width={14}
                            height={14}
                            viewBox="0 0 16 16"
                            aria-hidden="true"
                        >
                            <path
                                d="M8 3v10M3 8h10"
                                stroke="currentColor"
                                strokeWidth={1.7}
                                strokeLinecap="round"
                            />
                        </svg>
                    </button>
                }}
            </div>
            <div
                className="-mx-1 flex min-h-0 flex-1 flex-col gap-1.5 overflow-x-hidden overflow-y-auto px-1.5 pt-2 pb-3"
            >
                {for t in tasks {
                    <TaskCard
                        key={t.id}
                        task={t}
                        onOpen={onOpen}
                        onArrowMove={onArrowMove}
                        color={color}
                        doneKey={doneKey}
                        onDropBeside={onDropBeside}
                        columnKey={columnKey}
                        keys={keys}
                        labels={labels}
                        colors={colors}
                        steps={steps}
                        selected={bool(selectedId) and t.id == selectedId}
                    />
                }}
                {if len(tasks) == 0 {
                    <p key="empty" className="px-1 py-2 text-xs text-subtle">
                        {"Done tasks are hidden"
                            if doneHidden
                            else ("No tasks yet" if canAdd else "Drop a task here")}
                    </p>
                }}
                {if showingAll and (moreOlder or loadingOlder) {
                    <button
                        key="more"
                        type="button"
                        disabled={loadingOlder}
                        className="self-start rounded-sm px-1 py-1 text-[12.5px] text-muted-foreground hover:text-foreground hover:underline disabled:opacity-60"
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
                        className="self-start rounded-sm px-1 py-1 text-[12.5px] text-muted-foreground hover:text-foreground hover:underline"
                        onClick={lambda { if onToggleOlder { onToggleOlder(); }}}
                    >
                        {(
                            (str(extraCount) + " more done earlier")
                                if extraCount > 0
                                else "Show done earlier"
                        )
                            if not showingAll
                            else "Show the last 7 days only"}
                    </button>
                }}
            </div>
        </section>;
}
