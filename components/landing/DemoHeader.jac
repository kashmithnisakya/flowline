"""A step group's header as the board draws it: the step's status icon and
name on a plain surface, with its task count."""

import from ..common.StepBadge { StepBadge }

def:pub DemoHeader(name: str, color: str, kind: str, count: int) -> JsxElement {
    return
        <div className="flex h-9 items-center gap-2 rounded-md bg-bg-surface px-2">
            <StepBadge name={name} color={color} kind={kind} size="sm"/>
            <span className="num text-[13px] text-text-tertiary">{str(count)}</span>
        </div>;
}
