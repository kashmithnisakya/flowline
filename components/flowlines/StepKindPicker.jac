"""The inspector's kind chips and colour swatches. Only the picked kind shows the
step's colour on its icon; the swatches are the one place a colour is chosen."""

import from ...constants { STEP_KINDS }
import from .kinds { KIND_LABEL, KIND_HINT, COLOR_KEYS, DOT_FILL, colorKey }
import from ..common.StepBadge { StepIcon }

def:pub StepKindPicker(
    kind: str, color: str, onField: Callable[[str, str], None] = None
) -> JsxElement {
    tint = colorKey(color);
    return
        <>
            <div className="flex flex-col gap-1.5">
                <span className="text-[13px] font-medium" id="kind-label">Kind</span>
                <div
                    role="radiogroup"
                    aria-labelledby="kind-label"
                    className="flex flex-wrap gap-1.5"
                >
                    {for k in STEP_KINDS {
                        <button
                            key={k}
                            type="button"
                            role="radio"
                            aria-checked={kind == k}
                            className={"flex h-[26px] items-center gap-1.5 rounded-md border bg-card px-2 text-[12.5px] transition-colors "
                                + (
                                    "border-foreground font-medium"
                                        if kind == k
                                        else "border-border hover:bg-bg-hover"
                                )}
                            onClick={lambda { if onField { onField("kind", k); }}}
                        >
                            <StepIcon color={tint if kind == k else "slate"} kind={k}/>
                            {KIND_LABEL[k]}
                        </button>
                    }}
                </div>
                <p className="meta">
                    {(KIND_LABEL[kind] if kind in KIND_LABEL else "")
                        + ": "
                        + (KIND_HINT[kind] if kind in KIND_HINT else "")
                        + ". The kind is what the app understands; the name is yours."}
                </p>
            </div>
            <div className="flex flex-col gap-1.5">
                <span className="text-[13px] font-medium" id="color-label">Colour</span>
                <div
                    role="radiogroup"
                    aria-labelledby="color-label"
                    className="flex gap-2"
                >
                    {for c in COLOR_KEYS {
                        <button
                            key={c}
                            type="button"
                            role="radio"
                            aria-checked={tint == c}
                            aria-label={"orchid" if c == "rose" else c}
                            className={"size-6 rounded-sm "
                                + DOT_FILL[c]
                                + (
                                    " ring-2 ring-foreground ring-offset-2 ring-offset-card"
                                        if tint == c
                                        else ""
                                )}
                            onClick={lambda { if onField { onField("color", c); }}}
                        />
                    }}
                </div>
            </div>
        </>;
}
