"""One line of the AI page's activity: the mark, the task and its pull request,
what the run came to, when, and the one action that applies."""

import from "@jac/runtime" { Link }
import from ...models { AgentRunLine }
import from ...lib.dates { prettyDay }
import from ..board.AgentRunRow { runStatus, runLine }
import from ..common.AiMark { AiMark }
import from ..common.CommandPalette { PageIcon }
import from ..ui.button { Button }

def:pub RunLine(
    run: AgentRunLine,
    busy: bool,
    onRetry: Callable[[str], None],
    onCancel: Callable[[str], None]
) -> JsxElement {
    live = run.status == "queued" or run.status == "running";
    again = run.status in ["failed", "skipped", "cancelled"];
    where = " · ".join(
        [
            part
            for part in [run.project_name, "PR #" + str(run.pr_number)]
            if part
        ]
    );
    return
        <li
            className="flex flex-wrap items-center gap-x-3 gap-y-1 border-b px-4 py-2 last:border-b-0"
        >
            <AiMark running={run.status == "running"}/>
            <div className="min-w-0 flex-[1_1_240px]">
                {if run.task_title {
                    <Link
                        key="task"
                        to={"/board?task=" + run.task_id}
                        className="block truncate text-[13.5px] font-medium hover:underline"
                    >
                        {run.task_title}
                    </Link>
                } else {
                    <span
                        key="gone"
                        className="block truncate text-[13.5px] text-text-tertiary"
                    >
                        Deleted task
                    </span>
                } }
                <p className="truncate text-[12.5px] text-text-tertiary">
                    {where + (" · " + runLine(run) if not live else "")}
                </p>
            </div>
            <span
                className={"w-32 shrink-0 text-[12.5px] "
                    + (
                        "text-danger"
                            if run.status == "failed"
                            else "text-text-secondary"
                    )}
            >
                {runStatus(run)}
            </span>
            <span
                className="num w-14 shrink-0 text-right text-[12px] text-text-tertiary"
            >
                {prettyDay(run.queued_at[:10])}
            </span>
            <span className="flex w-24 shrink-0 justify-end">
                {if run.review_url {
                    <a
                        key="gh"
                        href={run.review_url}
                        target="_blank"
                        rel="noreferrer"
                        className="inline-flex items-center gap-1 text-[12.5px] text-text-secondary underline underline-offset-2 hover:text-text-primary"
                    >
                        <PageIcon name="github" size={13}/>
                        On GitHub
                    </a>
                }}
                {if again {
                    <Button
                        key="retry"
                        size="xs"
                        variant="outline"
                        disabled={busy}
                        onClick={lambda { onRetry(run.id); }}
                    >
                        Retry
                    </Button>
                }}
                {if live {
                    <Button
                        key="cancel"
                        size="xs"
                        variant="ghost"
                        disabled={busy}
                        onClick={lambda { onCancel(run.id); }}
                    >
                        Cancel
                    </Button>
                }}
            </span>
        </li>;
}
