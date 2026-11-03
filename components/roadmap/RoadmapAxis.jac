"""The week row above the roadmap (each week's Monday, this week in primary)
and the week lines behind its rows."""

import from .span { dayNumber, isoOfDay }
import from .LabelCell { LabelCell, LABEL_OFFSET }
import from ...lib.dates { prettyDay }

def:pub RoadmapAxis(fromDate: str, weeks: int, today: str) -> JsxElement {
    origin = dayNumber(fromDate);
    todayN = dayNumber(today);
    weekStarts = [isoOfDay(origin + 7 * w) for w in range(weeks)];
    return
        <div className="flex border-b" aria-hidden="true">
            <LabelCell className="flex h-7 items-center text-xs text-text-tertiary">
                Task
            </LabelCell>
            <div className="flex flex-1">
                {for w in weekStarts {
                    <div
                        key={w}
                        className={"flex flex-1 items-center border-l border-border-subtle px-1.5 num text-xs whitespace-nowrap "
                            + (
                                "font-medium text-primary"
                                    if todayN >= dayNumber(w)
                                        and todayN < dayNumber(w) + 7
                                    else "text-text-tertiary"
                            )}
                    >
                        {prettyDay(w)}
                    </div>
                }}
            </div>
        </div>;
}


def:pub WeekLines(origin: int, weeks: int) -> JsxElement {
    return
        <div
            className={"pointer-events-none absolute inset-y-0 right-0 flex "
                + LABEL_OFFSET}
            aria-hidden="true"
        >
            {for w in range(weeks) {
                <div
                    key={isoOfDay(origin + 7 * w)}
                    className="flex-1 border-l border-border-subtle"
                />
            }}
        </div>;
}
