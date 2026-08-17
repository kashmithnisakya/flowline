"""Client-side day helpers shared by the board card and the overview: today as
a local ISO day, whole-day distances, and a due date rendered as urgency
("Tomorrow", "3d overdue") instead of a bare date.
"""

glob MONTH_SHORT: list[str] = [
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
     ];

# Local calendar day, not UTC: a task due "today" must not flip at 5:30 IST.
def:pub todayIso -> str {
    d = new(Date);
    shifted = new(Date, d.getTime() - d.getTimezoneOffset() * 60000);
    return shifted.toISOString()[:10];
}

# "2026-08-07" -> "Aug 7"; anything that is not a full ISO day passes through.
def:pub prettyDay(iso: str) -> str {
    if len(iso) < 10 {
        return iso;
    }
    return MONTH_SHORT[int(iso[5:7]) - 1] + " " + str(int(iso[8:10]));
}

# Whole days from `fromIso` to `iso`, negative when `iso` is in the past.
# Rounded, so a DST hour in between does not turn 1 day into 0.96.
def:pub daysUntil(iso: str, fromIso: str) -> int {
    a = new(Date, iso[:10] + "T00:00:00");
    b = new(Date, fromIso[:10] + "T00:00:00");
    return int(Math.round((a.getTime() - b.getTime()) / 86400000));
}

# "overdue" (past, still open), "soon" (within two days), or "" (later, or
# done). Done tasks never carry urgency: the date is history by then.
def:pub dueTone(iso: str, status: str, today: str) -> str {
    if len(iso) < 10 or status == "Done" {
        return "";
    }
    diff = daysUntil(iso, today);
    if diff < 0 {
        return "overdue";
    }
    if diff <= 2 {
        return "soon";
    }
    return "";
}

def:pub dueLabel(iso: str, status: str, today: str) -> str {
    if len(iso) < 10 {
        return iso;
    }
    tone = dueTone(iso, status, today);
    if tone == "" {
        return prettyDay(iso);
    }
    diff = daysUntil(iso, today);
    if diff < 0 {
        return str(-diff) + "d overdue";
    }
    if diff == 0 {
        return "Today";
    }
    if diff == 1 {
        return "Tomorrow";
    }
    return "In " + str(diff) + " days";
}
