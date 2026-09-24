"""How much work sits on a step, on the step's wash in its ink: "4 open", or
"4 done" on a done step (its count is recent Done, not open work)."""

import from ..common.StepBadge { stepWash, stepInk }

def:pub CountChip(count: int, kind: str = "", color: str = "slate") -> JsxElement {
    return
        <span
            className={"num shrink-0 rounded-full px-1.5 text-xs leading-5 "
                + stepWash(color)
                + " "
                + stepInk(color)}
        >
            {str(count) + (" done" if kind == "done" else " open")}
        </span>;
}
