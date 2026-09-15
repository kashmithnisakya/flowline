"""A board card in two lines: the title, then one meta line (a High flag,
project, due, GitHub number, people). Overdue or blocked adds one red line.
Native HTML5 drag with a custom MIME type; M opens the move menu, which on
phones and touch screens also has a visible button. shrink-0 matters: the
lane's list is a scrolling flex column that would otherwise squash cards."""

import from ...models { TaskView, StepView }
import from ...lib.dates { todayIso, dueTone, daysUntil, prettyDay }
import from ..common.Avatar { AvatarStack }
import from ..common.KindGlyph { KindGlyph }
import from .GitHubChip { GitHubChip, ghNumber, ghHref, suggestsDone }
import from .MoveMenu { MoveMenu }

glob WEEKDAY: list[str] = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
     # Visible on phones and touch screens; on a desktop pointer it shrinks
     # to an invisible anchor at the card's lower left for the M menu.
     MOVE_TRIGGER: str = "absolute top-1.5 right-1.5 inline-flex size-7 items-center justify-center rounded-sm text-subtle outline-none hover:bg-accent hover:text-foreground focus-visible:outline-2 focus-visible:outline-solid focus-visible:outline-ring md:pointer-fine:pointer-events-none md:pointer-fine:top-auto md:pointer-fine:right-auto md:pointer-fine:bottom-0 md:pointer-fine:left-2.5 md:pointer-fine:size-px md:pointer-fine:opacity-0";

# The due date as a person says it: today, tomorrow, a weekday within the
# week, else a short date. Overdue and Done return "" (the red line and
# history own those).
def:pub cardDue(iso: str, status: str, today: str) -> str {
    if len(iso) < 10 or status == "Done" {
        return "";
    }
    diff = daysUntil(iso, today);
    if diff < 0 {
        return "";
    }
    if diff == 0 {
        return "today";
    }
    if diff == 1 {
        return "tomorrow";
    }
    if diff < 7 {
        d = new(Date, iso[:10] + "T00:00:00");
        return WEEKDAY[int(d.getDay())];
    }
    return prettyDay(iso);
}

# The reason a move recorded ("**2026-09-14:** needs a device"), or the
# first line of the notes for a blocked card, without the markdown marks.
def:pub leadNote(notes: str, anyLine: bool) -> str {
    text = notes.strip() if notes else "";
    if not text {
        return "";
    }
    first = text.split("\n")[0].strip();
    stamped = first.startswith("**") and len(first) > 15 and first[12:15] == ":**";
    if not stamped and not anyLine {
        return "";
    }
    if stamped {
        first = first[15:].strip();
    }
    first = first.replace("**", "").replace("`", "");
    while len(first) > 0 and first[0] in "#- " {
        first = first[1:];
    }
    return first.strip();
}

def:pub TaskCard(
    task: TaskView,
    onOpen: Callable[[TaskView], None],
    onArrowMove: Callable[[TaskView, str], None],
    color: str = "",
    doneKey: str = "",
    # A drop on the card's upper half inserts before it, lower half after.
    onDropBeside: Callable[[str, str, bool], None] = None,
    # The board's columns, for the move menu: this card's column and the
    # parallel key/label/colour lists, plus the steps' transitions.
    columnKey: str = "",
    keys: list[str] = [],
    labels: list[str] = [],
    colors: list[str] = [],
    steps: list[StepView] = [],
    selected: bool = False
) -> JsxElement {
    has isDragging: bool = False,
        dropHint: str = "",
        moveOpen: bool = False;

    def hoverHalf(e: DragEvent) -> str {
        el: any = e.currentTarget;
        r = el.getBoundingClientRect();
        return "above" if (e.clientY - r.top) < r.height / 2.0 else "below";
    }

    def markDone(taskId: str) {
        if doneKey {
            onArrowMove(task, doneKey);
        }
    }

    # After the menu closes the card may sit in another lane (a new element),
    # so focus is found by id rather than kept on a ref.
    def refocus {
        tid = task.id;
        window.setTimeout(
            lambda {
                el: any = document.querySelector('[data-task-card="' + tid + '"]');
                if el {
                    el.focus({"preventScroll": True});
                }
            },
            0
        );
    }

    today = todayIso();
    tone = dueTone(task.due_date, task.status, today);
    due = cardDue(task.due_date, task.status, today);
    blocked = task.status == "Blocked";
    alert = "";
    if tone == "overdue" {
        late = 0 - daysUntil(task.due_date, today);
        alert = str(late) + (" day overdue" if late == 1 else " days overdue");
        why = leadNote(task.notes, False);
        if why {
            alert = alert + " · " + why;
        }
    } elif blocked {
        alert = leadNote(task.notes, True) or "Blocked";
    }
    num = ghNumber(task);
    clTotal = len(task.checklist);
    clDone = 0;
    for item in task.checklist {
        if item["done"] {
            clDone = clDone + 1;
        }
    }

    return
        <div
            data-task-card={task.id}
            role="button"
            tabIndex={0}
            draggable={True}
            onDragStart={lambda (e: DragEvent) {
                dt = e.dataTransfer;
                if dt {
                    dt.setData("text/x-flowline-task", task.id);
                    dt.effectAllowed = "move";
                }
                isDragging = True;
            }}
            onDragEnd={lambda { isDragging = False; }}
            onDragOver={lambda (e: DragEvent) { if onDropBeside and not isDragging {
                e.preventDefault();
                e.stopPropagation();
                half = hoverHalf(e);
                if dropHint != half {
                    dropHint = half;
                }
            }}}
            onDragLeave={lambda { if dropHint { dropHint = ""; }}}
            onDrop={lambda (e: DragEvent) { if onDropBeside {
                e.preventDefault();
                e.stopPropagation();
                dropHint = "";
                dt = e.dataTransfer;
                dragged = dt.getData("text/x-flowline-task") if dt else "";
                if dragged and dragged != task.id {
                    onDropBeside(dragged, task.id, hoverHalf(e) == "above");
                }
            }}}
            onClick={lambda { onOpen(task); }}
            onKeyDown={lambda (e: KeyboardEvent) {
                k = str(e.key);
                if k == "Enter" or k == " " {
                    e.preventDefault();
                    onOpen(task);
                } elif (k == "m" or k == "M")
                    and not e.metaKey
                    and not e.ctrlKey
                    and not e.altKey
                    and len(keys) > 0 {
                    e.preventDefault();
                    moveOpen = True;
                }
            }}
            className={"group relative flex shrink-0 cursor-pointer flex-col gap-1 rounded-md border bg-card px-2.5 pt-2 pb-2 text-left transition-colors duration-150 select-none hover:border-input "
                + ("opacity-50 " if isDragging else "")
                + (
                    "border-primary ring-1 ring-primary hover:border-primary"
                        if selected
                        else ""
                )}
        >
            {if dropHint == "above" {
                <div
                    key="hintAbove"
                    className="pointer-events-none absolute -top-[5px] right-1 left-1 h-0.5 rounded-full bg-primary"
                />
            }}
            {if dropHint == "below" {
                <div
                    key="hintBelow"
                    className="pointer-events-none absolute right-1 -bottom-[5px] left-1 h-0.5 rounded-full bg-primary"
                />
            }}
            <div
                className="line-clamp-3 text-[13.5px] leading-[1.35] font-medium text-foreground max-md:pr-7 pointer-coarse:pr-7"
            >
                {task.title}
            </div>
            {if alert {
                <div
                    key="alert"
                    className="flex items-start gap-1.5 text-xs leading-[1.35] text-destructive"
                >
                    <KindGlyph kind="blocked" size={12} className="mt-px"/>
                    <span className="line-clamp-2">{alert}</span>
                </div>
            }}
            <div
                className="flex min-h-6 min-w-0 items-center gap-1.5 text-xs text-muted-foreground"
            >
                {if task.priority == "High" {
                    <svg
                        key="high"
                        width={12}
                        height={12}
                        viewBox="0 0 16 16"
                        className="shrink-0 text-foreground"
                        role="img"
                        aria-label="High priority"
                    >
                        <path
                            d="M4 14V2.5M4 3h8l-1.8 3L12 9H4"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth={1.6}
                            strokeLinejoin="round"
                            strokeLinecap="round"
                        />
                    </svg>
                }}
                <span className="flex min-w-0 items-center gap-1 whitespace-nowrap">
                    {if task.project_name {
                        <span key="project" className="min-w-0 truncate">
                            {task.project_name}
                        </span>
                    }}
                    {if due {
                        <span key="due" className="flex shrink-0 items-center gap-1">
                            {if task.project_name {
                                <span key="sep" aria-hidden="true">·</span>
                            }}
                            <span
                                className={"font-semibold text-foreground"
                                    if due == "today"
                                    else ""}
                                title={"Due " + prettyDay(task.due_date)}
                            >
                                {due}
                            </span>
                        </span>
                    }}
                    {if num > 0 {
                        <span key="gh" className="flex shrink-0 items-center gap-1">
                            {if task.project_name or due {
                                <span key="sep" aria-hidden="true">·</span>
                            }}
                            <a
                                href={ghHref(task)}
                                target="_blank"
                                rel="noreferrer"
                                tabIndex={-1}
                                draggable={False}
                                title={task.gh_repo + " #" + str(num)
                                    if task.gh_repo
                                    else "Open on GitHub"}
                                className={"font-mono hover:text-foreground hover:underline"
                                    + (
                                        " line-through"
                                            if task.gh_issue_state == "closed"
                                            else ""
                                    )}
                                onClick={lambda (e: MouseEvent) { e.stopPropagation(); }}
                            >
                                {"#" + str(num)}
                            </a>
                        </span>
                    }}
                </span>
                <span className="ml-auto flex shrink-0 items-center gap-1.5">
                    {if clTotal > 0 {
                        <span
                            key="checklist"
                            className={"flex items-center gap-1 font-mono "
                                + ("text-success" if clDone == clTotal else "")}
                            title={"Checklist: "
                                + str(clDone)
                                + " of "
                                + str(clTotal)
                                + " done"}
                        >
                            <svg
                                width={12}
                                height={12}
                                viewBox="0 0 16 16"
                                aria-hidden="true"
                            >
                                <rect
                                    x={2}
                                    y={2}
                                    width={12}
                                    height={12}
                                    rx={2.5}
                                    fill="none"
                                    stroke="currentColor"
                                    strokeWidth={1.5}
                                />
                                <path
                                    d="m5 8.2 2 2 4-4.2"
                                    fill="none"
                                    stroke="currentColor"
                                    strokeWidth={1.6}
                                    strokeLinecap="round"
                                    strokeLinejoin="round"
                                />
                            </svg>
                            {str(clDone) + "/" + str(clTotal)}
                        </span>
                    }}
                    {if len(task.assignee_names) > 0 {
                        <AvatarStack key="who" names={task.assignee_names}/>
                    } elif task.gh_issue_number > 0 {
                        <svg
                            key="ghmark"
                            width={14}
                            height={14}
                            viewBox="0 0 16 16"
                            className="text-muted-foreground"
                            role="img"
                            aria-label="From GitHub"
                        >
                            <path
                                fill="currentColor"
                                d="M8 .8a7.2 7.2 0 0 0-2.3 14c.4.1.5-.1.5-.3v-1.3c-2 .4-2.4-.9-2.4-.9-.3-.8-.8-1-.8-1-.7-.5 0-.5 0-.5.7.1 1.1.8 1.1.8.6 1.1 1.7.8 2.1.6.1-.5.3-.8.5-1-1.6-.2-3.3-.8-3.3-3.6 0-.8.3-1.4.8-1.9-.1-.2-.3-.9.1-1.9 0 0 .6-.2 2 .7a6.9 6.9 0 0 1 3.6 0c1.4-.9 2-.7 2-.7.4 1 .2 1.7.1 1.9.5.5.8 1.1.8 1.9 0 2.8-1.7 3.4-3.3 3.6.3.2.5.7.5 1.4v2c0 .2.1.4.5.3A7.2 7.2 0 0 0 8 .8"
                            />
                        </svg>
                    } }
                </span>
            </div>
            {if suggestsDone(task) and doneKey {
                <GitHubChip key="merged" task={task} onMarkDone={markDone}/>
            }}
            {if len(keys) > 0 {
                if moveOpen {
                    <MoveMenu
                        key="move"
                        open={True}
                        onOpenChange={lambda (o: bool) { moveOpen = o; }}
                        current={columnKey}
                        keys={keys}
                        labels={labels}
                        colors={colors}
                        steps={steps}
                        onPick={lambda (k: str) { onArrowMove(task, k); }}
                        triggerClass={MOVE_TRIGGER}
                        onClosed={refocus}
                    />
                } else {
                    <button
                        key="move"
                        type="button"
                        tabIndex={-1}
                        aria-haspopup="menu"
                        aria-expanded="false"
                        aria-label="Move to another step"
                        className={MOVE_TRIGGER}
                        onClick={lambda (e: MouseEvent) {
                            e.stopPropagation();
                            moveOpen = True;
                        }}
                        onKeyDown={lambda (e: KeyboardEvent) { e.stopPropagation(); }}
                    >
                        <svg
                            width={14}
                            height={14}
                            viewBox="0 0 16 16"
                            aria-hidden="true"
                            className="shrink-0"
                        >
                            <path
                                d="M3 8h9.5M9 4.5 12.5 8 9 11.5"
                                fill="none"
                                stroke="currentColor"
                                strokeWidth={1.6}
                                strokeLinecap="round"
                                strokeLinejoin="round"
                            />
                        </svg>
                    </button>
                }
            }}
        </div>;
}
