"""Day arithmetic for the roadmap window. Days are read as UTC so DST never
shifts one, and positions are percentages of the window."""

glob DAY_MS: int = 86400000,
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
     ];

def:pub dayNumber(iso: str) -> int {
    return int(new(Date, iso + "T00:00:00Z").getTime() / DAY_MS + 0.5);
}

def:pub isoOfDay(n: int) -> str {
    return new(Date, n * DAY_MS).toISOString()[:10];
}

def:pub shiftIso(iso: str, days: int) -> str {
    return isoOfDay(dayNumber(iso) + days);
}

# The Monday on or before a day. Day 0 of the epoch was a Thursday, so
# (days + 3) % 7 counts days since Monday without a locale.
def:pub mondayOf(iso: str) -> str {
    return shiftIso(iso, -((dayNumber(iso) + 3) % 7));
}

def:pub pct(days: int, total: int) -> str {
    return str(days * 100.0 / total) + "%";
}

# Left edge and width of [first, last] (inclusive days) inside a window of
# `total` days from day `origin`, clipped to it, never under 24px wide.
def:pub spanStyle(first: str, last: str, origin: int, total: int) -> dict[str, str] {
    a = dayNumber(first) - origin;
    b = dayNumber(last) - origin + 1;
    a = 0 if a < 0 else a;
    b = total if b > total else b;
    width = b - a if b > a else 1;
    return {"left": pct(a, total), "width": "max(24px, " + pct(width, total) + ")"};
}

# Month cells on the real first of each month; a sliver under a week keeps
# no label.
def:pub monthCells(origin: int, total: int) -> list[dict[str, str]] {
    cells: list[dict[str, str]] = [];
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
        cells.append(
            {
                "key": iso[:7],
                "label": MONTHS[month - 1] + " " + str(year) if end - day >= 7 else "",
                "left": pct(day - origin, total),
                "width": pct(end - day, total)
            }
        );
        day = end;
    }
    return cells;
}
