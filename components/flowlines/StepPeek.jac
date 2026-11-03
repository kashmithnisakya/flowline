"""What sits on a step in its edit sheet: the count and first titles the line
already carries, so selecting a step in Edit makes no request."""

import from ...models { StepView }

def:pub StepPeek(step: StepView) -> JsxElement {
    more = step.task_count - len(step.task_titles);
    return
        <section aria-label="Tasks on this step" className="flex flex-col gap-1.5">
            <div className="flex items-baseline justify-between">
                <h3 className="text-[13px] font-semibold">Tasks</h3>
                <span className="num text-xs text-text-tertiary">
                    {str(step.task_count)}
                </span>
            </div>
            {if step.task_count == 0 {
                <p key="none" className="meta">Nothing is sitting on this step.</p>
            }}
            {for tt in step.task_titles {
                <p key={tt} className="truncate text-[13px]">{tt}</p>
            }}
            {if more > 0 {
                <p key="more" className="meta">{str(more) + " more"}</p>
            }}
        </section>;
}
