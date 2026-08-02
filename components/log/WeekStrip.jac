"""The week at a glance: one pill per weekday, click to jump to that day.

Each pill shows the weekday, day-of-month and entry count; the selected
day carries the ember accent.
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

def:pub WeekStrip(
    entries: list[LogEntry],
    selectedDate: str = "",
    onSelectDate: Callable[[str], None] = None
) -> JsxElement {
    if not selectedDate {
        return <div className="hidden" />;
    }
    monday = weekMonday(selectedDate);

    return <div className="flex flex-wrap items-center gap-1.5">
        {for i in range(7) {
            <button
                key={DAY_NAMES[i]}
                type="button"
                className={
                    "flex min-w-16 flex-col items-center rounded-lg border px-3 py-1.5 transition-colors "
                    + (
                        "border-primary bg-primary text-primary-foreground"
                        if dayShift(monday, i) == selectedDate
                        else "bg-card hover:bg-accent"
                    )
                }
                onClick={lambda { if onSelectDate { onSelectDate(dayShift(monday, i)); } }}
            >
                <span className="text-[11px] font-medium uppercase tracking-wide opacity-70">
                    {DAY_NAMES[i]}
                </span>
                <span className="text-sm font-semibold">
                    {dayShift(monday, i)[8:]}
                    {if len([e for e in entries if e.date == dayShift(monday, i)]) > 0 {
                        <span key="count" className="ml-1 text-xs opacity-70">
                            ·{len([e for e in entries if e.date == dayShift(monday, i)])}
                        </span>
                    }}
                </span>
            </button>
        }}
    </div>;
}
