"""A single kanban card. Draggable via native HTML5 DnD (custom MIME type so
foreign drags are ignored), with arrow-button click-to-move as the touch
fallback: the chevron row floats over the bottom corner on hover for fine
pointers and keeps an in-flow spot at reduced opacity on touch."""

import from ...models { TaskView }
import from ..workflow.kinds { CARD_BAR, colorKey }
import from ...lib.dates { todayIso, dueTone, dueLabel, prettyDay }
import from ..common.Avatar { AvatarStack, dotFor }
import from ..common.Markdown { Markdown }
import from ..ui.card { Card, CardContent }
import from ..ui.badge { Badge }
import from ..ui.button { Button }
import from .GitHubChip { GitHubChip }

# Due chip by urgency; "" is the quiet default for far-off or done work.
glob DUE_TINT: dict[str, str] = {
         "overdue": "rounded-md bg-destructive/10 px-1.5 py-0.5 font-semibold text-destructive",
         "soon": "rounded-md bg-warning/15 px-1.5 py-0.5 font-semibold text-warning",
         "": "text-muted-foreground"
     };


# Three bars: all lit for High, one for Low. Medium is the default and gets
# no ink at all, so the glyph only appears when it says something.
def PriorityGlyph(level: str) -> JsxElement {
    high = level == "High";
    return
        <svg
            width={12}
            height={12}
            viewBox="0 0 12 12"
            fill="currentColor"
            className={"shrink-0 " + (
                "text-destructive" if high else "text-muted-foreground/70"
            )}
            role="img"
            aria-label={level + " priority"}
        >
            <rect x={1} y={8} width={2.5} height={4} rx={0.5}/>
            <rect
                x={4.75}
                y={5}
                width={2.5}
                height={7}
                rx={0.5}
                opacity={1 if high else 0.3}
            />
            <rect
                x={8.5}
                y={1}
                width={2.5}
                height={11}
                rx={0.5}
                opacity={1 if high else 0.3}
            />
        </svg>;
}


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
    today = todayIso();
    tone = dueTone(task.due_date, task.status, today);
    showPriority = task.priority == "High" or task.priority == "Low";
    hasFooter = len(task.assignee_names) > 0
    or bool(task.category)
    or showPriority
    or bool(task.due_date);

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
            className={"group relative cursor-grab gap-0 py-0 transition-all duration-150 hover:-translate-y-0.5 hover:shadow-md focus-visible:ring-2 focus-visible:ring-ring active:cursor-grabbing " + (
                "opacity-50 " if isDragging else ""
            ) + (
                # The COLUMN carries the step's colour; a card only
                # wears a bar of it. Tinting both made the board shout,
                # and the grouping is already clear from the panel.
                ("bg-card " + CARD_BAR[colorKey(color)])
                    if color
                    else "border-border/70"
            )}
        >
            <CardContent className="space-y-1.5 p-3">
                {if task.project_name {
                    <div
                        key="project"
                        className="flex items-center gap-1.5 text-[11px] font-medium text-muted-foreground"
                    >
                        <span
                            className={"h-1.5 w-1.5 shrink-0 rounded-full " + dotFor(
                                task.project_name
                            )}
                        />
                        <span className="truncate">{task.project_name}</span>
                    </div>
                }}
                <div
                    className="line-clamp-2 text-sm font-medium leading-snug"
                    title={task.title}
                >
                    {task.title}
                </div>
                {if hasFooter {
                    <div
                        key="footer"
                        className="flex flex-wrap items-center gap-x-2 gap-y-1 pt-0.5 text-xs text-muted-foreground"
                    >
                        {if len(task.assignee_names) > 0 {
                            <AvatarStack key="who" names={task.assignee_names}/>
                        }}
                        {if task.category {
                            <Badge
                                key="category"
                                variant="outline"
                                className="h-5 max-w-28 truncate rounded-full px-2 text-[11px] font-medium"
                            >
                                {task.category}
                            </Badge>
                        }}
                        {if showPriority or task.due_date {
                            # Right-aligned; wraps to its own line, still
                            # right-aligned, when the lane is narrow.
                            <span
                                key="when"
                                className="ml-auto flex shrink-0 items-center gap-1.5"
                            >
                                {if showPriority {
                                    <PriorityGlyph
                                        key="priority"
                                        level={task.priority}
                                    />
                                }}
                                {if task.due_date {
                                    <span
                                        key="due"
                                        className={"whitespace-nowrap text-[11px] " + DUE_TINT[
                                            tone
                                        ]}
                                        title={"Due " + prettyDay(task.due_date)}
                                    >
                                        {dueLabel(task.due_date, task.status, today)}
                                    </span>
                                }}
                            </span>
                        }}
                    </div>
                }}
                {if task.status == "Blocked" and task.notes {
                    <div
                        key="blocked"
                        className="line-clamp-2 rounded-md border border-destructive/40 bg-destructive/10 px-2 py-1 text-xs text-destructive"
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
                        className="text-muted-foreground hover:text-foreground pointer-coarse:size-7"
                        disabled={not prevKey}
                        title={"Move to " + prevLabel if prevKey else ""}
                        aria-label={"Move to " + prevLabel
                            if prevKey
                            else "No earlier step"}
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
                        className="text-muted-foreground hover:text-foreground pointer-coarse:size-7"
                        disabled={not nextKey}
                        title={"Move to " + nextLabel if nextKey else ""}
                        aria-label={"Move to " + nextLabel
                            if nextKey
                            else "No later step"}
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
