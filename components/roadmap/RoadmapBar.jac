"""One task's bar across the weeks, neutral: a step's colour stays on its icon.
Past due is outlined in danger, Done fades, and a blocked task carries a hatch.
A side clipped by the window stays square; `who` is the bar's words; `win` is
Timeline's window."""

import from .span { spanStyle }

glob HATCH: str = "repeating-linear-gradient(135deg, var(--border-strong) 0 1px, transparent 1px 5px)",
     TONE: dict[str, str] = {
         "late": "border-danger bg-transparent text-danger",
         "done": "border-border-subtle bg-bg-surface text-text-tertiary",
         "open": "border-border-strong bg-bg-selected text-text-primary"
     };

def:pub RoadmapBar(
    first: str,
    last: str,
    win: dict[str, any],
    who: str = "",
    late: bool = False,
    done: bool = False,
    blocked: bool = False
) -> JsxElement {
    css = spanStyle(first, last, win["origin"], win["total"]);
    if blocked and not done {
        css["backgroundImage"] = HATCH;
    }
    tone = "done" if done else ("late" if late else "open");
    edges = ("rounded-l-[5px] " if first >= win["fromDate"] else "")
        + ("rounded-r-[5px] " if last <= win["lastDay"] else "");
    return
        <span
            className={"pointer-events-none absolute top-[6px] flex h-5 items-center border px-[7px] text-xs "
                + edges
                + TONE[tone]}
            style={css}
            aria-hidden="true"
        >
            <span className="truncate">{who}</span>
        </span>;
}
