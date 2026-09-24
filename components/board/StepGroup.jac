"""One flow line step on the board: its header bar, then its tasks as rows
while open. A task dropped on the group moves to this step; the Done group
passes its history footer."""

import from ...models { TaskRow }
import from .StepHeader { StepHeader }
import from .TaskLine { TaskLine }
import from .RowShell { DRAG_TYPE }

def:pub StepGroup(
    columnKey: str,
    label: str,
    kind: str,
    color: str,
    dot: str,
    tasks: list[TaskRow],
    open: bool,
    overdue: int,
    today: str,
    selectedId: str,
    doneKey: str,
    route: dict[str, any],
    onToggle: Callable[[], None],
    onOpen: Callable[[TaskRow], None],
    onMove: Callable[[TaskRow, str], None],
    onDropTask: Callable[[str, str], None],
    onDropBeside: Callable[[str, str, bool], None],
    onAdd: Callable[[str], None] | None = None,
    empty: str = "No tasks yet",
    footer: any = None
) -> JsxElement {
    has dragOver: bool = False;

    def drop(e: DragEvent) {
        e.preventDefault();
        dragOver = False;
        dt = e.dataTransfer;
        if dt and dt.getData(DRAG_TYPE) {
            onDropTask(dt.getData(DRAG_TYPE), columnKey);
        }
    }

    def leave(e: DragEvent) {
        # A row inside the group fires dragleave on it too.
        ct: any = e.currentTarget;
        if not ct.contains(e.relatedTarget) {
            dragOver = False;
        }
    }

    return
        <section
            data-step={columnKey}
            aria-label={label}
            className={"step-group flex scroll-mt-20 flex-col gap-1.5 rounded-3xl transition-colors"
                + (" bg-accent/50" if dragOver else "")}
            onDragOver={lambda (e: DragEvent) {
                e.preventDefault();
                dragOver = True;
            }}
            onDragLeave={leave}
            onDrop={drop}
        >
            <StepHeader
                label={label}
                color={color}
                kind={kind}
                count={len(tasks)}
                overdue={overdue}
                open={open}
                onToggle={onToggle}
                onAdd={(lambda { onAdd(columnKey); }) if onAdd else None}
            />
            {if open {
                <div key="rows" className="flex flex-col divide-y divide-border/55">
                    {for t in tasks {
                        <TaskLine
                            key={t.id}
                            task={t}
                            today={today}
                            dot={dot}
                            selected={t.id == selectedId}
                            columnKey={columnKey}
                            doneKey={doneKey}
                            route={route}
                            onOpen={onOpen}
                            onMove={onMove}
                            onDropBeside={onDropBeside}
                        />
                    }}
                    {if len(tasks) == 0 {
                        <p key="empty" className="py-3 pl-8 text-[13px] text-subtle">
                            {empty}
                        </p>
                    }}
                    {footer}
                </div>
            }}
        </section>;
}
