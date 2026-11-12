"""A step card's muted rows under its name (geometry META_LH, 18px each): the
owner role, which the lane view leaves out because the lane says it, then how
much work sits there and what it takes to enter."""

import from ...models { StepView }
import from .kinds { ownerWord, nodeCount }

def:pub NodeMeta(step: StepView, showOwner: bool = True) -> JsxElement {
    return
        <span
            className="mt-0.5 flex min-w-0 flex-col text-xs leading-[18px] text-text-tertiary"
        >
            {if showOwner {
                <span key="owner" className="truncate">{ownerWord(step.owner)}</span>
            }}
            <span className="num truncate">{nodeCount(step)}</span>
        </span>;
}
