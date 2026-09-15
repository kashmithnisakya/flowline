"""Travel so far: one task's log entries, newest first, as a stamp column and a
sentence. Fetched from its creation day to today; a fresh `refreshKey` (the
task's updated_at) fetches again after a move. Renders nothing until there is
something to show."""

import from ...models { LogEntry }
import from ...services.log.log { ListLogEntries }
import from ...lib.dates { todayIso, daysUntil, prettyDay }

glob DAY_SHORT: list[str] = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
     # Without a creation day the history reaches back this far.
     FALLBACK_DAYS: int = 180;

def pad2(n: int) -> str {
    return ("0" + str(n))[-2:];
}

# "Mon 14 16:20" this week, "Sep 9 09:30" before it, "Sep 9" with no time.
def stampOf(row: LogEntry, today: str) -> str {
    if not row.at {
        return prettyDay(row.date);
    }
    d = new(Date, row.at);
    if isNaN(d.getTime()) {
        return prettyDay(row.date);
    }
    local = new(Date, d.getTime() - d.getTimezoneOffset() * 60000);
    day = local.toISOString()[:10];
    clock = pad2(int(d.getHours())) + ":" + pad2(int(d.getMinutes()));
    if daysUntil(day, today) > -7 {
        return DAY_SHORT[int(d.getDay())] + " " + str(int(d.getDate())) + " " + clock;
    }
    return prettyDay(day) + " " + clock;
}

def byStamp(row: LogEntry) -> str {
    return row.at or row.date;
}

def:pub TravelLog(taskId: str, since: str = "", refreshKey: str = "") -> JsxElement {
    has rows: list[LogEntry] = [];

    async can with (taskId, refreshKey) entry {
        # A day of slack each side: the server stamps log days on its own
        # clock, which can sit a date away from this browser's.
        today = todayIso();
        now = new(Date, today + "T00:00:00").getTime();
        base = now - FALLBACK_DAYS * 86400000;
        if len(since) >= 10 {
            base = new(Date, since[:10] + "T00:00:00").getTime();
        }
        start = new(Date, base - 86400000).toISOString()[:10];
        until = new(Date, now + 2 * 86400000).toISOString()[:10];
        try {
            result = root spawn ListLogEntries(
                from_date=start, to_date=until, task_id=taskId, page_size=200
            );
            page = result.reports[0] if result.reports else None;
            got: list[LogEntry] = page.rows if page else [];
            ordered = sorted(got, key=byStamp, reverse=True);
            rows = ordered;
        } except Exception as e {
            rows = [];
        }
    }

    today = todayIso();
    return
        <section
            className="grid gap-2"
            hidden={len(rows) == 0}
            aria-label="Travel so far"
        >
            <h3 className="text-[13px] font-semibold">Travel so far</h3>
            <ol className="border-t">
                {for row in rows {
                    <li
                        key={jid(row)}
                        className="grid grid-cols-[6.25rem_minmax(0,1fr)] gap-2.5 border-b py-2 text-[13px] leading-snug"
                    >
                        <time
                            className="num pt-px text-xs text-subtle"
                            dateTime={row.at or row.date}
                        >
                            {stampOf(row, today)}
                        </time>
                        <span className="min-w-0 break-words">
                            {row.activity}
                            {if row.notes {
                                <span key="note" className="text-muted-foreground">
                                    {" · " + row.notes}
                                </span>
                            }}
                        </span>
                    </li>
                }}
            </ol>
        </section>;
}
