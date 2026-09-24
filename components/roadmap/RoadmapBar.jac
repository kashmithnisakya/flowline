"""One task's pill across the weeks, in its step's solid colour. Past due
turns it red, Done fades it, and a blocked task carries a diagonal hatch.
A side clipped by the window stays square; `win` is Timeline's window."""

import from .span { spanStyle }

glob HATCH: str = "repeating-linear-gradient(135deg, color-mix(in oklab, var(--background) 55%, transparent) 0 2px, transparent 2px 6px)";

def:pub RoadmapBar(
    first: str,
    last: str,
    win: dict[str, any],
    color: str,
    late: bool = False,
    done: bool = False,
    blocked: bool = False
) -> JsxElement {
    css = spanStyle(first, last, win["origin"], win["total"]);
    if done {
        css["backgroundColor"] = "var(--muted)";
    } elif late {
        css["backgroundColor"] = "var(--destructive)";
    } else {
        css["backgroundColor"] = "var(--step-" + color + "-solid)";
    }
    if blocked and not done {
        css["backgroundImage"] = HATCH;
    }
    edges = ("rounded-l-full " if first >= win["fromDate"] else "")
        + ("rounded-r-full" if last <= win["lastDay"] else "");
    return
        <span
            className={"pointer-events-none absolute top-1/2 h-4 -translate-y-1/2 "
                + ("border border-border " if done else "")
                + edges}
            style={css}
            aria-hidden="true"
        />;
}
