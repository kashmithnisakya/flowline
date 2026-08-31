"""GitHub state on a kanban card: the linked issue, its PR, and the nudge. A
merged PR only ever *suggests* Done; the board never moves a card on its own.
"""

import from ...models { TaskView }
import from ..ui.badge { Badge }
import from ..ui.button { Button }

# Merged and closed mean opposite things on GitHub, so they never share a
# tint. Anything unrecognised falls back to the neutral outline.
glob PR_TINT: dict[str, str] = {
         "open": "border-success/40 bg-success/10 text-success",
         "draft": "border-border bg-muted text-muted-foreground",
         "merged": "border-primary/40 bg-primary/10 text-primary",
         "closed": "border-destructive/40 bg-destructive/10 text-destructive"
     },
     SUGGEST_STATUSES: list[str] = ["In Progress", "Review"];

# Columns where "the PR merged" is news. A card already in Done or Backlog
# does not need telling.
def:pub GitHubChip(task: TaskView, onMarkDone: Callable[[str], None]) -> JsxElement {
    issueTint = (
        "border-border bg-muted/60 text-muted-foreground line-through"
            if task.gh_issue_state == "closed"
            else "border-border bg-card text-foreground hover:bg-accent"
    );
    prLabel = "PR " + task.pr_state;
    prTitle = (
        (task.gh_repo + " #" + str(task.pr_number)) if task.pr_number > 0 else prLabel
    );
    suggestDone = task.pr_state == "merged" and task.status in SUGGEST_STATUSES;

    return
        <div className="space-y-1.5">
            <div className="flex flex-wrap items-center gap-1">
                {if task.gh_issue_number > 0 {
                    <a
                        key="issue"
                        href={task.issue_link}
                        target="_blank"
                        rel="noreferrer"
                        title={task.gh_repo + " #" + str(task.gh_issue_number)}
                        # The card itself opens the task dialog on click.
                        onClick={lambda (e: MouseEvent) { e.stopPropagation(); }}
                        className={"inline-flex h-5 items-center rounded-full border px-2 text-xs font-medium transition-colors "
                            + issueTint}
                    >
                        {"#" + str(task.gh_issue_number)}
                    </a>
                }}
                {if task.pr_state {
                    <Badge
                        key="pr"
                        variant="outline"
                        title={prTitle}
                        className={PR_TINT.get(
                            task.pr_state, "border-border bg-card text-muted-foreground"
                        )
                            + " h-5 rounded-full"}
                    >
                        {prLabel}
                    </Badge>
                }}
                {if task.gh_sub_total > 0 {
                    <Badge
                        key="family"
                        variant="outline"
                        title={"Sub-issues: "
                            + str(task.gh_sub_done)
                            + " of "
                            + str(task.gh_sub_total)
                            + " done"}
                        className={(
                            "border-success/40 bg-success/10 text-success"
                                if task.gh_sub_done == task.gh_sub_total
                                else "border-primary/40 bg-primary/10 text-primary"
                        )
                            + " h-5 rounded-full tabular-nums"}
                    >
                        {"⌗ " + str(task.gh_sub_done) + "/" + str(task.gh_sub_total)}
                    </Badge>
                }}
                {if task.gh_parent_number > 0 {
                    <Badge
                        key="parent"
                        variant="outline"
                        title={"Part of "
                            + task.gh_parent_repo
                            + " #"
                            + str(task.gh_parent_number)}
                        className="h-5 rounded-full border-border bg-card text-muted-foreground"
                    >
                        {"↳ #" + str(task.gh_parent_number)}
                    </Badge>
                }}
            </div>
            {if suggestDone {
                <div
                    key="suggest"
                    className="flex items-center justify-between gap-2 rounded-md border border-primary/30 bg-primary/5 px-2 py-1 text-xs"
                >
                    <span className="text-muted-foreground">PR merged.</span>
                    <Button
                        variant="ghost"
                        size="xs"
                        onClick={lambda (e: MouseEvent) {
                            e.stopPropagation();
                            onMarkDone(task.id);
                        }}
                    >
                        Mark done
                    </Button>
                </div>
            }}
        </div>;
}
