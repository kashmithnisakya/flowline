"""A board row's data cells from lg up, in GROUP_COLUMNS order: people,
priority, checklist, due date and the linked GitHub number."""

import from ...models { TaskRow }
import from ..common.Avatar { AvatarStack }
import from .GitHubChip { ghNumber, ghHref }
import from .taskFacts { dueWords, isLate }

# The row grid: glyph, title, the five cells, the move button.
glob:pub GROUP_COLUMNS: str = "grid-cols-[28px_minmax(0,1fr)_104px_76px_112px_104px_84px_40px]",
     # The same grid from lg up, written out whole so Tailwind generates it.
     ROW_COLUMNS: str = "lg:grid-cols-[28px_minmax(0,1fr)_104px_76px_112px_104px_84px_40px]";

def:pub TaskCells(task: TaskRow, today: str, color: str) -> JsxElement {
    total = task.checklist_total;
    done = task.checklist_done;
    num = ghNumber(task);
    late = isLate(task, today);
    due = dueWords(task.due_date, task.status, today);
    return
        <>
            <span className="flex min-w-0 items-center">
                {if len(task.assignee_names) > 0 {
                    <AvatarStack key="who" names={task.assignee_names}/>
                } else {
                    <span key="none" className="text-xs text-subtle">Nobody</span>
                } }
            </span>
            <span
                className={"text-[13px] "
                    + (
                        "font-medium text-destructive"
                            if task.priority == "High"
                            else "text-muted-foreground"
                    )}
            >
                {task.priority}
            </span>
            <span className="flex items-center gap-2">
                {if total > 0 {
                    <span
                        key="bar"
                        className="h-1.5 w-12 overflow-hidden rounded-full bg-muted"
                        title={str(done) + " of " + str(total) + " done"}
                    >
                        <span
                            className={"block h-full rounded-full " + color}
                            style={{"width": str(int(100 * done / total)) + "%"}}
                        />
                    </span>
                }}
                {if total > 0 {
                    <span key="n" className="num text-xs text-muted-foreground">
                        {str(done) + "/" + str(total)}
                    </span>
                }}
            </span>
            <span
                className={"truncate text-[13px] "
                    + (
                        "font-medium text-destructive"
                            if late
                            else (
                                "font-medium"
                                    if due == "Today"
                                    else "text-muted-foreground"
                            )
                    )}
            >
                {due}
            </span>
            <span className="min-w-0 truncate">
                {if num > 0 {
                    <a
                        key="gh"
                        href={ghHref(task)}
                        target="_blank"
                        rel="noreferrer"
                        tabIndex={-1}
                        draggable={False}
                        className={"num text-xs text-muted-foreground hover:text-foreground hover:underline"
                            + (
                                " line-through"
                                    if task.gh_issue_state == "closed"
                                    else ""
                            )}
                        onClick={lambda (e: MouseEvent) { e.stopPropagation(); }}
                    >
                        {(
                            "PR #"
                                if task.gh_issue_number == 0 and task.pr_number > 0
                                else "#"
                        )
                            + str(num)}
                    </a>
                }}
            </span>
        </>;
}
