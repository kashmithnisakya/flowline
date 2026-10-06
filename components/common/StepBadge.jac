"""A step as its kind glyph in the step's colour, plus its name in plain text.

Colour is information here, not decoration. The glyph carries the step's
colour at icon size and its shape carries the kind, so meaning never rides on
colour alone. There is no pill, no solid fill and no tinted band: a step used
to render as a solid rounded-full badge sitting on a washed bar, which made
colour the loudest thing on the board and left every group looking urgent.

`color` is a key from flowlines/kinds COLOR_KEYS; an unknown key renders slate.
"""

import from .KindGlyph { KindGlyph }

glob ICON: dict[str, str] = {
         "sky": "text-step-sky",
         "indigo": "text-step-indigo",
         "amber": "text-step-amber",
         "rose": "text-step-rose",
         "emerald": "text-step-emerald",
         "slate": "text-step-slate"
     };

def key(color: str) -> str {
    return color if color in ICON else "slate";
}


# The step's colour, for its glyph and nothing larger.
def:pub stepIcon(color: str) -> str {
    return ICON[key(color)];
}


# A step's glyph on its own, at icon size, in the step's colour.
def:pub StepIcon(
    color: str = "slate", kind: str = "start", size: int = 14
) -> JsxElement {
    return <KindGlyph kind={kind or "start"} size={size} className={stepIcon(color)}/>;
}


def:pub StepBadge(
    name: str, color: str = "slate", kind: str = "", size: str = "md"
) -> JsxElement {
    px = 14 if size == "md" else 12;
    text = "text-[13px]" if size == "md" else "text-[12px]";
    return
        <span
            className={"inline-flex max-w-full min-w-0 items-center gap-1.5 font-medium whitespace-nowrap "
                + text}
        >
            <StepIcon color={color} kind={kind or "start"} size={px}/>
            <span className="truncate">{name}</span>
        </span>;
}
