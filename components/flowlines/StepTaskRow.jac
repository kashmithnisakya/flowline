"""One task in the step panel: title and due date, then project, priority and
assignees. The whole row is a button that opens the board's task sheet."""

import from ...models { TaskRow }
import from ...lib.dates { dueTone, dueLabel, prettyDay }

# Due text by urgency, the same three tones the board card uses.
glob DUE_TINT: dict[str, str] = {
         "overdue": "font-semibold text-destructive",
         "soon": "font-semibold text-warning",
         "": "text-muted-foreground"
     };

def:pub StepTaskRow(
    task: TaskRow, today: str, onOpen: Callable[[str], None] = None
) -> JsxElement {
    bits: list[str] = [];
    if task.project_name {
        bits.append(task.project_name);
    }
    if task.priority {
        bits.append(task.priority);
    }
    if len(task.assignee_names) > 0 {
        bits.append(", ".join(task.assignee_names));
    }
    return
        <button
            type="button"
            className="flex w-full flex-col gap-0.5 rounded-lg px-2.5 py-2 text-left transition-colors duration-150 hover:bg-accent focus-visible:bg-accent"
            onClick={lambda { if onOpen { onOpen(task.id); }}}
        >
            <span className="flex w-full items-baseline gap-3">
                <span className="min-w-0 flex-1 text-sm leading-5 font-medium">
                    {task.title}
                </span>
                {if task.due_date {
                    <span
                        key="due"
                        className={"num shrink-0 text-xs whitespace-nowrap "
                            + DUE_TINT[dueTone(task.due_date, task.status, today)]}
                        title={"Due " + prettyDay(task.due_date)}
                    >
                        {dueLabel(task.due_date, task.status, today)}
                    </span>
                }}
            </span>
            {if len(bits) > 0 {
                <span key="meta" className="truncate text-xs text-muted-foreground">
                    {" · ".join(bits)}
                </span>
            }}
        </button>;
}
