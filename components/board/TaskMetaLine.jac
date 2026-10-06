"""A board row's facts on one muted line below lg, where the cells do not
fit: due date, a High flag, the checklist and the GitHub number, with the
people at the end."""

import from ...models { TaskRow }
import from ..common.Avatar { AvatarStack }
import from .GitHubChip { ghNumber }
import from .taskFacts { dueWords, isLate }

def:pub TaskMetaLine(task: TaskRow, today: str) -> JsxElement {
    parts: list[str] = [];
    if task.priority == "High" {
        parts.append("High");
    }
    if task.checklist_total > 0 {
        parts.append(str(task.checklist_done) + "/" + str(task.checklist_total));
    }
    num = ghNumber(task);
    if num > 0 {
        parts.append("#" + str(num));
    }
    due = dueWords(task.due_date, task.status, today);
    return
        <div className="flex min-w-0 items-center gap-2 pl-5 text-[13px] lg:hidden">
            {if due {
                <span
                    key="due"
                    className={"shrink-0 "
                        + (
                            "font-medium text-destructive"
                                if isLate(task, today)
                                else "text-foreground"
                        )}
                >
                    {due}
                </span>
            }}
            <span className="min-w-0 flex-1 truncate text-muted-foreground">
                {" · ".join(parts)}
            </span>
            {if len(task.assignee_names) > 0 {
                <AvatarStack key="who" names={task.assignee_names}/>
            }}
        </div>;
}
