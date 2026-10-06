"""A board row's title block: the step-coloured bullet, the title with its
category and a Blocked pill, and the red reason line under it when the task
is blocked or late."""

import from ...models { TaskRow }

def:pub TaskTitle(task: TaskRow, dot: str, alert: str) -> JsxElement {
    blocked = task.status == "Blocked";
    return
        <div className="flex min-w-0 flex-1 items-start gap-3 lg:col-span-2">
            <span
                aria-hidden="true"
                className={"mt-[7px] size-2 shrink-0 rounded-full " + dot}
            />
            <div className="flex min-w-0 flex-col gap-0.5">
                <div className="flex min-w-0 flex-wrap items-center gap-x-2 gap-y-1">
                    <span
                        className={"min-w-0 text-sm leading-snug font-medium lg:truncate "
                            + (
                                "text-muted-foreground" if task.status == "Done" else ""
                            )}
                    >
                        {task.title}
                    </span>
                    {if task.category {
                        <span
                            key="cat"
                            className="shrink-0 rounded-full bg-muted px-2 py-px text-xs text-muted-foreground"
                        >
                            {task.category}
                        </span>
                    }}
                    {if blocked {
                        <span
                            key="blocked"
                            className="shrink-0 rounded-full bg-destructive/10 px-2 py-px text-xs font-semibold text-destructive"
                        >
                            Blocked
                        </span>
                    }}
                </div>
                {if alert {
                    <span key="alert" className="text-[13px] text-destructive">
                        {alert}
                    </span>
                }}
            </div>
        </div>;
}
