"""The row's AI chip: what an open run is doing, or what the last review came
to. Dashed while it wants attention, solid once it is settled."""

import from ...models { TaskRow }
import from ..common.AiMark { AiMark }

def plural(n: int, word: str) -> str {
    return str(n) + " " + word + ("" if n == 1 else "s");
}

def:pub AiChip(task: TaskRow) -> JsxElement {
    if task.ai_state == "running" {
        return
            <span className="ai-chip" title="An AI review is running">
                <AiMark running={True}/>
                Reviewing
            </span>;
    }
    if task.ai_state == "queued" {
        return
            <span className="ai-chip" title="An AI review is queued">
                <AiMark/>
                Queued
            </span>;
    }
    if task.ai_outcome == "changes" {
        return
            <span className="ai-chip" title="The AI review requested changes">
                <AiMark/>
                {str(task.ai_blocking) + " blocking"
                    if task.ai_blocking > 0
                    else "Changes requested"}
            </span>;
    }
    if task.ai_outcome == "failed" {
        return
            <span
                className="ai-chip ai-chip-settled text-danger!"
                title="The AI review failed"
            >
                <AiMark/>
                Failed
            </span>;
    }
    if task.ai_outcome == "reviewed" {
        return
            <span className="ai-chip ai-chip-settled" title="The AI review is done">
                <AiMark/>
                {plural(task.ai_comments, "comment")
                    if task.ai_comments > 0
                    else "Reviewed"}
            </span>;
    }
    return <span hidden={True}/>;
}
