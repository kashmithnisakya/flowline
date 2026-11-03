"""The roadmap's toolbar: back to this week, a step earlier or later and the
weeks on screen; on the right what is scheduled and a note of what has no
dates, linking to the board, where dates are set. It wraps on a phone."""

import from "@jac/runtime" { Link }
import from ..common.Busy { Busy }
import from ..ui.button { Button }
import from ..common.Chevron { Chevron }

def:pub RoadmapToolbar(
    rangeLabel: str,
    onEarlier: Callable[[], None],
    onToday: Callable[[], None],
    onLater: Callable[[], None],
    summary: str = "",
    # Open tasks with no dates, so they are not on the timeline.
    undated: int = 0,
    # A refetch is in flight behind the rows on screen.
    busy: bool = False
) -> JsxElement {
    undatedText = "1 task has no dates"
        if undated == 1
        else str(undated) + " tasks have no dates";
    return
        <div className="toolbar">
            <div
                className="flex items-center gap-1"
                role="group"
                aria-label="Weeks shown"
            >
                <Button
                    variant="outline"
                    size="sm"
                    className="h-[30px]"
                    onClick={lambda { onToday(); }}
                >
                    Today
                </Button>
                <Button
                    variant="ghost"
                    size="icon-sm"
                    className="size-[30px]"
                    aria-label="Earlier weeks"
                    onClick={lambda { onEarlier(); }}
                >
                    <Chevron facing="left"/>
                </Button>
                <Button
                    variant="ghost"
                    size="icon-sm"
                    className="size-[30px]"
                    aria-label="Later weeks"
                    onClick={lambda { onLater(); }}
                >
                    <Chevron facing="right"/>
                </Button>
            </div>
            <span className="meta num" aria-live="polite">{rangeLabel}</span>
            <Busy active={busy}/>
            <div className="ml-auto flex flex-wrap items-center gap-x-3 gap-y-1">
                {if summary {
                    <span key="sum" className="meta num">{summary}</span>
                }}
                {if undated > 0 {
                    <Link
                        key="undated"
                        to="/board"
                        title="Dates are set in the task sheet on the board"
                        className="meta underline decoration-border-strong underline-offset-[3px] hover:text-text-primary"
                    >
                        {undatedText}
                    </Link>
                }}
            </div>
        </div>;
}
