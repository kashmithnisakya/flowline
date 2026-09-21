"""Server-only helpers. Kept out of models.jac so that module stays free of
Python imports, client components import types from models, and a Python
anchor there would drag the wasm host into the browser bundle."""

import datetime;
import uuid;
import from models {
    Task,
    Member,
    AssignedTo,
    projects_of,
    members_of,
    seeded_done,
    note_category,
    history_days,
    week_start
}


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


# A short id for an item stored inside a node field (a checklist row).
def short_id -> str {
    return uuid.uuid4().hex[:12];
}


# `value` as a canonical ISO day ("2026-09-14"), or "" when it is not one.
def iso_day(value: str) -> str {
    if not value or len(value) < 10 {
        return "";
    }
    try {
        return datetime.date.fromisoformat(value[:10]).isoformat();
    } except Exception {
        return "";
    }
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


# The day a task reached Done: `done_at`, or `updated_at` on rows written
# before the stamp existed, and never earlier than the day it was created.
def done_day(t: Task) -> str {
    day = (t.done_at or t.updated_at)[:10];
    made = t.created_at[:10];
    return made if made and day < made else day;
}


# Done that moved here, as opposed to a task created already Done (a closed
# issue filed by a GitHub backfill): that one is history, not throughput.
def moved_to_done(t: Task) -> bool {
    return t.status == "Done" and not seeded_done(t);
}


# Tallies and link fields for every project that has none yet (an empty
# `tallies_at`): one full load per such project, once. Every counting or
# listing walker calls this first; a stamped project costs one field read.
# Done rows from before `done_at` existed get it filled from done_day, so
# the pushed date predicates see them.
def ensure_tallies(holder: Root) -> None {
    pending = [
        p
        for p in projects_of(holder)
        if not p.tallies_at
    ];
    if not pending {
        return;
    }
    assigned: dict[str, list[str]] = {};
    for m in members_of(holder) {
        for t in [m<-:AssignedTo:<-[?:Task]] {
            key = jid(t);
            if key not in assigned {
                assigned[key] = [];
            }
            assigned[key].append(jid(m));
        }
    }
    stamp = now_iso();
    cats: list[str] = [];
    for p in pending {
        pid = jid(p);
        total = 0;
        done = 0;
        seeded = 0;
        for t in [p-->[?:Task]] {
            total = total + 1;
            if t.status == "Done" {
                if not t.done_at {
                    t.done_at = done_day(t);
                }
                done = done + 1;
                if seeded_done(t) {
                    seeded = seeded + 1;
                }
            }
            if t.project_id != pid {
                t.project_id = pid;
            }
            ids = assigned[jid(t)] if jid(t) in assigned else [];
            if t.assignee_ids != ids {
                t.assignee_ids = ids;
            }
            if t.category and t.category not in cats {
                cats.append(t.category);
            }
        }
        p.task_total = total;
        p.done_total = done;
        p.seeded_done_total = seeded;
        p.tallies_at = stamp;
    }
    for c in cats {
        note_category(holder, c);
    }
}


# The weekly history of every project that has none yet (an empty
# `history_at`): one full load per such project, once, after its tallies.
# TaskHistory calls this first; the writes keep it from then on.
def ensure_history(holder: Root) {
    stamp = now_iso();
    for p in projects_of(holder) {
        if p.history_at {
            continue;
        }
        added: dict[str, int] = {};
        finished: dict[str, int] = {};
        for t in [p-->[?:Task]] {
            days = history_days(t);
            for (counts, day) in [(added, days[0]), (finished, days[1])] {
                week = week_start(day);
                if week {
                    counts[week] = (counts[week] if week in counts else 0) + 1;
                }
            }
        }
        p.week_added = added;
        p.week_finished = finished;
        p.history_at = stamp;
    }
}


# The cutoff Done tasks fall behind is applied in the store's query
# (`done_at < cutoff` in the models readers), the same test as done_day
# once ensure_tallies has filled `done_at` on every Done row.
# Board order: the drag order the user arranged. Callers sort by jid first,
# so ties stay deterministic across two requests.
def order_working(rows: list[Task]) {
    rows.sort(key=lambda (t: Task) { t.sort_order; });
}
