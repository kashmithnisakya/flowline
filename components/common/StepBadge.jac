"""A step as a solid pill (its kind glyph and name on the step's solid fill)
and the tinted bar a step group sits on. `color` is a key from
flowlines/kinds COLOR_KEYS; an unknown key renders slate.
"""

import from .KindGlyph { KindGlyph }

glob SOLID: dict[str, str] = {
         "sky": "bg-step-sky-solid [--kind-knockout:var(--step-sky-solid)]",
         "indigo": "bg-step-indigo-solid [--kind-knockout:var(--step-indigo-solid)]",
         "amber": "bg-step-amber-solid [--kind-knockout:var(--step-amber-solid)]",
         "rose": "bg-step-rose-solid [--kind-knockout:var(--step-rose-solid)]",
         "emerald": "bg-step-emerald-solid [--kind-knockout:var(--step-emerald-solid)]",
         "slate": "bg-step-slate-solid [--kind-knockout:var(--step-slate-solid)]"
     },
     WASH: dict[str, str] = {
         "sky": "bg-step-sky-wash",
         "indigo": "bg-step-indigo-wash",
         "amber": "bg-step-amber-wash",
         "rose": "bg-step-rose-wash",
         "emerald": "bg-step-emerald-wash",
         "slate": "bg-step-slate-wash"
     },
     INK: dict[str, str] = {
         "sky": "text-step-sky-ink",
         "indigo": "text-step-indigo-ink",
         "amber": "text-step-amber-ink",
         "rose": "text-step-rose-ink",
         "emerald": "text-step-emerald-ink",
         "slate": "text-step-slate-ink"
     };

def key(color: str) -> str {
    return color if color in SOLID else "slate";
}

# The tint behind a step's group header or row band.
def:pub stepWash(color: str) -> str {
    return WASH[key(color)];
}

# The step's solid fill, under --step-solid-fg text.
def:pub stepSolid(color: str) -> str {
    return SOLID[key(color)];
}

# Text in the step's ink, for counts and hints on its wash.
def:pub stepInk(color: str) -> str {
    return INK[key(color)];
}

def:pub StepBadge(
    name: str, color: str = "slate", kind: str = "", size: str = "md"
) -> JsxElement {
    tall = "h-8 px-3.5 text-[14px]" if size == "md" else "h-6 px-2.5 text-[12.5px]";
    return
        <span
            className={"inline-flex max-w-full min-w-0 shrink-0 items-center gap-1.5 rounded-full font-semibold whitespace-nowrap text-step-solid-fg shadow-xs "
                + tall
                + " "
                + SOLID[key(color)]}
        >
            {if kind {
                <KindGlyph key="glyph" kind={kind} size={13 if size == "md" else 11}/>
            }}
            <span className="truncate">{name}</span>
        </span>;
}
