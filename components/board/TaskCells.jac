"""A board row's data cells from lg up, in GROUP_COLUMNS order: people,
priority, checklist, due date and the linked GitHub number."""

import from ...models { TaskRow }
import from ..common.Avatar { AvatarStack }
import from ..common.PriorityIcon { PriorityIcon }
import from ..common.ProgressRing { ProgressRing }
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
            <span className="flex items-center" title={task.priority + " priority"}>
                <PriorityIcon priority={task.priority}/>
            </span>
            <span className="flex items-center gap-2">
                {if total > 0 {
                    <span
                        key="ring"
                        className="flex items-center gap-1.5"
                        title={str(done) + " of " + str(total) + " done"}
                    >
                        <ProgressRing done={done} total={total}/>
                        <span className="num text-[12px] text-text-tertiary">
                            {str(done) + "/" + str(total)}
                        </span>
                    </span>
                }}
            </span>
            <span
                className={"num truncate text-[12px] "
                    + (
                        "font-medium text-danger"
                            if late
                            else (
                                "font-medium text-text-primary"
                                    if due == "Today"
                                    else "text-text-secondary"
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
        </>;
}
