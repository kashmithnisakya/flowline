"""One status column: header with live count badge, drop target, card list."""

import from ...models { TaskView }
import from .TaskCard { TaskCard }
import from ..ui.badge { Badge }

# Status accent colors from the brand palette (see styles/global.css).
glob STATUS_DOT: dict[str, str] = {
    "Backlog": "var(--chart-4)",
    "In Progress": "var(--primary)",
    "Review": "var(--warning)",
    "Changes Requested": "var(--warning)",
    "Done": "var(--success)",
    "Blocked": "var(--destructive)"
};

def:pub KanbanColumn(
    status: str,
    tasks: list[TaskView],
    onOpen: Callable[[TaskView], None],
    onArrowMove: Callable[[TaskView, str], None],
    onDropTask: Callable[[str, str], None],
    extraCount: int = 0,
    showingAll: bool = False,
    onToggleOlder: Callable[[], None] = None
) -> JsxElement {
    has dragOver: bool = False;

    return <div
        className={
            "flex w-full min-w-0 flex-col gap-2 rounded-xl border bg-muted/30 p-2 "
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
            <span className="flex min-w-0 items-center gap-1.5 text-sm font-semibold">
                <span
                    className="h-2 w-2 shrink-0 rounded-full"
                    style={{"background": STATUS_DOT.get(status, "var(--chart-4)")}}
                />
                <span className="truncate">{status}</span>
            </span>
            <Badge variant="secondary">{len(tasks)}</Badge>
        </div>
        {for t in tasks {
            <TaskCard key={t.id} task={t} onOpen={onOpen} onArrowMove={onArrowMove} />
        }}
        {if len(tasks) == 0 {
            <div key="empty" className="rounded-md border border-dashed p-4 text-center text-xs text-muted-foreground">
                Drop a task here
            </div>
        }}
        {if extraCount > 0 or showingAll {
            <button
                key="older"
                type="button"
                className="rounded-md py-1 text-xs text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
                onClick={lambda { if onToggleOlder { onToggleOlder(); } }}
            >
                {("Show " + str(extraCount) + " completed earlier") if not showingAll else "Show recent only"}
            </button>
        }}
    </div>;
}
