"""A step group's header as the board draws it: a bar tinted in the step
colour holding the step as a solid badge and its task count."""

import from ..common.StepBadge { StepBadge, stepWash, stepInk }

def:pub DemoHeader(name: str, color: str, kind: str, count: int) -> JsxElement {
    return
        <div
            className={"flex min-h-11 items-center gap-2.5 rounded-2xl px-2 py-1.5 "
                + stepWash(color)}
        >
            <StepBadge name={name} color={color} kind={kind} size="sm"/>
            <span className={"text-sm font-semibold " + stepInk(color)}>
                {str(count)}
            </span>
        </div>;
}
