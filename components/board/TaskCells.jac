"""A board row's data cells from lg up: people, due date, the GitHub number and
the AI chip, on the same grid as the column heads."""

import from ...models { TaskRow }
import from ..common.Avatar { AvatarStack }
import from .GitHubChip { ghNumber, ghHref }
import from .taskFacts { dueWords, isLate }
import from .AiChip { AiChip }

# The row grid: glyph, title, the four cells, the move button. The widths are
# --row-cols (styles/global.css), which ColumnHeads resizes.
glob:pub GROUP_COLUMNS: str = "grid-cols-(--row-cols)",
     # The same grid from lg up, written out whole so Tailwind generates it.
     ROW_COLUMNS: str = "lg:grid-cols-(--row-cols)";

def:pub TaskCells(task: TaskRow, today: str) -> JsxElement {
    num = ghNumber(task);
    due = dueWords(task.due_date, task.status, today);
    return
        <>
            <span data-col="0" className="flex min-w-0 items-center">
                {if len(task.assignee_names) > 0 {
                    <AvatarStack key="who" names={task.assignee_names}/>
                } else {
                    <span key="none" className="text-xs text-subtle">Nobody</span>
                } }
            </span>
            <span
                data-col="1"
                className={"num truncate text-[12px] "
                    + (
                        "font-medium text-danger"
                            if isLate(task, today)
                            else (
                                "font-medium text-text-primary"
                                    if due == "Today"
                                    else "text-text-secondary"
                            )
                    )}
            >
                {due}
            </span>
            <span data-col="2" className="min-w-0 truncate">
                {if num > 0 {
                    <a
                        key="gh"
                        href={ghHref(task)}
                        target="_blank"
                        rel="noreferrer"
                        tabIndex={-1}
                        draggable={False}
                        className={"num text-[12px] text-text-tertiary hover:text-text-primary hover:underline"
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
            <span data-col="3" className="flex min-w-0 items-center">
                <AiChip task={task}/>
            </span>
        </>;
}
