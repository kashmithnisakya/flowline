"""A board row's title block: the step's status icon, the title with its High
flag, checklist count and category, and the red reason line under it when the
task is blocked or late."""

import from ...models { TaskRow }
import from ..common.StepBadge { StepIcon }
import from ..common.PriorityIcon { PriorityIcon }

def:pub TaskTitle(task: TaskRow, color: str, kind: str, alert: str) -> JsxElement {
    total = task.checklist_total;
    return
        <div
            className="flex min-w-0 flex-1 items-start gap-3 lg:col-span-2 lg:items-center"
        >
            <span className="mt-[3px] flex w-4 shrink-0 justify-center lg:mt-0">
                <StepIcon color={color} kind={kind} size={14}/>
            </span>
            <div className="flex min-w-0 flex-col gap-0.5">
                <div
                    className="flex min-w-0 flex-wrap items-center gap-x-2 gap-y-1 lg:flex-nowrap"
                >
                    <span
                        className={"min-w-0 text-[13.5px] leading-snug font-medium lg:truncate "
                            + (
                                "text-muted-foreground" if task.status == "Done" else ""
                            )}
                    >
                        {task.title}
                    </span>
                    {if task.priority == "High" {
                        <span
                            key="high"
                            title="High priority"
                            className="hidden shrink-0 lg:inline-flex"
                        >
                            <PriorityIcon priority="High"/>
                        </span>
                    }}
                    {if total > 0 {
                        <span
                            key="ck"
                            title={str(task.checklist_done)
                                + " of "
                                + str(total)
                                + " done"}
                            className="num hidden shrink-0 text-[12px] text-text-tertiary lg:inline"
                        >
                            {str(task.checklist_done) + "/" + str(total)}
                        </span>
                    }}
                    {if task.category {
                        <span
                            key="cat"
                            className="shrink-0 truncate text-[12px] text-text-tertiary"
                        >
                            {task.category}
                        </span>
                    }}
                </div>
                {if alert {
                    <span key="alert" className="text-[12.5px] text-destructive">
                        {alert}
                    </span>
                }}
            </div>
        </div>;
}
