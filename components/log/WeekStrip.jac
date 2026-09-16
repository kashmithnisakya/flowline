"""The week at a glance: one pill per weekday (weekday, day, entry count),
click to jump. The selected day carries the ember accent, today a subtle
primary ring, weekends sit muted.
"""

import from ...models { LogEntry }

glob DAY_NAMES: list[str] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

def dayShift(iso: str, delta: int) -> str {
    d = new(Date, iso + "T00:00:00");
    d.setDate(d.getDate() + delta);
    shifted = new(Date, d.getTime() - d.getTimezoneOffset() * 60000);
    return shifted.toISOString()[:10];
}

def weekMonday(iso: str) -> str {
    d = new(Date, iso + "T00:00:00");
    offset = int((d.getDay() + 6) % 7);
    return dayShift(iso, -offset);
}

def todayIso -> str {
    d = new(Date);
    shifted = new(Date, d.getTime() - d.getTimezoneOffset() * 60000);
    return shifted.toISOString()[:10];
}

def:pub WeekStrip(
    entries: list[LogEntry],
    selectedDate: str = "",
    onSelectDate: Callable[[str], None] = None
) -> JsxElement {
    if not selectedDate {
        return <div className="hidden"/>;
    }
    monday = weekMonday(selectedDate);
    today = todayIso();

    return
        <div className="flex flex-wrap items-center gap-1.5">
            {for i in range(7) {
                <button
                    key={DAY_NAMES[i]}
                    type="button"
                    className={"flex min-w-16 flex-col items-center rounded-lg border px-3 py-1.5 transition active:scale-[0.97] "
                        + (
                            "border-primary bg-primary text-primary-foreground shadow-sm"
                                if dayShift(monday, i) == selectedDate
                                else (
                                    "border-primary/40 bg-card ring-1 ring-primary/30 hover:bg-accent"
                                        if dayShift(monday, i) == today
                                        else (
                                            "bg-card text-muted-foreground hover:bg-accent hover:text-foreground"
                                                if i >= 5
                                                else "bg-card hover:bg-accent"
                                        )
                                )
                        )}
                    onClick={lambda { if onSelectDate {
                        onSelectDate(dayShift(monday, i));
                    }}}
                >
                    <span
                        className="text-xs font-medium uppercase tracking-wide opacity-70"
                    >
                        {DAY_NAMES[i]}
                    </span>
                    <span
                        className="flex items-center gap-1 text-sm font-semibold tabular-nums"
                    >
                        {dayShift(monday, i)[8:]}
                        {if len(
                            [
                                e
                                for e in entries
                                if e.date == dayShift(monday, i)
                            ]
                        )
                            > 0 {
                            <span
                                key="count"
                                className={"inline-flex h-4 min-w-4 items-center justify-center rounded-full px-1 text-xs font-semibold leading-none tabular-nums "
                                    + (
                                        "bg-primary-foreground/25 text-primary-foreground"
                                            if dayShift(monday, i) == selectedDate
                                            else "bg-primary/10 text-primary"
                                    )}
                            >
                                {len(
                                    [
                                        e
                                        for e in entries
                                        if e.date == dayShift(monday, i)
                                    ]
                                )}
                            </span>
                        }}
                    </span>
                </button>
            }}
        </div>;
}
