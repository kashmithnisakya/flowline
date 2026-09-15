"""The roadmap grid: a week header, the iterations as a band, then the tasks
grouped by project, each a bar over its span in its step's colour. Positions
are percentages of the window, so the grid scrolls sideways on a narrow
screen instead of squeezing. `starts` / `ends` are index-aligned with `rows`."""

import from ...models { TaskView, StepView, IterationView }
import from ...constants { STATUS_KIND, KIND_COLORS }
import from ..flowlines.kinds { LANE_BAR, colorKey }
import from ...lib.dates { prettyDay }

glob DAY_MS: int = 86400000,
     # A solid tint for the band and group rows: the sticky label cells sit
     # over scrolled content, so a translucent fill would let the grid through.
     TINT: str = "bg-[color-mix(in_oklab,var(--muted)_45%,var(--card))]";

# Whole days since the epoch for an ISO day, read as UTC so DST never shifts it.
def dayNumber(iso: str) -> int {
    return int(new(Date, iso + "T00:00:00Z").getTime() / DAY_MS + 0.5);
}

def isoOfDay(n: int) -> str {
    return new(Date, n * DAY_MS).toISOString()[:10];
}

# Left edge and width of [first, last] (inclusive days) as percentages of a
# window of `total` days starting on day `origin`, clipped to the window.
def spanStyle(first: str, last: str, origin: int, total: int) -> dict[str, str] {
    a = dayNumber(first) - origin;
    b = dayNumber(last) - origin + 1;
    a = 0 if a < 0 else a;
    b = total if b > total else b;
    width = b - a if b > a else 1;
    return {
        "left": str(a * 100.0 / total) + "%",
        "width": "max(6px, " + str(width * 100.0 / total) + "%)"
    };
}

def spanLabel(first: str, last: str) -> str {
    return prettyDay(first)
        if first == last
        else prettyDay(first) + " – " + prettyDay(last);
}

def:pub RoadmapTimeline(
    fromDate: str,
    weeks: int,
    today: str,
    iterations: list[IterationView],
    rows: list[TaskView],
    starts: list[str],
    ends: list[str],
    steps: list[StepView],
    onOpen: Callable[[str], None]
) -> JsxElement {
    origin = dayNumber(fromDate);
    total = weeks * 7;
    lastDay = isoOfDay(origin + total - 1);
    weekStarts = [isoOfDay(origin + 7 * w) for w in range(weeks)];
    todayFrac = (dayNumber(today) - origin + 0.5) * 1.0 / total;
    showToday = today >= fromDate and today <= lastDay;
    stepColor: dict[str, str] = {};
    for st in steps {
        stepColor[st.id] = colorKey(st.color);
    }
    # Projects in order of their earliest task; rows keep the server's order.
    groups: list[str] = [];
    groupRows: dict[str, list[int]] = {};
    for (i, t) in enumerate(rows) {
        key = t.project_name or "No project";
        if key not in groupRows {
            groups.append(key);
            groupRows[key] = [];
        }
        groupRows[key].append(i);
    }

    # Today's mark inside one row's timeline cell. Drawn per row rather than
    # as one overlay, so the sticky label column always covers it.
    def TodayMark -> JsxElement {
        return
            <div
                className="pointer-events-none absolute inset-y-0 z-10 w-0.5 -translate-x-1/2 bg-primary"
                style={{"left": str(todayFrac * 100.0) + "%"}}
                aria-hidden="true"
            />;
    }

    def barClass(t: TaskView) -> str {
        key = stepColor[t.step_id] if t.step_id in stepColor else "";
        if not key {
            kind = STATUS_KIND[t.status] if t.status in STATUS_KIND else "active";
            key = KIND_COLORS[kind] if kind in KIND_COLORS else "slate";
        }
        return LANE_BAR[key] if key in LANE_BAR else LANE_BAR["slate"];
    }

    return
        <div className="overflow-x-auto rounded-xl border bg-card">
            <div className="relative min-w-[960px]">
                <div className="flex border-b">
                    <div
                        className="sticky left-0 z-20 w-60 shrink-0 bg-card px-4 py-2 text-xs font-medium text-muted-foreground"
                    >
                        Task
                    </div>
                    <div className="flex flex-1">
                        {for w in weekStarts {
                            <div
                                key={w}
                                className={"flex-1 border-l px-2 py-2 text-xs tabular-nums "
                                    + (
                                        "font-medium text-foreground"
                                            if today >= w
                                                and dayNumber(today) < dayNumber(w) + 7
                                            else "text-muted-foreground"
                                    )}
                            >
                                {prettyDay(w)}
                            </div>
                        }}
                    </div>
                </div>
                <div className={"flex border-b " + TINT}>
                    <div
                        className={"sticky left-0 z-20 w-60 shrink-0 px-4 py-2.5 text-xs text-muted-foreground "
                            + TINT}
                    >
                        Iterations
                    </div>
                    <div className="relative h-10 flex-1">
                        {for it in iterations {
                            <div
                                key={it.id}
                                className={"absolute top-2 z-[15] flex h-6 items-center truncate rounded-md border px-2 text-xs "
                                    + (
                                        "border-primary/50 bg-[color-mix(in_oklab,var(--primary)_15%,var(--card))] font-medium text-foreground"
                                            if it.start_date <= today
                                                and it.end_date >= today
                                            else "border-border bg-card text-muted-foreground"
                                    )}
                                style={spanStyle(
                                    it.start_date, it.end_date, origin, total
                                )}
                                title={it.name
                                    + " · "
                                    + spanLabel(it.start_date, it.end_date)}
                            >
                                {it.name}
                            </div>
                        }}
                        {if showToday {
                            <TodayMark key="today"/>
                        }}
                    </div>
                </div>
                <div className="relative">
                    <div
                        className="pointer-events-none absolute inset-y-0 right-0 left-60 flex"
                        aria-hidden="true"
                    >
                        {for w in weekStarts {
                            <div key={w} className="flex-1 border-l border-border/60"/>
                        }}
                    </div>
                    {for g in groups {
                        <div key={g}>
                            <div
                                className={"relative flex border-b text-xs font-semibold "
                                    + TINT}
                            >
                                <span
                                    className={"sticky left-0 z-20 w-60 shrink-0 px-4 py-1.5 "
                                        + TINT}
                                >
                                    {g + " · " + str(len(groupRows[g]))}
                                </span>
                                <div className="relative flex-1">
                                    {if showToday {
                                        <TodayMark key="today"/>
                                    }}
                                </div>
                            </div>
                            {for i in groupRows[g] {
                                <div
                                    key={rows[i].id}
                                    className="relative flex h-11 items-center border-b hover:bg-accent/40"
                                >
                                    <button
                                        type="button"
                                        className="sticky left-0 z-20 h-full w-60 shrink-0 border-r bg-card px-4 text-left"
                                        onClick={lambda { onOpen(rows[i].id); }}
                                    >
                                        <span
                                            className="block truncate text-sm font-medium"
                                        >
                                            {rows[i].title}
                                        </span>
                                        <span
                                            className="block truncate text-xs text-muted-foreground"
                                        >
                                            {spanLabel(starts[i], ends[i])}
                                        </span>
                                    </button>
                                    <div className="relative h-full flex-1">
                                        <button
                                            type="button"
                                            className={"absolute top-3 h-5 "
                                                + barClass(rows[i])
                                                + (
                                                    " rounded-l-md"
                                                        if starts[i] >= fromDate
                                                        else ""
                                                )
                                                + (
                                                    " rounded-r-md"
                                                        if ends[i] <= lastDay
                                                        else ""
                                                )
                                                + (
                                                    " opacity-50"
                                                        if rows[i].status == "Done"
                                                        else ""
                                                )
                                                + " transition-[filter] hover:brightness-110 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring"}
                                            style={spanStyle(
                                                starts[i], ends[i], origin, total
                                            )}
                                            title={rows[i].title
                                                + " · "
                                                + spanLabel(starts[i], ends[i])
                                                + " · "
                                                + rows[i].status}
                                            aria-label={"Open "
                                                + rows[i].title
                                                + ", "
                                                + spanLabel(starts[i], ends[i])}
                                            onClick={lambda { onOpen(rows[i].id); }}
                                        />
                                        {if showToday {
                                            <TodayMark key="today"/>
                                        }}
                                    </div>
                                </div>
                            }}
                        </div>
                    }}
                </div>
            </div>
        </div>;
}
