"""The Overview worklist's rows and groups, plain data for NeedsYou to draw, and
the small count helpers they share with the page. Pure, pinned client."""

import from ...models { StepView, TaskRow }
import from ...constants { STATUS_KIND, KIND_COLORS }
import from ...lib.dates { daysUntil, prettyDay }

glob:pub DAY_LABELS: list[str] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

# A due date as the worklist reads it: "today", "tomorrow", a weekday later
# this week, a date after that, or how many days it is late.
def:pub relDay(iso: str, today: str) -> str {
    diff = daysUntil(iso, today);
    if diff < 0 {
        late = 0 - diff;
        return str(late) + (" day" if late == 1 else " days");
    }
    if diff == 0 {
        return "today";
    }
    if diff == 1 {
        return "tomorrow";
    }
    d = new(Date, iso[:10] + "T00:00:00");
    t = new(Date, today[:10] + "T00:00:00");
    dayIdx = int((d.getDay() + 6) % 7);
    if diff < 7 and dayIdx > int((t.getDay() + 6) % 7) {
        return DAY_LABELS[dayIdx];
    }
    return prettyDay(iso);
}

# When a blocked task stopped: "since today", "since yesterday", else a date.
def:pub sinceDay(iso: str, today: str) -> str {
    if len(iso) < 10 {
        return "";
    }
    ago = daysUntil(today, iso);
    if ago <= 0 {
        return "since today";
    }
    return "since yesterday" if ago == 1 else "since " + prettyDay(iso);
}

# A blocked reason's first line as plain text: move notes arrive as markdown
# with a "**2026-09-15:**" stamp in front.
def:pub plainLine(text: str) -> str {
    line = text.strip().split("\n")[0].replace("**", "").strip();
    if len(line) > 11 and line[4] == "-" and line[7] == "-" and line[10] == ":" {
        line = line[11:].strip();
    }
    return line;
}

def:pub plural(n: int, one: str, many: str) -> str {
    return str(n) + " " + (one if n == 1 else many);
}

def:pub countAll(xs: list[int]) -> int {
    n = 0;
    for x in xs {
        n = n + x;
    }
    return n;
}

def:pub splitNames(joined: str) -> list[str] {
    return [
        n.strip()
        for n in joined.split(",")
        if n.strip()
    ];
}

# The pill a row shows: the task's own step, else the first step of its
# status's kind by the legacy status (a task need not have a step).
def:pub stepChip(steps: list[StepView], stepId: str, status: str) -> dict[str, str] {
    for s in steps {
        if stepId and s.id == stepId {
            return {"name": s.name, "color": s.color, "kind": s.kind};
        }
    }
    kind = STATUS_KIND[status] if status in STATUS_KIND else "active";
    return {"name": status or "Open", "color": KIND_COLORS[kind], "kind": kind};
}

# One worklist row; the note, flags and step are filled in by the caller.
def:pub workRow(
    id: str, title: str, meta: str, names: list[str], time: str, late: bool, status: str
) -> dict[str, any] {
    return {
        "id": id,
        "title": title,
        "meta": meta,
        "note": "",
        "noteWarn": False,
        "names": names,
        "time": time,
        "late": late,
        "status": status,
        "step": {}
    };
}

def:pub dueRow(t: TaskRow, today: str) -> dict[str, any] {
    return workRow(
        t.id,
        t.title,
        t.project_name,
        t.assignee_names,
        relDay(t.due_date, today),
        t.due_date < today,
        t.status
    );
}

# Fills in a blocked row: its reason from the snapshot's blocked list
# (`info`), then a red due date when late, else the day it stopped.
def:pub withBlocked(
    row: dict[str, any], due: str, today: str, info: dict[str, any], since: str
) -> dict[str, any] {
    late = len(due) >= 10 and due < today;
    row["late"] = late;
    row["time"] = relDay(due, today) if late else sinceDay(since, today);
    row["note"] = plainLine(info["reason"]) if "reason" in info else "";
    return row;
}

# A review queue entry's context (reviewer note, PR, avatars) on a row, so a
# review that turns late keeps it in Overdue. `held` is the task, if read.
def:pub withReview(
    row: dict[str, any], r: dict[str, any], held: any
) -> dict[str, any] {
    reviewer = r["reviewer"];
    pr = "PR linked" if r["pr_link"] else "";
    if held and held.pr_number > 0 {
        pr = "PR #" + str(held.pr_number);
    }
    if reviewer {
        row["names"] = [reviewer];
    }
    row["meta"] = " · ".join(
        [
            part
            for part in [row["meta"], pr]
            if part
        ]
    );
    row["note"] = (reviewer.split(" ")[0] + " reviewing")
        if reviewer
        else "no reviewer";
    row["noteWarn"] = not reviewer;
    return row;
}

def:pub group(
    key: str, label: str, tone: str, rows: list[dict[str, any]], more: int, what: str
) -> dict[str, any] {
    return {
        "key": key,
        "label": label,
        "tone": tone,
        "rows": rows,
        "more": more,
        "moreLabel": what
    };
}
