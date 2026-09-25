"""How much work sits on a step: "4 open", or "4 done" on a done step (its
count is recent Done, not open work). Neutral: the step's colour is carried
by its icon, not by a tinted chip."""

def:pub CountChip(count: int, kind: str = "", color: str = "slate") -> JsxElement {
    return
        <span
            className="num shrink-0 rounded-md bg-bg-surface px-1.5 text-xs leading-5 text-text-secondary"
        >
            {str(count) + (" done" if kind == "done" else " open")}
        </span>;
}
