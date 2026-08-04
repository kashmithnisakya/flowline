"""A single kanban card.

Draggable via native HTML5 DnD (custom MIME type so foreign drags are
ignored), with arrow-button click-to-move as the no-drag/touch fallback.
"""

import from ...models { TaskView }
glob STATUSES: list[str] = [
    "Backlog", "In Progress", "Review", "Changes Requested", "Done", "Blocked"
];

glob MONTH_SHORT: list[str] = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
];

# "2026-08-07" -> "Aug 7"
def prettyDay(iso: str) -> str {
    if len(iso) < 10 {
        return iso;
    }
    return MONTH_SHORT[int(iso[5:7]) - 1] + " " + str(int(iso[8:10]));
}
import from ..ui.card { Card, CardContent }
import from ..ui.badge { Badge }
import from ..ui.button { Button }
import from .GitHubChip { GitHubChip }

def:pub TaskCard(
    task: TaskView,
    onOpen: Callable[[TaskView], None],
    onArrowMove: Callable[[TaskView, str], None],
    onMarkDone: Callable[[str], None] = None
) -> JsxElement {
    # The column does not forward a mark-done callback yet, so fall back to
    # the arrow path. Both land in the page's moveTo, undo toast included.
    def markDone(taskId: str) {
        if onMarkDone {
            onMarkDone(taskId);
        } else {
            onArrowMove(task, "Done");
        }
    }

    statusIdx = 0;
    for (i, s) in enumerate(STATUSES) {
        if s == task.status {
            statusIdx = i;
        }
    }
    prevStatus = STATUSES[statusIdx - 1] if statusIdx > 0 else "";
    nextStatus = STATUSES[statusIdx + 1] if statusIdx < len(STATUSES) - 1 else "";
    priorityVariant = "destructive" if task.priority == "High" else (
        "secondary" if task.priority == "Medium" else "outline"
    );

    return <Card
        draggable={True}
        onDragStart={lambda (e: DragEvent) {
            dt = e.dataTransfer;
            if dt {
                dt.setData("text/x-standup-task", task.id);
                dt.effectAllowed = "move";
            }
        }}
        onClick={lambda { onOpen(task); }}
        role="button"
        tabIndex={0}
        onKeyDown={lambda (e: KeyboardEvent) {
            if e.key == "Enter" or e.key == " " {
                e.preventDefault();
                onOpen(task);
            }
        }}
        className="group cursor-grab gap-0 border-border/70 py-0 transition-shadow hover:shadow-md active:cursor-grabbing"
    >
        <CardContent className="space-y-2 p-3">
            <div className="text-sm font-medium leading-snug">{task.title}</div>
            <div className="flex flex-wrap items-center gap-1">
                {if task.project_name {
                    <Badge key="project" variant="secondary">{task.project_name}</Badge>
                }}
                {if task.priority {
                    <Badge key="priority" variant={priorityVariant}>{task.priority}</Badge>
                }}
                {if task.category {
                    <Badge key="category" variant="outline">{task.category}</Badge>
                }}
            </div>
            {if len(task.assignee_names) > 0 or task.due_date {
                <div key="meta" className="flex items-center justify-between text-xs text-muted-foreground">
                    <span className="truncate">{", ".join(task.assignee_names)}</span>
                    <span className="shrink-0">{prettyDay(task.due_date)}</span>
                </div>
            }}
            {if task.status == "Blocked" and task.notes {
                <div key="blocked" className="rounded-md border border-destructive/40 bg-destructive/10 px-2 py-1 text-xs text-destructive">
                    {task.notes}
                </div>
            }}
            {if task.gh_issue_number > 0 or task.pr_state {
                <GitHubChip key="github" task={task} onMarkDone={markDone} />
            }}
            <div className="flex items-center justify-end gap-1 opacity-50 transition-opacity group-hover:opacity-100">
                <Button
                    variant="ghost"
                    size="icon-xs"
                    className="text-muted-foreground hover:text-foreground"
                    disabled={not prevStatus}
                    title={"Move to " + prevStatus if prevStatus else ""}
                    onClick={lambda (e: MouseEvent) {
                        e.stopPropagation();
                        onArrowMove(task, prevStatus);
                    }}
                >
                    ←
                </Button>
                <Button
                    variant="ghost"
                    size="icon-xs"
                    className="text-muted-foreground hover:text-foreground"
                    disabled={not nextStatus}
                    title={"Move to " + nextStatus if nextStatus else ""}
                    onClick={lambda (e: MouseEvent) {
                        e.stopPropagation();
                        onArrowMove(task, nextStatus);
                    }}
                >
                    →
                </Button>
            </div>
        </CardContent>
    </Card>;
}
