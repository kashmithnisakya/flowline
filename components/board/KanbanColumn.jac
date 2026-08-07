"""One board column: header with live count, drop target, card list.

Columns come from the org's workflow now, so a column is addressed by an
opaque key (the step's jid, or the legacy status string when no workflow
exists yet) and carries its own label and accent colour.
"""

import from ...models { TaskView }
import from .TaskCard { TaskCard }
import from ..ui.badge { Badge }
import from ..workflow.kinds { DOT_VAR, colorKey }

# Accent per step kind, so a column reads the same on the board as its step
# does on the workflow canvas.
glob KIND_DOT: dict[str, str] = {
         "start": "var(--chart-4)",
         "active": "var(--primary)",
         "handoff": "var(--warning)",
         "blocked": "var(--destructive)",
         "done": "var(--success)"
     };


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
    onToggleOlder: Callable[[], None] = None
) -> JsxElement {
    has dragOver: bool = False;

    return
        <div
            className={"flex w-full min-w-0 flex-col gap-2 rounded-xl border bg-muted/30 p-2 "
                + ("ring-2 ring-ring" if dragOver else "")}
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
                # dragleave fires when entering a child card too — only clear
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
            <div className="flex items-center justify-between px-1 py-1">
                <span
                    className="flex min-w-0 items-center gap-1.5 text-sm font-semibold"
                >
                    <span
                        className="h-2 w-2 shrink-0 rounded-full"
                        style={{
                            "background": (
                                DOT_VAR[colorKey(color)]
                                    if color
                                    else KIND_DOT.get(kind, "var(--chart-4)")
                            )
                        }}
                    />
                    <span className="truncate" title={label}>{label}</span>
                </span>
                <Badge variant="secondary">{len(tasks)}</Badge>
            </div>
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
                    className="rounded-md border border-dashed p-4 text-center text-xs text-muted-foreground"
                >
                    Drop a task here
                </div>
            }}
            {if extraCount > 0 or showingAll {
                <button
                    key="older"
                    type="button"
                    className="rounded-md py-1 text-xs text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
                    onClick={lambda { if onToggleOlder { onToggleOlder(); }}}
                >
                    {("Show " + str(extraCount) + " completed earlier")
                        if not showingAll
                        else "Show recent only"}
                </button>
            }}
        </div>;
}
