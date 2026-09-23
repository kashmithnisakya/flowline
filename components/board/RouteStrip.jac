"""The flow line above the board: every step as a node (swatch, name, count)
joined by wires in column order. A node whose lane is scrolled out of view is
dimmed, the open task's step wears the ring its card wears, and selecting a
node brings its lane in. On phones the same list is a row of step tabs, one
lane at a time."""

import from .MoveMenu { swatchFor }

def:pub RouteStrip(
    keys: list[str],
    labels: list[str],
    colors: list[str],
    counts: list[int],
    # Keys whose lane is mostly on screen, and the one most on screen.
    inView: list[str],
    active: str,
    # The step the open task sits in, ringed like its card ("" for none).
    current: str,
    # Lanes past the right edge, for the "N more steps" hint.
    hiddenAfter: int,
    onPick: Callable[[str], None],
    onMore: Callable[[], None],
    tabs: bool = False
) -> JsxElement {
    if tabs {
        return
            <div
                className="-mx-1 flex gap-1.5 overflow-x-auto px-1 pb-1"
                role="group"
                aria-label="Steps"
                data-step-tabs="true"
            >
                {for (i, key) in enumerate(keys) {
                    <button
                        key={key}
                        type="button"
                        data-step-tab={key}
                        aria-current={"true" if key == active else None}
                        className={"inline-flex shrink-0 items-center gap-1.5 rounded-md border bg-card px-2.5 py-1.5 text-[13px] whitespace-nowrap "
                            + (
                                "border-foreground font-semibold text-foreground"
                                    if key == active
                                    else "text-muted-foreground"
                            )}
                        onClick={lambda { onPick(key); }}
                    >
                        <span
                            className={"step-swatch " + swatchFor(colors[i])}
                            aria-hidden="true"
                        />
                        {labels[i]}
                        <span className="num text-xs font-medium text-subtle">
                            {counts[i]}
                        </span>
                    </button>
                }}
            </div>;
    }
    return
        <nav aria-label="Steps" className="flex min-w-0 items-center gap-3">
            <div className="flex min-w-0 flex-1 items-center overflow-x-auto py-0.5">
                {for (i, key) in enumerate(keys) {
                    if i > 0 {
                        <span
                            key={"w" + key}
                            aria-hidden="true"
                            className="relative h-0.5 w-[18px] shrink-0 bg-wire after:absolute after:-top-[3px] after:-right-px after:border-y-4 after:border-l-[6px] after:border-y-transparent after:border-l-wire after:content-['']"
                        />
                    }
                    <button
                        key={key}
                        type="button"
                        title={"Go to " + labels[i]}
                        aria-current={"step" if key == current and current else None}
                        className={"inline-flex shrink-0 items-center gap-[7px] rounded-md border px-2 py-1 text-[12.5px] font-semibold whitespace-nowrap transition-colors duration-150 "
                            + (
                                "bg-card text-foreground"
                                    if key in inView
                                    else "bg-transparent text-muted-foreground"
                            )
                            + (
                                " border-primary ring-1 ring-primary hover:border-primary"
                                    if key == current and current
                                    else " hover:border-input"
                            )}
                        onClick={lambda { onPick(key); }}
                    >
                        <span
                            className={"step-swatch " + swatchFor(colors[i])}
                            aria-hidden="true"
                        />
                        {labels[i]}
                        <span className="num text-xs font-medium text-subtle">
                            {counts[i]}
                        </span>
                    </button>
                }}
            </div>
            {if hiddenAfter > 0 {
                <button
                    key="more"
                    type="button"
                    className="inline-flex shrink-0 items-center gap-1 rounded-sm text-[12.5px] text-muted-foreground hover:text-foreground"
                    onClick={lambda { onMore(); }}
                >
                    {str(hiddenAfter)
                        + (" more step" if hiddenAfter == 1 else " more steps")}
                    <svg width={14} height={14} viewBox="0 0 16 16" aria-hidden="true">
                        <path
                            d="M3 8h9.5M9 4.5 12.5 8 9 11.5"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth={1.6}
                            strokeLinecap="round"
                            strokeLinejoin="round"
                        />
                    </svg>
                </button>
            }}
        </nav>;
}
