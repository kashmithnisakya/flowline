"""The week as a people × weekday grid: one row per person, one cell per day
with the count and the first entries, blocked days tinted. Gaps read as empty
cells, which is the signal a standup exists to surface. Click a cell to open
that day.
"""

import from ...models { LogEntry }
import from ..common.Avatar { Avatar }
import from ..ui.card { Card, CardContent }

glob DAY_NAMES: list[str] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
     MAX_LINES: int = 2;

def todayIso -> str {
    d = new(Date);
    shifted = new(Date, d.getTime() - d.getTimezoneOffset() * 60000);
    return shifted.toISOString()[:10];
}

# "2026-08-11" -> "Tue 11"
def dayLabel(iso: str) -> str {
    d = new(Date, iso + "T00:00:00");
    return DAY_NAMES[int((d.getDay() + 6) % 7)] + " " + str(int(iso[8:10]));
}

# member_name is every assignee comma-joined; an empty one is "Unassigned".
def people(e: LogEntry) -> list[str] {
    names = [
        n
        for n in e.member_name.split(", ")
        if n
    ];
    return names if len(names) > 0 else ["Unassigned"];
}

def:pub WeekMatrix(
    entries: list[LogEntry],
    weekDays: list[str],
    # Roster names come first (so a quiet person still gets a row); anyone
    # else who appears in the log is appended, then Unassigned if needed.
    memberNames: list[str],
    selectedDate: str,
    onSelectDate: Callable[[str], None]
) -> JsxElement {
    today = todayIso();
    rows: list[str] = [];
    for n in memberNames {
        if n not in rows {
            rows.append(n);
        }
    }
    for e in entries {
        for n in people(e) {
            if n not in rows {
                rows.append(n);
            }
        }
    }
    # Weekend columns show only when something happened on them.
    days = [
        d
        for (i, d) in enumerate(weekDays)
        if i < 5
        or len(
            [
                e
                for e in entries
                if e.date == d
            ]
        ) > 0
    ];
    if len(rows) == 0 {
        return <span/>;
    }
    # One bucket per (person, day) so the grid below does no filtering.
    cells: dict[str, list[LogEntry]] = {};
    for who in rows {
        for d in days {
            cells[who + "|" + d] = [];
        }
    }
    for e in entries {
        for who in people(e) {
            key = who + "|" + e.date;
            if key in cells {
                cells[key].append(e);
            }
        }
    }
    return
        <Card className="gap-0 py-0">
            <CardContent className="overflow-x-auto p-3 sm:p-4">
                <div
                    className="grid min-w-[40rem] gap-1.5"
                    style={{
                        "gridTemplateColumns": "10rem repeat(" + str(len(days)) + ", minmax(0, 1fr))"
                    }}
                >
                    <div/>
                    {for d in days {
                        <button
                            key={"h" + d}
                            type="button"
                            onClick={lambda { onSelectDate(d); }}
                            className={"rounded-md py-1 text-center text-[11px] font-semibold uppercase tracking-wide transition-colors hover:bg-accent " + (
                                "text-primary"
                                    if d == selectedDate
                                    else (
                                        "text-foreground"
                                            if d == today
                                            else "text-muted-foreground"
                                    )
                            )}
                            aria-current={"date" if d == today else None}
                        >
                            {dayLabel(d)}
                        </button>
                    }}
                    {for who in rows {
                        <div key={who} className="contents">
                            <div
                                className="flex min-w-0 items-center gap-2 pr-2 text-sm font-medium"
                            >
                                <Avatar name={who} size="sm"/>
                                <span className="truncate">{who}</span>
                            </div>
                            {for d in days {
                                <button
                                    key={who + d}
                                    type="button"
                                    onClick={lambda { onSelectDate(d); }}
                                    title={who + " · " + dayLabel(d) + ": " + str(
                                        len(cells[who + "|" + d])
                                    ) + " entries"}
                                    className={"flex min-h-14 flex-col items-start gap-0.5 rounded-lg border p-1.5 text-left text-[11px] leading-tight transition-colors hover:bg-accent " + (
                                        (
                                            "border-destructive/50 bg-destructive/5"
                                                if len(
                                                    [
                                                        e
                                                        for e in cells[who + "|" + d]
                                                        if e.status == "Blocked"
                                                    ]
                                                ) > 0
                                                else "border-border bg-card"
                                        )
                                            if len(cells[who + "|" + d]) > 0
                                            else "border-dashed border-border/70 bg-transparent"
                                    ) + (
                                        " ring-2 ring-primary/40"
                                            if d == selectedDate
                                            else ""
                                    )}
                                >
                                    {for (i, e) in enumerate(cells[who + "|" + d]) {
                                        if i < MAX_LINES {
                                            <span
                                                key={jid(e)}
                                                className={"w-full truncate " + (
                                                    "font-medium text-destructive"
                                                        if e.status == "Blocked"
                                                        else "text-foreground"
                                                )}
                                            >
                                                {(e.task_title or e.activity) + (
                                                    (" → " + e.status)
                                                        if e.task_title and e.status
                                                        else ""
                                                )}
                                            </span>
                                        }
                                    }}
                                    {if len(cells[who + "|" + d]) > MAX_LINES {
                                        <span
                                            key="more"
                                            className="text-muted-foreground"
                                        >
                                            {"+" + str(
                                                len(cells[who + "|" + d]) - MAX_LINES
                                            ) + " more"}
                                        </span>
                                    }}
                                </button>
                            }}
                        </div>
                    }}
                </div>
            </CardContent>
        </Card>;
}
