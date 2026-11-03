"""Day arithmetic for the roadmap window. Days are read as UTC so DST never
shifts one, and positions are percentages of the window."""

glob DAY_MS: int = 86400000;

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
