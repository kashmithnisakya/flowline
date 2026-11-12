"""One AI run in the task sheet, as a card. Dashed while it is working or wants
an answer, an ordinary solid card once settled, with the review on GitHub and
Retry or Cancel when they apply."""

import from ...constants { AGENT_LIMITS }
import from ...models { AgentRunView }
import from ..common.AiMark { AiMark }
import from ..ui.button { Button }

def plural(n: int, word: str) -> str {
    return str(n) + " " + word + ("" if n == 1 else "s");
}

# The word beside the responsibility's name.
def:pub runStatus(run: AgentRunView) -> str {
    if run.status == "queued" {
        return "Retrying" if run.attempts > 0 else "Queued";
    }
    if run.status == "running" {
        return "Reviewing";
    }
    if run.status == "done" {
        return "Changes requested" if run.verdict == "request_changes" else "Commented";
    }
    return run.status[:1].upper() + run.status[1:];
}

# The line under the title: findings once done, else what it is doing or why not.
def:pub runLine(run: AgentRunView) -> str {
    if run.status == "done" {
        found = plural(run.comments, "comment");
        return found
            + (", " + str(run.blocking) + " blocking" if run.blocking > 0 else "");
    }
    if run.status == "queued" and run.attempts > 0 {
        return "Attempt "
            + str(run.attempts + 1)
            + " of "
            + str(AGENT_LIMITS["max_attempts"])
            + ". "
            + (run.error or "The last try failed.");
    }
    if run.status == "queued" {
        return "PR #" + str(run.pr_number) + " is next in line.";
    }
    if run.status == "running" {
        return "Reading PR #" + str(run.pr_number) + ".";
    }
    return run.error;
}

def:pub AgentRunRow(
    run: AgentRunView,
    name: str,
    busy: bool,
    onRetry: Callable[[str], None],
    onCancel: Callable[[str], None]
) -> JsxElement {
    live = run.status == "queued" or run.status == "running";
    again = run.status in ["failed", "skipped", "cancelled"];
    return
        <li
            data-run={run.status}
            className={"ai-card text-[13px]"
                if live
                else "flex flex-col gap-2 rounded-xl border bg-card p-3 text-[13px]"}
        >
            <div className="flex min-w-0 items-center gap-2 font-semibold">
                <AiMark running={run.status == "running"}/>
                {name}
                <span
                    className={"ml-auto text-[12.5px] font-normal "
                        + (
                            "text-danger"
                                if run.status == "failed"
                                else "text-text-secondary"
                        )}
                >
                    {runStatus(run)}
                </span>
            </div>
            <p
                className={"font-medium"
                    if run.status == "done"
                    else "text-text-secondary"}
            >
                {runLine(run)}
            </p>
            {if run.status == "done" and run.summary {
                <p key="sum" className="break-words text-text-secondary">
                    {run.summary}
                </p>
            }}
            <div className="flex items-center gap-2">
                {if run.review_url {
                    <a
                        key="link"
                        href={run.review_url}
                        target="_blank"
                        rel="noreferrer"
                        className="text-[12.5px] text-text-secondary underline underline-offset-2 hover:text-text-primary"
                    >
                        View on GitHub
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
                        className="ml-auto"
                        disabled={busy}
                        onClick={lambda { onCancel(run.id); }}
                    >
                        Cancel
                    </Button>
                }}
            </div>
        </li>;
}
