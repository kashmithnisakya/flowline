"""The week as a people by weekday grid: one row per person, one text cell per
day with its first lines, each led by the entry's kind glyph. Gaps stay empty,
which is the signal a standup exists to surface. Today's column is marked
with a primary rule; a cell opens that day.
"""

import from ...models { LogEntry }
import from ...constants { STATUS_KIND }
import from ..common.Avatar { Avatar }
import from ..common.KindGlyph { KindGlyph }

glob DAY_NAMES: list[str] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
     MAX_LINES: int = 2;

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

def kindOf(status: str) -> str {
    return STATUS_KIND[status] if status in STATUS_KIND else "active";
}

def glyphTone(kind: str) -> str {
    if kind == "done" {
        return "text-success";
    }
    if kind == "blocked" {
        return "text-destructive";
    }
    return "text-muted-foreground";
}


def:pub WeekMatrix(
    entries: list[LogEntry],
    weekDays: list[str],
    # Roster names come first (so a quiet person still gets a row); anyone
    # else who appears in the log is appended, then Unassigned if needed.
    memberNames: list[str],
    selectedDate: str,
    onSelectDate: Callable[[str], None],
    today: str = ""
) -> JsxElement {
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
            )
                > 0
    ];
    if len(rows) == 0 {
        return <span/>;
    }
    # One bucket per (person, day), newest first, so the grid does no filtering.
    cells: dict[str, list[LogEntry]] = {};
    for who in rows {
        for d in days {
            cells[who + "|" + d] = [];
        }
    }
    ordered = sorted(entries, key=lambda (e: LogEntry) { e.at; }, reverse=True);
    for e in ordered {
        for who in people(e) {
            key = who + "|" + e.date;
            if key in cells {
                cells[key].append(e);
            }
        }
    }
    return
        <div className="surface overflow-x-auto [--kind-knockout:var(--card)]">
            <div
                className="grid min-w-[46rem] [--who-col:8.5rem] md:[--who-col:11rem]"
                style={{
                    "gridTemplateColumns": "var(--who-col) repeat("
                        + str(len(days))
                        + ", minmax(0, 1fr))"
                }}
            >
                <div className="border-b"/>
                {for d in days {
                    <button
                        key={"h" + d}
                        type="button"
                        onClick={lambda { onSelectDate(d); }}
                        aria-current={"date" if d == today else None}
                        className={"border-b border-l px-2.5 py-2 text-left text-[12.5px] transition-colors hover:bg-accent "
                            + (
                                "font-semibold text-primary shadow-[inset_0_-2px_0_var(--primary)]"
                                    if d == today
                                    else "font-medium text-muted-foreground hover:text-foreground"
                            )}
                    >
                        {dayLabel(d)}
                    </button>
                }}
                {for (r, who) in enumerate(rows) {
                    <div key={who} className="contents">
                        <div
                            className={"flex min-w-0 items-center gap-2 px-3 py-2 text-[13.5px] font-medium "
                                + ("border-t" if r > 0 else "")}
                        >
                            <Avatar name={who} size="sm"/>
                            <span className="truncate">{who}</span>
                        </div>
                        {for d in days {
                            <button
                                key={who + d}
                                type="button"
                                onClick={lambda { onSelectDate(d); }}
                                title={who
                                    + " · "
                                    + dayLabel(d)
                                    + ": "
                                    + str(len(cells[who + "|" + d]))
                                    + " entries"}
                                className={"flex min-h-14 min-w-0 flex-col items-stretch gap-1 border-l px-2.5 py-2 text-left text-[13px] leading-snug transition-colors hover:bg-accent "
                                    + ("border-t" if r > 0 else "")}
                            >
                                {for (i, e) in enumerate(cells[who + "|" + d]) {
                                    if i < MAX_LINES {
                                        <span
                                            key={jid(e)}
                                            className="flex min-w-0 items-start gap-1.5"
                                        >
                                            <span
                                                className={"mt-[3px] "
                                                    + glyphTone(kindOf(e.status))}
                                            >
                                                <KindGlyph kind={kindOf(e.status)}/>
                                            </span>
                                            <span className="truncate">
                                                {e.task_title or e.activity}
                                            </span>
                                        </span>
                                    }
                                }}
                                {if len(cells[who + "|" + d]) > MAX_LINES {
                                    <span
                                        key="more"
                                        className="pl-5 text-xs text-muted-foreground"
                                    >
                                        {"+"
                                            + str(len(cells[who + "|" + d]) - MAX_LINES)
                                            + " more"}
                                    </span>
                                }}
                            </button>
                        }}
                    </div>
                }}
            </div>
        </div>;
}
