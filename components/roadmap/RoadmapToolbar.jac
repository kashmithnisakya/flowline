"""The roadmap's toolbar: the weeks on screen and pills to step them
earlier, back to this week, or later. It wraps on a phone."""

import from ..common.Busy { Busy }
import from ..ui.button { Button }
import from ..common.Chevron { Chevron }

glob PILL: str = "h-8 rounded-full px-3",
     ROUND: str = "size-8 rounded-full";

def:pub RoadmapToolbar(
    rangeLabel: str,
    onEarlier: Callable[[], None],
    onToday: Callable[[], None],
    onLater: Callable[[], None],
    # A refetch is in flight behind the rows on screen.
    busy: bool = False
) -> JsxElement {
    return
        <div className="flex flex-wrap items-center gap-2">
            <Busy active={busy}/>
            <span className="meta num whitespace-nowrap" aria-live="polite">
                {rangeLabel}
            </span>
            <div
                className="flex items-center gap-1"
                role="group"
                aria-label="Weeks shown"
            >
                <Button
                    variant="outline"
                    size="icon-sm"
                    className={ROUND}
                    aria-label="Earlier weeks"
                    title="Earlier weeks"
                    onClick={lambda { onEarlier(); }}
                >
                    <Chevron facing="left"/>
                </Button>
                <Button
                    variant="outline"
                    size="sm"
                    className={PILL}
                    onClick={lambda { onToday(); }}
                >
                    Today
                </Button>
                <Button
                    variant="outline"
                    size="icon-sm"
                    className={ROUND}
                    aria-label="Later weeks"
                    title="Later weeks"
                    onClick={lambda { onLater(); }}
                >
                    <Chevron facing="right"/>
                </Button>
            </div>
        </div>;
}
