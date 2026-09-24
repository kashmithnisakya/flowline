"""What a board row says about a task, as text: the due date as a person
says it, the reason line a blocked or overdue task carries, and whether the
task is late. Shared by the desktop cells and the phone meta line."""

import from ...models { TaskRow }
import from ...lib.dates { daysUntil, prettyDay, dueTone }

glob WEEKDAY: list[str] = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

# Today, tomorrow, a weekday within the week, else a short date. Overdue
# says how late; Done says nothing (history owns it).
def:pub dueWords(iso: str, status: str, today: str) -> str {
    if len(iso) < 10 or status == "Done" {
        return "";
    }
    diff = daysUntil(iso, today);
    if diff < 0 {
        late = 0 - diff;
        return str(late) + (" day late" if late == 1 else " days late");
    }
    if diff == 0 {
        return "Today";
    }
    if diff == 1 {
        return "Tomorrow";
    }
    if diff < 7 {
        d = new(Date, iso[:10] + "T00:00:00");
        return WEEKDAY[int(d.getDay())];
    }
    return prettyDay(iso);
}

# The note's first line without markdown or a move's date stamp
# ("**2026-09-14:** needs a device"); "" unless stamped or `anyLine`.
def leadNote(notes: str, anyLine: bool) -> str {
    first = (notes.strip() if notes else "").split("\n")[0].strip();
    stamped = first.startswith("**") and len(first) > 15 and first[12:15] == ":**";
    if not first or (not stamped and not anyLine) {
        return "";
    }
    if stamped {
        first = first[15:].strip();
    }
    first = first.replace("**", "").replace("`", "");
    while len(first) > 0 and first[0] in "#- " {
        first = first[1:];
    }
    return first.strip();
}

def:pub isLate(t: TaskRow, today: str) -> bool {
    return dueTone(t.due_date, t.status, today) == "overdue";
}

# The red line under a row: why a blocked task stopped, or why a late one
# is late. "" when the task is neither.
def:pub alertLine(t: TaskRow, today: str) -> str {
    if t.status == "Blocked" {
        return leadNote(t.note_lead, True);
    }
    if isLate(t, today) {
        return leadNote(t.note_lead, False);
    }
    return "";
}
