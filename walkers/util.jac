"""Server-only helpers. Kept out of models.jac so that module stays free of
Python imports, client components import types from models, and a Python
anchor there would drag the wasm host into the browser bundle."""

import datetime;
import from models { Task }


def now_iso -> str {
    return datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None).isoformat()
        + "Z";
}


# Age of a now_iso() stamp. An unreadable or empty stamp reads as ancient so
# that callers expiring a one-shot token fail closed.
def minutes_since(stamp: str) -> float {
    if not stamp {
        return 999999.0;
    }
    try {
        then = datetime.datetime.fromisoformat(stamp.replace("Z", ""));
    } except Exception {
        return 999999.0;
    }
    now = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None);
    return (now - then).total_seconds() / 60.0;
}


# `iso` shifted by `days` (negative for earlier), as an ISO day. Anything that
# is not a full ISO day passes through unchanged.
def shift_day(iso: str, days: int) -> str {
    if len(iso) < 10 {
        return iso;
    }
    try {
        d = datetime.date.fromisoformat(iso[:10]);
    } except Exception {
        return iso;
    }
    return (d + datetime.timedelta(days=days)).isoformat();
}


def today_iso -> str {
    return now_iso()[:10];
}


# Task tags as stored: trimmed, no empties, first occurrence wins. Shared by
# the task walkers and the GitHub import so no writer invents its own rules.
def clean_tags(raw: list[str]) -> list[str] {
    kept: list[str] = [];
    for t in raw {
        name = str(t).strip();
        if name and name not in kept {
            kept.append(name);
        }
    }
    return kept;
}


# Page arithmetic shared by every list walker: a 1-based page, a size clamped
# to [1, cap], and the slice bounds. `page_size` 0 asks for the default.
def page_bounds(
    page: int, page_size: int, fallback: int, cap: int
) -> tuple[int, int, int, int] {
    size = page_size if page_size > 0 else fallback;
    if size > cap {
        size = cap;
    }
    p = page if page > 0 else 1;
    start = (p - 1) * size;
    return (p, size, start, start + size);
}


# The cutoff Done tasks fall behind, "" when history is not being trimmed.
def done_cutoff(done_days: int) -> str {
    return shift_day(today_iso(), 0 - done_days) if done_days > 0 else "";
}


# A Done task last touched before the cutoff: history, not the working set.
# Shared by the list walkers and the board so the split has one definition.
def is_older(t: Task, cutoff: str) -> bool {
    return t.status == "Done" and bool(cutoff) and t.updated_at[:10] < cutoff;
}


# Board order: the drag order the user arranged. Callers sort by jid first,
# so ties stay deterministic across two requests.
def order_working(rows: list[Task]) {
    rows.sort(key=lambda (t: Task) { t.sort_order; });
}
