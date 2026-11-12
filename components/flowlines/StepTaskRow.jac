"""One task on a step's sheet: title, priority, assignees and due date. The whole
row is a button that opens the board's task sheet."""

import from ...models { TaskRow }
import from ...lib.dates { dueTone, dueLabel, prettyDay }
import from ..common.Avatar { AvatarStack }
import from ..common.PriorityIcon { PriorityIcon }

# Due text by urgency, the same three tones the board row uses.
glob DUE_TINT: dict[str, str] = {
         "overdue": "text-danger",
         "soon": "text-warning",
         "": "text-text-tertiary"
     };

def:pub StepTaskRow(
    task: TaskRow, today: str, onOpen: Callable[[str], None] = None
) -> JsxElement {
    return
        <button
            type="button"
            className="-mx-2 flex min-h-9 w-[calc(100%+1rem)] items-center gap-2.5 rounded-md px-2 py-1.5 text-left transition-colors duration-150 hover:bg-bg-hover focus-visible:bg-bg-hover"
            onClick={lambda { if onOpen { onOpen(task.id); }}}
        >
            <span className="min-w-0 flex-1 text-[13px] leading-5">{task.title}</span>
            {if task.priority {
                <PriorityIcon key="prio" priority={task.priority}/>
            }}
            {if len(task.assignee_names) > 0 {
                <AvatarStack key="who" names={task.assignee_names}/>
            }}
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
        </button>;
}
