"""One status column: header with live count badge, drop target, card list."""

import from ...models { TaskView }
import from .TaskCard { TaskCard }
import from ..ui.badge { Badge }

def:pub KanbanColumn(
    status: str,
    tasks: list[TaskView],
    onOpen: Callable[[TaskView], None],
    onArrowMove: Callable[[TaskView, str], None],
    onDropTask: Callable[[str, str], None]
) -> JsxElement {
    has dragOver: bool = False;

    <div
        className={
            "flex w-64 shrink-0 flex-col gap-2 rounded-lg border bg-muted/30 p-2 "
            + ("ring-2 ring-ring" if dragOver else "")
        }
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
                onDropTask(taskId, status);
            }
        }}
    >
        <div className="flex items-center justify-between px-1 py-1">
            <span className="text-sm font-medium">{status}</span>
            <Badge variant="secondary">{len(tasks)}</Badge>
        </div>
        {for t in tasks {
            <TaskCard key={t.id} task={t} onOpen={onOpen} onArrowMove={onArrowMove} />
        }}
        {if len(tasks) == 0 {
            <div key="empty" className="rounded-md border border-dashed p-3 text-center text-xs text-muted-foreground">
                Empty
            </div>
        }}
    </div>
}
