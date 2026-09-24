"""The month and week rows above the roadmap, in mono. A month label
scrolled past stays pinned beside the task column; this week is primary."""

import from .span { dayNumber, isoOfDay, monthCells }
import from .LabelCell { LabelCell, LABEL_OFFSET }
import from ...lib.dates { prettyDay }

def:pub RoadmapAxis(fromDate: str, weeks: int, today: str) -> JsxElement {
    origin = dayNumber(fromDate);
    todayN = dayNumber(today);
    weekStarts = [isoOfDay(origin + 7 * w) for w in range(weeks)];
    months = monthCells(origin, weeks * 7);
    return
        <div className="border-b" aria-hidden="true">
            <div className="flex">
                <LabelCell/>
                <div className="relative h-7 flex-1">
                    {for m in months {
                        <div
                            key={m["key"]}
                            className="absolute inset-y-0 py-1 font-mono text-xs font-medium whitespace-nowrap text-foreground tabular-nums"
                            style={{"left": m["left"], "width": m["width"]}}
                        >
                            <span
                                className={"sticky inline-block px-2 " + LABEL_OFFSET}
                            >
                                {m["label"]}
                            </span>
                        </div>
                    }}
                </div>
            </div>
            <div className="flex">
                <LabelCell className="py-1.5 text-xs text-muted-foreground">
                    Task
                </LabelCell>
                <div className="flex flex-1">
                    {for w in weekStarts {
                        <div
                            key={w}
                            className={"flex-1 border-l border-border/60 px-2 py-1.5 font-mono text-xs tabular-nums "
                                + (
                                    "font-medium text-primary"
                                        if todayN >= dayNumber(w)
                                            and todayN < dayNumber(w) + 7
                                        else "text-muted-foreground"
                                )}
                        >
                            {prettyDay(w)}
                        </div>
                    }}
                </div>
            </div>
        </div>;
}
