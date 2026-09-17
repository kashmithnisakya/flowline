"""The roadmap grid: mono month and week headers, iterations as quiet shaded
ranges, then the tasks grouped by project. A bar is neutral and carries its
step as a 2px rule and its kind as a glyph; overdue turns it red. Positions
are percentages of the window, so the grid scrolls sideways when it is narrow."""

import from "react" { useEffect }
import from ...models { TaskView, StepView, IterationView }
import from ...constants { STATUS_KIND, KIND_COLORS }
import from ..flowlines.kinds { DOT_VAR, colorKey }
import from ..common.KindGlyph { KindGlyph }
import from ..ui.skeleton { Skeleton }
import from ...lib.dates { prettyDay, dueTone, dueLabel }

# Placeholder rows: title widths, where each bar sits across the window and
# how wide it is (mostly the one-day minimum, like a loaded roadmap).
glob PH_WIDTHS: list[str] = ["w-3/5", "w-2/5", "w-1/2", "w-[70%]"],
     PH_LEFT: list[str] = ["18%", "31%", "26%", "44%", "52%", "38%", "61%", "35%"],
     PH_BAR: list[str] = ["24px", "24px", "9%", "24px", "24px", "6%", "24px", "24px"],
     # The project groups the last loaded roadmap had in this browser (rows
     # per group), so the first-load frame reserves the same group rows.
     SHAPE_KEY: str = "flowline-roadmap-shape";

# Rows per placeholder group: the cached shape, else one group of `fallback`.
def cachedGroups(fallback: int) -> list[int] {
    try {
        raw = localStorage.getItem(SHAPE_KEY) or "";
        parsed: any = JSON.parse(raw) if raw else [];
        out: list[int] = [];
        total = 0;
        for n in parsed {
            m = int(n) if n else 0;
            m = 1 if m < 1 else (12 if m > 12 else m);
            if len(out) < 6 and total + m <= 30 {
                out.append(m);
                total = total + m;
            }
        }
        return out if len(out) > 0 else [fallback];
    } except Exception as e {
        return [fallback];
    }
}

glob DAY_MS: int = 86400000,
     # lib/dates keeps its own copy unexported, so the month row carries one.
     MONTHS: list[str] = [
         "Jan",
         "Feb",
         "Mar",
         "Apr",
         "May",
         "Jun",
         "Jul",
         "Aug",
         "Sep",
         "Oct",
         "Nov",
         "Dec"
     ],
     # Iteration shading, mixed off the foreground so it reads in both palettes:
     # a solid head in the band row, a lighter wash behind the task rows.
     BAND_HEAD: str = "bg-[color-mix(in_oklab,var(--foreground)_7%,var(--card))]",
     BAND_WASH: str = "bg-[color-mix(in_oklab,var(--foreground)_4%,transparent)]",
     GROUP_FILL: str = "bg-[color-mix(in_oklab,var(--muted)_60%,var(--card))]",
     # A bar's neutral fill and edge, also mixed off the foreground so a bar
     # still stands off the dark card. The kind glyph knocks out of the same fill.
     BAR_MIX: str = "color-mix(in oklab, var(--foreground) 9%, var(--card))",
     BAR_FILL: str = "bg-[color-mix(in_oklab,var(--foreground)_9%,var(--card))]",
     BAR_EDGE: str = "border-[color-mix(in_oklab,var(--foreground)_20%,var(--card))]",
     # The sticky label column: narrow enough that a phone still shows time.
     LABEL_W: str = "w-40 sm:w-60",
     LABEL_OFFSET: str = "left-40 sm:left-60",
     LABEL_CELL: str = "sticky left-0 z-20 shrink-0 border-r px-3";

# Whole days since the epoch for an ISO day, read as UTC so DST never shifts it.
def dayNumber(iso: str) -> int {
    return int(new(Date, iso + "T00:00:00Z").getTime() / DAY_MS + 0.5);
}

def isoOfDay(n: int) -> str {
    return new(Date, n * DAY_MS).toISOString()[:10];
}

def pct(days: int, total: int) -> str {
    return str(days * 100.0 / total) + "%";
}

# Left edge and width of [first, last] (inclusive days) as percentages of a
# window of `total` days starting on day `origin`, clipped to the window.
def spanStyle(
    first: str, last: str, origin: int, total: int, minPx: int = 24
) -> dict[str, str] {
    a = dayNumber(first) - origin;
    b = dayNumber(last) - origin + 1;
    a = 0 if a < 0 else a;
    b = total if b > total else b;
    width = b - a if b > a else 1;
    return {
        "left": pct(a, total),
        "width": "max(" + str(minPx) + "px, " + pct(width, total) + ")"
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
    onOpen: Callable[[str], None],
    # The first load: this many skeleton rows under the real month and week
    # headers, at the real row height.
    placeholder: int = 0
) -> JsxElement {
    has scroller: Ref[any] = Ref();

    origin = dayNumber(fromDate);
    total = weeks * 7;
    lastDay = isoOfDay(origin + total - 1);
    weekStarts = [isoOfDay(origin + 7 * w) for w in range(weeks)];
    todayFrac = (dayNumber(today) - origin + 0.5) * 1.0 / total;
    todayLeft = str(todayFrac * 100.0) + "%";
    showToday = today >= fromDate and today <= lastDay;
    stepKind: dict[str, str] = {};
    stepLabel: dict[str, str] = {};
    stepHue: dict[str, str] = {};
    for st in steps {
        stepKind[st.id] = st.kind;
        stepLabel[st.id] = st.name;
        stepHue[st.id] = colorKey(st.color);
    }
    # Month cells sit on the real first of each month, so a week that crosses
    # a month boundary splits where the calendar does. A sliver keeps no label,
    # and a label scrolled past stays pinned beside the task column.
    months: list[dict[str, any]] = [];
    day = origin;
    while day < origin + total {
        iso = isoOfDay(day);
        year = int(iso[:4]);
        month = int(iso[5:7]);
        nextFirst = (
            str(year + 1) + "-01-01"
                if month == 12
                else iso[:5] + ("0" if month < 9 else "") + str(month + 1) + "-01"
        );
        end = dayNumber(nextFirst);
        end = origin + total if end > origin + total else end;
        months.append(
            {
                "key": iso[:7],
                "label": MONTHS[month - 1] + " " + str(year) if end - day >= 7 else "",
                "left": pct(day - origin, total),
                "width": pct(end - day, total)
            }
        );
        day = end;
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
    # Remember the groups' shape once rows are on screen, for the next
    # first-load frame; a placeholder draws the cached groups instead.
    shapeStamp = ",".join([str(len(groupRows[g])) for g in groups]);
    useEffect(
        lambda {
            if len(rows) > 0 {
                try {
                    localStorage.setItem(
                        SHAPE_KEY, JSON.stringify([len(groupRows[g]) for g in groups])
                    );
                } except Exception as e {
                    shapeStamp = shapeStamp;
                }
            }
            return lambda { shapeStamp = shapeStamp; };
        },
        [shapeStamp]
    );
    phGroups = cachedGroups(placeholder) if placeholder > 0 else [];

    def kindOf(t: TaskView) -> str {
        if t.step_id in stepKind {
            return stepKind[t.step_id];
        }
        return STATUS_KIND[t.status] if t.status in STATUS_KIND else "active";
    }

    def hueOf(t: TaskView) -> str {
        if t.step_id in stepHue {
            return stepHue[t.step_id];
        }
        kind = kindOf(t);
        return KIND_COLORS[kind] if kind in KIND_COLORS else "slate";
    }

    def nameOf(t: TaskView) -> str {
        return stepLabel[t.step_id] if t.step_id in stepLabel else t.status;
    }

    def isLate(t: TaskView) -> bool {
        return dueTone(t.due_date, t.status, today) == "overdue";
    }

    # Words for a row's second line: overdue says so in text, not only in red.
    def lateWords(t: TaskView) -> str {
        return dueLabel(t.due_date, t.status, today) if isLate(t) else "";
    }

    # When the grid overflows its box (a phone), open with today a third of the
    # way across the visible weeks rather than at the window's left edge.
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

    # Today's mark inside one row's timeline cell. Drawn per row rather than
    # as one overlay, so the sticky label column always covers it.
    def TodayMark -> JsxElement {
        return
            <span
                className="pointer-events-none absolute inset-y-0 z-10 w-0.5 -translate-x-1/2 bg-primary"
                style={{"left": todayLeft}}
                aria-hidden="true"
            />;
    }

    def barClass(t: TaskView, first: str, last: str) -> str {
        edges = ("rounded-l-[3px] " if first >= fromDate else "")
            + ("rounded-r-[3px] " if last <= lastDay else "");
        base = "pointer-events-none absolute top-1/2 flex h-5 -translate-y-1/2 items-center overflow-hidden border border-l-2 pl-1 "
            + edges;
        if t.status == "Done" {
            return base + "border-border bg-card text-muted-foreground";
        }
        if isLate(t) {
            return base + "border-destructive/60 text-destructive " + BAR_FILL;
        }
        return base + "text-muted-foreground " + BAR_FILL + " " + BAR_EDGE;
    }

    def barStyle(t: TaskView, first: str, last: str) -> dict[str, str] {
        css = spanStyle(first, last, origin, total);
        css["borderLeftColor"] = "var(--destructive)"
            if isLate(t)
            else DOT_VAR[hueOf(t)];
        # The glyph knocks its bar out of its own fill, not the card's.
        css["--kind-knockout"] = "var(--card)" if t.status == "Done" else BAR_MIX;
        return css;
    }

    return
        <div ref={scroller} className="overflow-x-auto overscroll-x-contain">
            <div className="relative min-w-[960px]">
                <div className="flex border-b">
                    <div
                        className={LABEL_CELL + " bg-card " + LABEL_W}
                        data-roadmap-label="true"
                    />
                    <div className="relative h-8 flex-1" aria-hidden="true">
                        {for m in months {
                            <div
                                key={m["key"]}
                                className="absolute inset-y-0 border-l py-1.5 font-mono text-xs whitespace-nowrap text-muted-foreground tabular-nums"
                                style={{"left": m["left"], "width": m["width"]}}
                            >
                                <span
                                    className={"sticky inline-block px-2 "
                                        + LABEL_OFFSET}
                                >
                                    {m["label"]}
                                </span>
                            </div>
                        }}
                    </div>
                </div>
                <div className="flex border-b">
                    <div
                        className={LABEL_CELL
                            + " bg-card py-1.5 text-xs text-muted-foreground "
                            + LABEL_W}
                    >
                        Task
                    </div>
                    <div className="relative flex flex-1">
                        {for w in weekStarts {
                            <div
                                key={w}
                                className={"flex-1 border-l px-2 py-1.5 font-mono text-xs tabular-nums "
                                    + (
                                        "font-medium text-primary"
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
                {if len(iterations) > 0 {
                    <div key="bands" className="flex border-b">
                        <div
                            className={LABEL_CELL
                                + " flex items-center bg-card text-xs text-muted-foreground "
                                + LABEL_W}
                        >
                            Iterations
                        </div>
                        <div className="relative h-9 flex-1">
                            {for it in iterations {
                                <div
                                    key={it.id}
                                    className={"absolute inset-y-0 border-x border-border "
                                        + BAND_HEAD}
                                    style={spanStyle(
                                        it.start_date, it.end_date, origin, total, 2
                                    )}
                                    aria-hidden="true"
                                />
                            }}
                            {if showToday {
                                <TodayMark key="today"/>
                            }}
                            {for it in iterations {
                                <div
                                    key={"label-" + it.id}
                                    className="absolute inset-y-0 z-[15] flex items-center overflow-clip px-1.5"
                                    style={spanStyle(
                                        it.start_date, it.end_date, origin, total, 2
                                    )}
                                    title={it.name
                                        + " · "
                                        + spanLabel(it.start_date, it.end_date)}
                                >
                                    <span
                                        className={"sticky flex min-w-0 items-baseline gap-2 rounded-xs px-1 "
                                            + LABEL_OFFSET
                                            + " "
                                            + BAND_HEAD}
                                    >
                                        <span
                                            className={"max-w-full shrink-0 truncate text-[13px] "
                                                + (
                                                    "font-semibold text-foreground"
                                                        if it.start_date <= today
                                                            and it.end_date >= today
                                                        else "font-medium text-muted-foreground"
                                                )}
                                        >
                                            {it.name}
                                        </span>
                                        <span
                                            className="min-w-0 truncate font-mono text-xs text-muted-foreground tabular-nums"
                                        >
                                            {spanLabel(it.start_date, it.end_date)}
                                        </span>
                                    </span>
                                </div>
                            }}
                        </div>
                    </div>
                }}
                <div className="relative">
                    <div
                        className={"pointer-events-none absolute inset-y-0 right-0 "
                            + LABEL_OFFSET}
                        aria-hidden="true"
                    >
                        <div className="relative h-full w-full">
                            {for it in iterations {
                                <div
                                    key={it.id}
                                    className={"absolute inset-y-0 border-x border-border/70 "
                                        + BAND_WASH}
                                    style={spanStyle(
                                        it.start_date, it.end_date, origin, total, 2
                                    )}
                                />
                            }}
                            <div className="absolute inset-0 flex">
                                {for w in weekStarts {
                                    <div
                                        key={w}
                                        className="flex-1 border-l border-border/60"
                                    />
                                }}
                            </div>
                        </div>
                    </div>
                    {for (gi, n) in enumerate(phGroups) {
                        <div key={"pg" + str(gi)} aria-hidden="true">
                            <div className={"relative flex border-b " + GROUP_FILL}>
                                <span
                                    className={LABEL_CELL
                                        + " py-1.5 text-xs "
                                        + GROUP_FILL
                                        + " "
                                        + LABEL_W}
                                >
                                    <span className="flex h-4 items-center">
                                        <Skeleton className="h-3 w-28"/>
                                    </span>
                                </span>
                                <div className="relative flex-1"/>
                            </div>
                            {for i in range(n) {
                                <div
                                    key={"ph" + str(i)}
                                    className="relative flex h-11 w-full items-center border-b"
                                >
                                    <span
                                        className={LABEL_CELL
                                            + " flex h-full flex-col justify-center gap-1 bg-card "
                                            + LABEL_W}
                                    >
                                        <Skeleton
                                            className={"h-3.5 "
                                                + PH_WIDTHS[(gi + i) % 4]}
                                        />
                                        <Skeleton className="h-3 w-24"/>
                                    </span>
                                    <span className="relative h-full flex-1">
                                        <Skeleton
                                            className="absolute top-1/2 h-5 -translate-y-1/2 rounded-[3px]"
                                            style={{
                                                "left": PH_LEFT[(gi * 3 + i) % 8],
                                                "width": PH_BAR[(gi * 3 + i) % 8]
                                            }}
                                        />
                                    </span>
                                </div>
                            }}
                        </div>
                    }}
                    {for g in groups {
                        <div key={g} role="group" aria-label={g}>
                            <div className={"relative flex border-b " + GROUP_FILL}>
                                <span
                                    className={LABEL_CELL
                                        + " py-1.5 text-xs font-semibold "
                                        + GROUP_FILL
                                        + " "
                                        + LABEL_W}
                                >
                                    {g}
                                    <span
                                        className="ml-1.5 font-mono font-normal text-muted-foreground tabular-nums"
                                    >
                                        {str(len(groupRows[g]))}
                                    </span>
                                </span>
                                <div className="relative flex-1">
                                    {if showToday {
                                        <TodayMark key="today"/>
                                    }}
                                </div>
                            </div>
                            {for i in groupRows[g] {
                                <button
                                    key={rows[i].id}
                                    type="button"
                                    data-task-card={rows[i].id}
                                    className="group relative flex h-11 w-full items-center border-b text-left outline-none hover:bg-accent"
                                    title={rows[i].title
                                        + " · "
                                        + nameOf(rows[i])
                                        + " · "
                                        + spanLabel(starts[i], ends[i])}
                                    aria-label={"Open "
                                        + rows[i].title
                                        + ", "
                                        + spanLabel(starts[i], ends[i])
                                        + (
                                            ", " + lateWords(rows[i])
                                                if isLate(rows[i])
                                                else ""
                                        )}
                                    onClick={lambda { onOpen(rows[i].id); }}
                                >
                                    <span
                                        className="pointer-events-none absolute inset-0 z-30 hidden outline-2 -outline-offset-2 outline-ring outline-solid group-focus-visible:block"
                                        aria-hidden="true"
                                    />
                                    <span
                                        className={LABEL_CELL
                                            + " flex h-full flex-col justify-center gap-0.5 bg-card group-hover:bg-accent "
                                            + LABEL_W}
                                    >
                                        <span
                                            className="truncate text-[13.5px] leading-tight font-medium"
                                        >
                                            {rows[i].title}
                                        </span>
                                        <span
                                            className="flex min-w-0 items-center gap-1.5 text-xs leading-tight text-muted-foreground"
                                        >
                                            <span
                                                className={"shrink-0 font-mono tabular-nums "
                                                    + (
                                                        "font-medium text-destructive"
                                                            if isLate(rows[i])
                                                            else ""
                                                    )}
                                            >
                                                <span
                                                    className={"sm:inline "
                                                        + (
                                                            "hidden"
                                                                if isLate(rows[i])
                                                                else ""
                                                        )}
                                                >
                                                    {spanLabel(starts[i], ends[i])}
                                                </span>
                                                {if isLate(rows[i]) {
                                                    <span
                                                        key="due"
                                                        className="sm:hidden"
                                                    >
                                                        {prettyDay(ends[i])}
                                                    </span>
                                                }}
                                            </span>
                                            {if isLate(rows[i]) {
                                                <span
                                                    key="late"
                                                    className="min-w-0 truncate font-medium text-destructive"
                                                >
                                                    {"· " + lateWords(rows[i])}
                                                </span>
                                            } else {
                                                <span
                                                    key="step"
                                                    className="hidden min-w-0 truncate sm:inline"
                                                >
                                                    {"· " + nameOf(rows[i])}
                                                </span>
                                            } }
                                        </span>
                                    </span>
                                    <span className="relative h-full flex-1">
                                        <span
                                            className={barClass(
                                                rows[i], starts[i], ends[i]
                                            )}
                                            style={barStyle(
                                                rows[i], starts[i], ends[i]
                                            )}
                                        >
                                            <KindGlyph
                                                kind={kindOf(rows[i])}
                                                size={14}
                                            />
                                        </span>
                                        {if showToday {
                                            <TodayMark key="today"/>
                                        }}
                                    </span>
                                </button>
                            }}
                        </div>
                    }}
                </div>
            </div>
        </div>;
}
