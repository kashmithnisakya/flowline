"""Horizontal roadmap timeline: one bar per dated milestone.

Plain divs and Tailwind, no chart library. Every month is drawn the same
width, so bar geometry runs on a rough ordinal (month index * 31 + day)
rather than real calendar arithmetic, the same approximation
walkers/insights.jac uses for day gaps. Indexing the month off the year
keeps December to January monotonic, which a bare y*365 would not.

Undated milestones are deliberately absent: the page lists them instead of
the timeline guessing a position for them.
"""

import from ...models { MilestoneView }
import from ..ui.badge { Badge }

glob MONTH_NAMES: list[str] = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
];

# The milestone stores a colour KEY; the class strings must stay literal in
# these tables or Tailwind's scanner drops them from the build.
glob COLOR_KEYS: list[str] = [
    "violet", "sky", "emerald", "amber", "rose", "slate"
];

glob BAR_TINT: dict[str, str] = {
    "violet": "border-violet-500/40 bg-violet-500/15",
    "sky": "border-sky-500/40 bg-sky-500/15",
    "emerald": "border-emerald-500/40 bg-emerald-500/15",
    "amber": "border-amber-500/40 bg-amber-500/15",
    "rose": "border-rose-500/40 bg-rose-500/15",
    "slate": "border-slate-500/40 bg-slate-500/15"
};

glob BAR_FILL: dict[str, str] = {
    "violet": "bg-violet-500",
    "sky": "bg-sky-500",
    "emerald": "bg-emerald-500",
    "amber": "bg-amber-500",
    "rose": "bg-rose-500",
    "slate": "bg-slate-500"
};

# Label gutter and per-month width, in px. Both feed the scroll container's
# min width so the rows and the ruler cannot drift apart.
glob LABEL_PX: int = 176;
glob MONTH_PX: int = 132;

def colorKey(color: str) -> str {
    return color if color in COLOR_KEYS else "slate";
}

# Months since year 0, so ordering survives a year boundary.
def monthIndex(iso: str) -> int {
    if len(iso) < 7 {
        return 0;
    }
    return int(iso[0:4]) * 12 + int(iso[5:7]) - 1;
}

# Uniform-month day ordinal. Exact within a month, which is all the bar
# geometry needs; month-length drift moves a bar by at most a pixel.
def dayOrdinal(iso: str) -> int {
    if len(iso) < 10 {
        return 0;
    }
    return monthIndex(iso) * 31 + int(iso[8:10]);
}

def startOf(m: MilestoneView) -> str {
    return m.start_date if m.start_date else m.due_date;
}

def endOf(m: MilestoneView) -> str {
    return m.due_date if m.due_date else m.start_date;
}

def barLeft(m: MilestoneView, windowStart: int, span: int) -> str {
    return str((dayOrdinal(startOf(m)) - windowStart) * 100.0 / span) + "%";
}

def barWidth(m: MilestoneView, span: int) -> str {
    units = dayOrdinal(endOf(m)) - dayOrdinal(startOf(m)) + 1;
    if units < 1 {
        units = 1;
    }
    width = units * 100.0 / span;
    # A single-day milestone would otherwise render as a hairline nobody can
    # hover or read.
    floor = 300.0 / span;
    if width < floor {
        width = floor;
    }
    return str(width) + "%";
}

def progressWidth(m: MilestoneView) -> str {
    if m.task_count == 0 {
        return "0%";
    }
    return str(m.done_count * 100.0 / m.task_count) + "%";
}

def shortDate(iso: str) -> str {
    if len(iso) < 10 {
        return "?";
    }
    return MONTH_NAMES[int(iso[5:7]) - 1] + " " + iso[8:10];
}

def rangeLabel(m: MilestoneView) -> str {
    span = shortDate(startOf(m)) + " to " + shortDate(endOf(m));
    progress = str(m.done_count) + "/" + str(m.task_count) + " tasks done";
    return m.title + " · " + span + " · " + progress;
}

def statusVariant(status: str) -> str {
    if status == "Done" {
        return "secondary";
    }
    if status == "In Progress" {
        return "default";
    }
    return "outline";
}

def monthLabel(index: int, first: bool) -> str {
    name = MONTH_NAMES[index % 12];
    if first or index % 12 == 0 {
        return name + " " + str(index // 12);
    }
    return name;
}

def:pub Timeline(milestones: list[MilestoneView], today: str) -> JsxElement {
    dated = [m for m in milestones if m.start_date or m.due_date];
    if len(dated) == 0 {
        return <div className="rounded-lg border bg-card p-6 text-center text-sm text-muted-foreground">
            Nothing is scheduled yet. Give a milestone a start or target date and it appears here.
        </div>;
    }

    # NOTE: max()/min() over a list compiles to JS Math.max(array) and is NaN.
    firstIso = "";
    lastIso = "";
    firstOrd = 0;
    lastOrd = 0;
    for m in dated {
        so = dayOrdinal(startOf(m));
        eo = dayOrdinal(endOf(m));
        if not firstIso or so < firstOrd {
            firstIso = startOf(m);
            firstOrd = so;
        }
        if not lastIso or eo > lastOrd {
            lastIso = endOf(m);
            lastOrd = eo;
        }
    }

    startMonth = monthIndex(firstIso);
    monthCount = monthIndex(lastIso) - startMonth + 1;
    if monthCount < 1 {
        monthCount = 1;
    }
    windowStart = startMonth * 31 + 1;
    span = monthCount * 31;
    todayOrd = dayOrdinal(today);
    todayVisible = (
        len(today) >= 10 and todayOrd >= windowStart and todayOrd <= windowStart + span
    );
    todayLeft = str((todayOrd - windowStart) * 100.0 / span) + "%";

    return <div className="overflow-x-auto rounded-lg border bg-card">
        <div className="p-4" style={{"minWidth": str(LABEL_PX + monthCount * MONTH_PX) + "px"}}>
            <div className="flex items-end pb-2">
                <div className="shrink-0" style={{"width": str(LABEL_PX) + "px"}} />
                <div className="flex flex-1">
                    {for i in range(monthCount) {
                        <div
                            key={str(startMonth + i)}
                            className="flex-1 border-l pl-2 text-xs font-medium text-muted-foreground"
                        >
                            {monthLabel(startMonth + i, i == 0)}
                        </div>
                    }}
                </div>
            </div>

            <div className="relative">
                {if todayVisible {
                    <div
                        key="today"
                        className="pointer-events-none absolute inset-y-0 right-0"
                        style={{"left": str(LABEL_PX) + "px"}}
                    >
                        <div
                            className="absolute inset-y-0 w-px bg-primary/70"
                            style={{"left": todayLeft}}
                            title={"Today, " + today}
                        />
                    </div>
                }}
                <div className="space-y-1">
                    {for m in dated {
                        <div key={m.id} className="flex items-center">
                            <div className="shrink-0 pr-3" style={{"width": str(LABEL_PX) + "px"}}>
                                <div className="flex items-center gap-2">
                                    <span className={"h-2 w-2 shrink-0 rounded-full " + BAR_FILL[colorKey(m.color)]} />
                                    <span className="truncate text-sm font-medium" title={m.title}>
                                        {m.title}
                                    </span>
                                </div>
                                <div className="pl-4 pt-1">
                                    <Badge variant={statusVariant(m.status)} className="font-normal">
                                        {m.status}
                                    </Badge>
                                </div>
                            </div>
                            <div className="relative h-12 flex-1">
                                <div className="absolute inset-x-0 top-1/2 h-px -translate-y-1/2 bg-border" />
                                <div
                                    className={
                                        "absolute top-3 bottom-3 overflow-hidden rounded-md border "
                                        + BAR_TINT[colorKey(m.color)]
                                    }
                                    style={{
                                        "left": barLeft(m, windowStart, span),
                                        "width": barWidth(m, span)
                                    }}
                                    title={rangeLabel(m)}
                                >
                                    <div
                                        className={"h-full " + BAR_FILL[colorKey(m.color)]}
                                        style={{"width": progressWidth(m)}}
                                    />
                                </div>
                            </div>
                        </div>
                    }}
                </div>
            </div>
        </div>
    </div>;
}
