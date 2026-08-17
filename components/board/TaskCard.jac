"""A single kanban card. Draggable via native HTML5 DnD (custom MIME type so
foreign drags are ignored), with arrow-button click-to-move as the touch
fallback: the chevron row floats over the bottom corner on hover for fine
pointers and keeps an in-flow spot at reduced opacity on touch."""

import from ...models { TaskView }
import from ..workflow.kinds { CARD_BAR, colorKey }

glob MONTH_SHORT: list[str] = [
         "Jan",
         "Feb",
         "Mar",
         "Apr",
         "May",
         "Jun",
         "Jul",
         "Aug",
         "Sep",
         "Oct",
         "Nov",
         "Dec"
     ];

# "2026-08-07" -> "Aug 7"
def prettyDay(iso: str) -> str {
    if len(iso) < 10 {
        return iso;
    }
    return MONTH_SHORT[int(iso[5:7]) - 1] + " " + str(int(iso[8:10]));
}

import from ..common.Markdown { Markdown }
import from ..ui.card { Card, CardContent }
import from ..ui.badge { Badge }
import from ..ui.button { Button }
import from .GitHubChip { GitHubChip }

def:pub TaskCard(
    task: TaskView,
    onOpen: Callable[[TaskView], None],
    onArrowMove: Callable[[TaskView, str], None],
    # Neighbouring columns come from the column rendering this card: the
    # board's columns are the org's workflow, so a card cannot infer them.
    # The step's colour, so a whole column reads as one block of work.
    color: str = "",
    prevKey: str = "",
    prevLabel: str = "",
    nextKey: str = "",
    nextLabel: str = "",
    doneKey: str = "",
    onMarkDone: Callable[[str], None] = None
) -> JsxElement {
    # While the native drag ghost travels, the source card dims so the board
    # shows where the card came from.
    has isDragging: bool = False;

    # The column does not forward a mark-done callback yet, so fall back to
    # the arrow path. Both land in the page's moveTo, undo toast included.
    def markDone(taskId: str) {
        if onMarkDone {
            onMarkDone(taskId);
        } elif doneKey {
            onArrowMove(task, doneKey);
        }
    }
    priorityVariant = "destructive"
        if task.priority == "High"
        else ("secondary" if task.priority == "Medium" else "outline");
    # Overdue = due before today and not already done. `status` is the mapped
    # legacy status, so "Done" covers the done column in both board modes.
    d = new(Date);
    shifted = new(Date, d.getTime() - d.getTimezoneOffset() * 60000);
    todayIso = shifted.toISOString()[:10];
    overdue = len(task.due_date) >= 10
        and task.due_date < todayIso
        and task.status != "Done";

    return
        <Card
            draggable={True}
            onDragStart={lambda (e: DragEvent) {
                dt = e.dataTransfer;
                if dt {
                    dt.setData("text/x-standup-task", task.id);
                    dt.effectAllowed = "move";
                }
                isDragging = True;
            }}
            onDragEnd={lambda { isDragging = False; }}
            onClick={lambda { onOpen(task); }}
            role="button"
            tabIndex={0}
            onKeyDown={lambda (e: KeyboardEvent) { if e.key == "Enter"
                or e.key == " " {
                e.preventDefault();
                onOpen(task);
            }}}
            className={"group relative cursor-grab gap-0 py-0 transition-all duration-150 hover:-translate-y-0.5 hover:shadow-md active:cursor-grabbing "
                + ("opacity-50 " if isDragging else "")
                + (
                    # The COLUMN carries the step's colour; a card only
                    # wears a bar of it. Tinting both made the board shout,
                    # and the grouping is already clear from the panel.
                    ("bg-card " + CARD_BAR[colorKey(color)])
                        if color
                        else "border-border/70"
                )}
        >
            <CardContent className="space-y-2 p-3">
                <div
                    className="line-clamp-2 text-sm font-medium leading-snug"
                    title={task.title}
                >
                    {task.title}
                </div>
                <div className="flex flex-wrap items-center gap-1">
                    {if task.project_name {
                        <Badge key="project" variant="secondary">
                            {task.project_name}
                        </Badge>
                    }}
                    {if task.priority {
                        <Badge key="priority" variant={priorityVariant}>
                            {task.priority}
                        </Badge>
                    }}
                    {if task.category {
                        <Badge key="category" variant="outline">{task.category}</Badge>
                    }}
                </div>
                {if len(task.assignee_names) > 0 or task.due_date {
                    <div
                        key="meta"
                        className="flex items-center justify-between text-xs text-muted-foreground"
                    >
                        <span className="truncate">
                            {", ".join(task.assignee_names)}
                        </span>
                        <span
                            className={"flex shrink-0 items-center gap-1"
                                + (
                                    " font-medium text-destructive"
                                        if overdue
                                        else ""
                                )}
                        >
                            {if overdue {
                                <svg
                                    key="clock"
                                    width={14}
                                    height={14}
                                    viewBox="0 0 24 24"
                                    fill="none"
                                    stroke="currentColor"
                                    strokeWidth={2}
                                    strokeLinecap="round"
                                    strokeLinejoin="round"
                                >
                                    <circle cx={12} cy={12} r={10}/>
                                    <path d="M12 6v6l4 2"/>
                                </svg>
                            }}
                            {prettyDay(task.due_date)}
                        </span>
                    </div>
                }}
                {if task.status == "Blocked" and task.notes {
                    <div
                        key="blocked"
                        className="line-clamp-3 rounded-md border border-destructive/40 bg-destructive/10 px-2 py-1 text-xs text-destructive"
                    >
                        <Markdown text={task.notes}/>
                    </div>
                }}
                {if task.gh_issue_number > 0 or task.pr_state {
                    <GitHubChip key="github" task={task} onMarkDone={markDone}/>
                }}
                <div
                    className="flex items-center justify-end gap-1 opacity-60 transition-opacity duration-150 group-hover:pointer-events-auto group-hover:opacity-100 group-focus-within:pointer-events-auto group-focus-within:opacity-100 pointer-fine:pointer-events-none pointer-fine:absolute pointer-fine:right-1.5 pointer-fine:bottom-1.5 pointer-fine:rounded-lg pointer-fine:border pointer-fine:border-border/60 pointer-fine:bg-card/95 pointer-fine:p-0.5 pointer-fine:opacity-0 pointer-fine:shadow-sm pointer-fine:backdrop-blur-sm"
                >
                    <Button
                        variant="ghost"
                        size="icon-xs"
                        className="text-muted-foreground hover:text-foreground"
                        disabled={not prevKey}
                        title={"Move to " + prevLabel if prevKey else ""}
                        onClick={lambda (e: MouseEvent) {
                            e.stopPropagation();
                            onArrowMove(task, prevKey);
                        }}
                    >
                        <svg
                            width={14}
                            height={14}
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth={2}
                            strokeLinecap="round"
                            strokeLinejoin="round"
                        >
                            <path d="m15 18-6-6 6-6"/>
                        </svg>
                    </Button>
                    <Button
                        variant="ghost"
                        size="icon-xs"
                        className="text-muted-foreground hover:text-foreground"
                        disabled={not nextKey}
                        title={"Move to " + nextLabel if nextKey else ""}
                        onClick={lambda (e: MouseEvent) {
                            e.stopPropagation();
                            onArrowMove(task, nextKey);
                        }}
                    >
                        <svg
                            width={14}
                            height={14}
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth={2}
                            strokeLinecap="round"
                            strokeLinejoin="round"
                        >
                            <path d="m9 18 6-6-6-6"/>
                        </svg>
                    </Button>
                </div>
            </CardContent>
        </Card>;
}
