"""A step's name with its colour as a 10px swatch beside it, the only place a
step colour appears. `color` is a key from flowlines/kinds COLOR_KEYS (an
unknown key renders slate); size and weight come from the call site.
"""

glob SWATCH_FILL: dict[str, str] = {
         "sky": "bg-step-sky",
         "indigo": "bg-step-indigo",
         "amber": "bg-step-amber",
         "rose": "bg-step-rose",
         "emerald": "bg-step-emerald",
         "slate": "bg-step-slate"
     };

def:pub StepName(name: str, color: str = "slate", className: str = "") -> JsxElement {
    fill = SWATCH_FILL[color] if color in SWATCH_FILL else SWATCH_FILL["slate"];
    return
        <span
            className={"inline-flex max-w-full min-w-0 items-center gap-1.5"
                + ((" " + className) if className else "")}
        >
            <span className={"step-swatch " + fill} aria-hidden="true"/>
            <span className="truncate">{name}</span>
        </span>;
}
