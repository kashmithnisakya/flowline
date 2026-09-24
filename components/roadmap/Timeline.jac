"""The roadmap grid: month and week rows, then one group per step in the
board's column order. Positions are percentages of the window, so the grid
scrolls sideways when it is narrow; a phone opens with today in view."""

import from "react" { useEffect }
import from ...lib.session { ROADMAP_SHAPE_KEY }
import from .span { dayNumber, isoOfDay, pct }
import from .LabelCell { LABEL_OFFSET }
import from .RoadmapAxis { RoadmapAxis }
import from .RoadmapGroup { RoadmapGroup }
import from .RoadmapSkeleton { RoadmapSkeleton }

def:pub RoadmapTimeline(
    fromDate: str,
    weeks: int,
    today: str,
    # Step groups from the page (see RoadmapGroup), empty ones left out.
    groups: list[dict[str, any]],
    onOpen: Callable[[str], None],
    # The first load: skeleton groups shaped like the last visit.
    placeholder: int = 0
) -> JsxElement {
    has scroller: Ref[any] = Ref();

    origin = dayNumber(fromDate);
    total = weeks * 7;
    lastDay = isoOfDay(origin + total - 1);
    todayFrac = (dayNumber(today) - origin + 0.5) * 1.0 / total;
    showToday = today >= fromDate and today <= lastDay;
    win: dict[str, any] = {
        "origin": origin,
        "total": total,
        "fromDate": fromDate,
        "lastDay": lastDay,
        "today": today,
        "showToday": showToday,
        "todayLeft": str(todayFrac * 100.0) + "%"
    };
    shape = ",".join([str(len(g["items"])) for g in groups]);

    # Keep the groups' shape for the next first-load frame.
    useEffect(
        lambda { if placeholder == 0 and len(groups) > 0 {
            try {
                localStorage.setItem(ROADMAP_SHAPE_KEY, "[" + shape + "]");
            } except Exception as e {
                console.warn("The roadmap shape is not kept in this browser", e);
            }
        }},
        [shape, placeholder]
    );

    # When the grid overflows (a phone), open with today a third of the way
    # across the visible weeks rather than at the window's left edge.
    useEffect(
        lambda {
            el: any = scroller.current;
            if el and el.scrollWidth > el.clientWidth {
                label: any = el.querySelector("[data-roadmap-label]");
                labelW = label.offsetWidth if label else 0;
                x = (el.scrollWidth - labelW) * todayFrac
                    - (el.clientWidth - labelW) / 3;
                el.scrollLeft = x if showToday and x > 0 else 0;
            }
        },
        [fromDate]
    );

    return
        <div ref={scroller} className="overflow-x-auto overscroll-x-contain pb-2">
            <div className="relative min-w-[820px] sm:min-w-[960px]">
                <RoadmapAxis fromDate={fromDate} weeks={weeks} today={today}/>
                <div className="relative">
                    <div
                        className={"pointer-events-none absolute inset-y-0 right-0 flex "
                            + LABEL_OFFSET}
                        aria-hidden="true"
                    >
                        {for w in range(weeks) {
                            <div
                                key={isoOfDay(origin + 7 * w)}
                                className="flex-1 border-l border-border/60"
                            />
                        }}
                    </div>
                    {if placeholder > 0 {
                        <RoadmapSkeleton key="ph" fallback={placeholder}/>
                    }}
                    {for g in groups {
                        <RoadmapGroup
                            key={g["key"]}
                            group={g}
                            win={win}
                            onOpen={onOpen}
                        />
                    }}
                </div>
            </div>
        </div>;
}
