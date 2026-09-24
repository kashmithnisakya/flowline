"""Daily-log walkers: day buckets under the Logs box and their entries."""

import from models {
    Project,
    Member,
    Task,
    LogDay,
    LogEntry,
    LogPage,
    LogTotals,
    MemberDays,
    Logs,
    By,
    AssignedTo,
    resolve,
    on_attached,
    owned,
    logs_box,
    days_between,
    day_entries,
    day_task_entries,
    day_import_lines,
    task_entries_between,
    entry_key,
    entry_people,
    note_entry,
    forget_entry
}
import from services.util { today_iso, shift_day, page_bounds, now_iso }

# ---------------------------------------------------------------- daily log

glob IMPORT_PREFIX: str = "Imported from GitHub ",
     IMPORT_FOLD_MIN: int = 10;

# A day written before its tallies: fold its backfill, key its entries and
# count them, once. Answers them newest first, because a query later in this
# request cannot see the new keys (a field write shows to the next request).
def fill_day(day: LogDay) -> list[LogEntry] {
    rows = fold_imports(day, [day-->[?:LogEntry]]);
    counts: dict[str, int] = {};
    for r in rows {
        if not r.sort_key {
            r.sort_key = entry_key(r.at, r.date, jid(r));
        }
        for name in entry_people(r.member_name) {
            counts[name] = (counts[name] if name in counts else 0) + 1;
        }
    }
    rows.sort(key=lambda (r: LogEntry) { r.sort_key; }, reverse=True);
    day.entry_total = len(rows);
    day.member_counts = counts;
    day.tallied = True;
    return rows;
}


# A backfill from before batch lines wrote one "Imported from GitHub
# org/repo #n" line per issue. More than IMPORT_FOLD_MIN of them for one repo
# and status on a day become that day's batch line, as log_imports writes it.
def fold_imports(day: LogDay, rows: list[LogEntry]) -> list[LogEntry] {
    batches: dict[str, list[LogEntry]] = {};
    order: list[str] = [];
    for r in rows {
        if r.task_id and r.activity.startswith(IMPORT_PREFIX) {
            key = r.activity[len(IMPORT_PREFIX):].split(" #")[0] + "|" + r.status;
            if key not in batches {
                batches[key] = [];
                order.append(key);
            }
            batches[key].append(r);
        }
    }
    gone: list[str] = [];
    made: list[LogEntry] = [];
    for key in order {
        batch = batches[key];
        if len(batch) <= IMPORT_FOLD_MIN {
            continue;
        }
        full_name = key.split("|")[0];
        status = batch[0].status;
        latest = "";
        for r in batch {
            latest = r.at if r.at > latest else latest;
        }
        lines = [
            e
            for e in rows
            if not e.task_id
                and e.item_count > 0
                and e.repo == full_name
                and e.status == status
        ];
        if lines {
            line = lines[0];
            line.item_count = line.item_count + len(batch);
            line.at = latest if latest > line.at else line.at;
            line.activity = import_line(line.item_count, full_name, status == "Done");
            line.sort_key = entry_key(line.at, line.date, jid(line));
        } else {
            made.append(
                day ++> LogEntry(
                    date=day.date,
                    at=latest,
                    activity=import_line(len(batch), full_name, status == "Done"),
                    repo=full_name,
                    status=status,
                    project_name=batch[0].project_name,
                    item_count=len(batch)
                )
            );
        }
        for r in batch {
            gone.append(jid(r));
            del r;
        }
    }
    kept = [
        r
        for r in rows
        if jid(r) not in gone
    ];
    return kept + made;
}


# The days in [since, until], newest first; two days on one date (a racing
# first write) keep one order between requests.
def days_newest_first(holder: Root, since: str, until: str) -> list[LogDay] {
    days = days_between(holder, since, until);
    days.sort(key=lambda (d: LogDay) { jid(d); });
    days.sort(key=lambda (d: LogDay) { d.date; }, reverse=True);
    return days;
}


# Rows [start, start + size) of `days` (newest first), each day newest stamp
# first. Whole days before the window are skipped on their counts and each
# day in it answers only its slice. A short slice means the count drifted,
# so that day is counted again and paged from what it loaded.
def range_rows(days: list[LogDay], start: int, size: int) -> list[LogEntry] {
    loaded: dict[str, list[LogEntry]] = {};
    for d in days {
        if not d.tallied {
            loaded[jid(d)] = fill_day(d);
        }
    }
    rows: list[LogEntry] = [];
    offset = start;
    for d in days {
        if len(rows) >= size {
            break;
        }
        if offset < d.entry_total {
            stop = min(d.entry_total, offset + size - len(rows));
            part = day_slice(d, offset, stop, loaded);
            # A recount can leave the day shorter than the offset.
            if offset < d.entry_total {
                rows.extend(part);
                offset = 0;
                continue;
            }
        }
        offset = offset - d.entry_total;
    }
    return rows;
}


# How many entries the days hold, from their counts (range_rows fills a day
# not yet counted, so call it first).
def range_total(days: list[LogDay]) -> int {
    total = 0;
    for d in days {
        total = total + d.entry_total;
    }
    return total;
}


# Rows [offset, stop) of one day: from the store, or from fill_day's load
# when the day was counted in this request or the store came back short.
def day_slice(
    d: LogDay, offset: int, stop: int, loaded: dict[str, list[LogEntry]]
) -> list[LogEntry] {
    key = jid(d);
    if key not in loaded {
        part = day_entries(d, offset, stop);
        if len(part) == stop - offset {
            return part;
        }
        loaded[key] = fill_day(d);
    }
    return loaded[key][offset:stop];
}


walker ListLogEntries {
    """One page of the entries in [from_date, to_date], newest day first and
    newest stamp first within a day, so a later page lands under the rows on
    screen. `total` is the whole range, from the day counts. A `task_id`
    keeps only that task's rows (the task sheet's history), before paging."""
    has from_date: str,
        to_date: str,
        page: int = 1,
        page_size: int = 0,
        task_id: str = "",
        reports: list[LogPage] = [];

    # A read never makes the box: no box, an empty page. The FIRST box only,
    # so a second box a racing first write left cannot report twice.
    can start with Root entry {
        boxes = [here-->[?:Logs]];
        if boxes {
            visit [boxes[0]];
        } else {
            (p, size, start, end) = page_bounds(self.page, self.page_size, 200, 500);
            report LogPage(rows=[], page=p, page_size=size, has_more=False, total=0);
        }
    }

    can gather with Logs entry {
        (p, size, start, end) = page_bounds(self.page, self.page_size, 200, 500);
        if self.task_id {
            report self.task_page(root, p, size, start, end);
        } else {
            days = days_newest_first(root, self.from_date, self.to_date);
            rows = range_rows(days, start, size);
            total = range_total(days);
            report LogPage(
                rows=rows, page=p, page_size=size, has_more=total > end, total=total
            );
        }
    }

    # A task's rows (the task sheet's history): one query across the range's
    # days loads them and nothing else, however many days the range spans;
    # they sort and page here in the range's order.
    def task_page(holder: Root, p: int, size: int, start: int, end: int) -> LogPage {
        found = task_entries_between(
            holder, self.task_id, self.from_date, self.to_date
        );
        found.sort(
            key=lambda (r: LogEntry) { r.date
                + "|"
                + entry_key(r.at, r.date, jid(r)); },
            reverse=True
        );
        return LogPage(
            rows=found[start:end],
            page=p,
            page_size=size,
            has_more=len(found) > end,
            total=len(found)
        );
    }
}

# The Overview's log numbers: entries per week for the four weeks ending in
# `monday`'s week (oldest first), per weekday of that week, and which days each
# person logged on. Reads the days' tallies, never their entries.
def log_totals(holder: Root, monday: str) -> LogTotals {
    week0 = monday if len(monday) >= 10 else today_iso();
    starts = [shift_day(week0, -7 * (3 - i)) for i in range(4)];
    since = starts[0];
    until = shift_day(week0, 6);
    week_days = [shift_day(week0, i) for i in range(7)];
    # Week bounds up front, for the same reason as task_totals.
    ends = [shift_day(starts[i], 7) for i in range(4)];
    by_week = [0, 0, 0, 0];
    by_day = [0, 0, 0, 0, 0, 0, 0];
    per_person: dict[str, list[int]] = {};
    for day in days_between(holder, since, until) {
        if not day.tallied {
            fill_day(day);
        }
        n = day.entry_total;
        for i in range(4) {
            if day.date >= starts[i] and day.date < ends[i] {
                by_week[i] = by_week[i] + n;
            }
        }
        if day.date < week0 {
            continue;
        }
        slot = -1;
        for i in range(7) {
            if day.date == week_days[i] {
                slot = i;
            }
        }
        if slot < 0 {
            continue;
        }
        by_day[slot] = by_day[slot] + n;
        for name in day.member_counts {
            if name not in per_person {
                per_person[name] = [0, 0, 0, 0, 0, 0, 0];
            }
            per_person[name][slot] = per_person[name][slot] + day.member_counts[name];
        }
    }
    people: list[MemberDays] = [];
    for name in per_person {
        counts = per_person[name];
        people.append(MemberDays(name=name, by_day=counts, total=sum(counts)));
    }
    return LogTotals(by_week=by_week, by_day=by_day, members=people);
}


# The log day for a date, made on first write.
def log_day(holder: Root, date: str) -> LogDay {
    days = days_between(holder, date, date);
    if days {
        return days[0];
    }
    day = logs_box(holder) ++> LogDay(date=date, entry_total=0, tallied=True);
    on_attached(holder, day);
    return day;
}

# Board moves write the log now: append one denormalized row describing a
# task event to today's bucket. Called from the task walkers.
def record_task_event(holder: Root, task: Task, activity: str, stamp: str) -> None {
    today = stamp[:10];
    if not today {
        return;
    }
    day = log_day(holder, today);
    names: list[str] = [];
    tag_pool: list[str] = [];
    for a in [task->:AssignedTo:->] {
        names.append(a.full_name());
        for t in a.tags {
            if t not in tag_pool {
                tag_pool.append(t);
            }
        }
    }
    projects = [task<--[?:Project]];
    row = day ++> LogEntry(
        date=today,
        at=stamp,
        task_id=jid(task),
        task_title=task.title,
        activity=activity,
        category=task.category,
        repo="",
        issue_link=task.issue_link,
        pr_link=task.pr_link,
        status=task.status,
        notes="",
        member_name=", ".join(names),
        tags=", ".join(tag_pool),
        project_name=projects[0].name if projects else ""
    );
    note_entry(day, row);
}

# Imported issues reach the log once per batch. A batch of one keeps its own
# line (the task sheet's history shows it); a bigger one grows the day's
# line for its repo and status, so a backfill of 1,400 issues is one row.
def log_imports(holder: Root, fresh: list[Task], stamp: str) {
    batches: dict[str, list[Task]] = {};
    order: list[str] = [];
    for t in fresh {
        key = t.gh_repo + "|" + t.status;
        if key not in batches {
            batches[key] = [];
            order.append(key);
        }
        batches[key].append(t);
    }
    for key in order {
        batch = batches[key];
        first = batch[0];
        if len(batch) == 1 {
            record_task_event(
                holder,
                first,
                IMPORT_PREFIX + first.gh_repo + " #" + str(first.gh_issue_number),
                stamp
            );
        } else {
            note_import_batch(holder, batch, stamp);
        }
    }
}

# "Imported 3 issues from org/repo", "closed issues" when they landed Done:
# the sentence the log page folds single import lines into.
def import_line(n: int, full_name: str, closed: bool) -> str {
    return "Imported "
        + str(n)
        + (" closed issues" if closed else " issues")
        + " from "
        + full_name;
}

# Grow today's import line for the batch's repo and status, or start it.
def note_import_batch(holder: Root, batch: list[Task], stamp: str) -> None {
    first = batch[0];
    closed = first.status == "Done";
    day = log_day(holder, stamp[:10]);
    for e in day_import_lines(day, first.gh_repo) {
        if e.item_count > 0 and e.status == first.status {
            e.item_count = e.item_count + len(batch);
            e.activity = import_line(e.item_count, first.gh_repo, closed);
            e.at = stamp;
            e.sort_key = entry_key(stamp, e.date, jid(e));
            return;
        }
    }
    projects = [first<--[?:Project]];
    row = day ++> LogEntry(
        date=day.date,
        at=stamp,
        activity=import_line(len(batch), first.gh_repo, closed),
        repo=first.gh_repo,
        status=first.status,
        project_name=projects[0].name if projects else "",
        item_count=len(batch)
    );
    note_entry(day, row);
}

# The move handoff arrives after the move row was written; refresh the
# latest row for this task today so its links and note show in the feed.
def sync_task_links(holder: Root, task: Task, note: str) -> None {
    today = task.updated_at[:10];
    days = days_between(holder, today, today);
    if not days {
        return;
    }
    matches = day_task_entries(days[0], jid(task));
    if not matches {
        return;
    }
    matches.sort(key=lambda (r: LogEntry) { r.at; });
    target = matches[-1];
    target.issue_link = task.issue_link;
    target.pr_link = task.pr_link;
    if note {
        target.notes = note;
    }
}
