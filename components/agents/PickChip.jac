"""A toggle chip: square, sentence case, a tick when picked. One look for every
choice in the agent dialog and the canvas inspector."""

import from ..workspace.icons { IconCheck }

def:pub PickChip(
    label: str,
    on: bool,
    onClick: Callable[[], None],
    hint: str = "",
    disabled: bool = False
) -> JsxElement {
    return
        <button
            type="button"
            aria-pressed={on}
            title={hint}
            disabled={disabled}
            className={"inline-flex h-7 items-center gap-1.5 rounded-sm border px-2 text-[13px] transition-colors duration-150 disabled:opacity-50 "
                + (
                    "border-foreground bg-card font-semibold text-foreground"
                        if on
                        else "border-border text-muted-foreground hover:bg-accent hover:text-foreground"
                )}
            onClick={lambda { onClick(); }}
        >
            {if on {
                <IconCheck key="tick" size={12}/>
            }}
            <span>{label}</span>
        </button>;
}
