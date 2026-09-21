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
    entry_key,
    note_entry,
    forget_entry
}
import from services.util { today_iso, shift_day, page_bounds, now_iso }

# ---------------------------------------------------------------- daily log

# A day written before its count and keys: key its entries and count them,
# once. Answers them newest first, because a query later in this request
# cannot see the new keys (a field write shows to the next request only).
def fill_day(day: LogDay) -> list[LogEntry] {
    rows = [day-->[?:LogEntry]];
    for r in rows {
        if not r.sort_key {
            r.sort_key = entry_key(r.at, r.date, jid(r));
        }
    }
    rows.sort(key=lambda (r: LogEntry) { r.sort_key; }, reverse=True);
    day.entry_total = len(rows);
    return rows;
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
        days = days_between(root, self.from_date, self.to_date);
        # Newest day first; two days on one date (a racing first write) keep
        # one order between requests.
        days.sort(key=lambda (d: LogDay) { jid(d); });
        days.sort(key=lambda (d: LogDay) { d.date; }, reverse=True);
        if self.task_id {
            report self.task_page(days, p, size, start, end);
        } else {
            report self.range_page(days, p, size, start, end);
        }
    }

    # Whole days before the page are skipped on their counts and each day in
    # it answers only its slice. A short slice means the count drifted, so
    # that day is counted again and paged from what it loaded.
    def range_page(
        days: list[LogDay], p: int, size: int, start: int, end: int
    ) -> LogPage {
        loaded: dict[str, list[LogEntry]] = {};
        for d in days {
            if d.entry_total < 0 {
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
                part = self.day_slice(d, offset, stop, loaded);
                # A recount can leave the day shorter than the offset.
                if offset < d.entry_total {
                    rows.extend(part);
                    offset = 0;
                    continue;
                }
            }
            offset = offset - d.entry_total;
        }
        total = 0;
        for d in days {
            total = total + d.entry_total;
        }
        return LogPage(
            rows=rows, page=p, page_size=size, has_more=total > end, total=total
        );
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

    # A task's rows: the filter runs in the store, so only they load, then
    # they sort and page here in the range's order.
    def task_page(
        days: list[LogDay], p: int, size: int, start: int, end: int
    ) -> LogPage {
        found: list[LogEntry] = [];
        for d in days {
            part = day_task_entries(d, self.task_id);
            part.sort(
                key=lambda (r: LogEntry) { entry_key(r.at, r.date, jid(r)); },
                reverse=True
            );
            found.extend(part);
        }
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
# person logged on. Reads node fields only, so row volume does not change cost.
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
        for row in [day-->[?:LogEntry]] {
            for i in range(4) {
                if row.date >= starts[i] and row.date < ends[i] {
                    by_week[i] = by_week[i] + 1;
                }
            }
            if row.date < week0 {
                continue;
            }
            slot = -1;
            for i in range(7) {
                if row.date == week_days[i] {
                    slot = i;
                }
            }
            if slot < 0 {
                continue;
            }
            by_day[slot] = by_day[slot] + 1;
            for who in row.member_name.split(",") {
                name = who.strip();
                if not name {
                    continue;
                }
                if name not in per_person {
                    per_person[name] = [0, 0, 0, 0, 0, 0, 0];
                }
                per_person[name][slot] = per_person[name][slot] + 1;
            }
        }
    }
    people: list[MemberDays] = [];
    for name in per_person {
        counts = per_person[name];
        people.append(MemberDays(name=name, by_day=counts, total=sum(counts)));
    }
    return LogTotals(by_week=by_week, by_day=by_day, members=people);
}


walker LogCounts {
    """The Overview's log numbers over the four weeks ending in `monday`'s
    week."""
    has monday: str = "",
        reports: list[LogTotals] = [];

    can count with Root entry {
        report log_totals(here, self.monday);
    }
}


walker LogActivity {
    """Visit the Logs box, get-or-create the day in it, then append one
    denormalized row under the day. Refuses writes no view could fetch
    (empty date) or that would produce a blank authorless row (bad member)."""
    has date: str,
        member_id: str,
        activity: str,
        project_id: str = "",
        category: str = "",
        repo: str = "",
        issue_link: str = "",
        pr_link: str = "",
        status: str = "",
        notes: str = "",
        reports: list[LogEntry] = [];

    can start with Root entry {
        if not self.date {
            disengage;
        }
        probe = resolve(self.member_id);
        if not isinstance(probe, Member) or not owned(here, probe) {
            disengage;
        }
        visit logs_box(here);
    }

    # One day per date: an existing one anywhere in the log, else a new one
    # in this box.
    can open_day with Logs entry {
        days = days_between(root, self.date, self.date);
        if days {
            visit [days[0]];
        } else {
            fresh = here ++> LogDay(date=self.date, entry_total=0);
            on_attached(root, fresh);
            visit fresh;
        }
    }

    can add with LogDay entry {
        # `here` is the LogDay; `root` is the caller's own root.
        holder = root;
        member_name = "";
        tags_snap = "";
        m = resolve(self.member_id);
        if isinstance(m, Member) {
            member_name = m.full_name();
            tags_snap = ", ".join(m.tags);
        }
        project_name = "";
        p = resolve(self.project_id);
        if isinstance(p, Project) and owned(holder, p) {
            project_name = p.name;
        }
        # Stamped like the automatic rows, so the time column and the
        # digest's ordering treat manual entries the same way.
        row = here ++> LogEntry(
            date=here.date,
            at=now_iso(),
            activity=self.activity,
            category=self.category,
            repo=self.repo,
            issue_link=self.issue_link,
            pr_link=self.pr_link,
            status=self.status,
            notes=self.notes,
            member_name=member_name,
            tags=tags_snap,
            project_name=project_name
        );
        note_entry(here, row);
        if isinstance(m, Member) {
            row +>:By():+> m;
        }
        report row;
        disengage;
    }
}

# The log day for a date, made on first write.
def log_day(holder: Root, date: str) -> LogDay {
    days = days_between(holder, date, date);
    if days {
        return days[0];
    }
    day = logs_box(holder) ++> LogDay(date=date, entry_total=0);
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
                "Imported from GitHub "
                    + first.gh_repo
                    + " #"
                    + str(first.gh_issue_number),
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
    matches = [
        r
        for r in [days[0]-->[?:LogEntry]]
        if r.task_id == jid(task)
    ];
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

walker find_log_entry {
    """Lookup base for log-entry mutations: resolve the jid, check it is ours
    (LogEntry <- LogDay <- Logs <- root, the owned() climb), then visit."""
    has entry_id: str = "";

    can locate with Root entry {
        target = resolve(self.entry_id);
        if isinstance(target, LogEntry) and owned(here, target) {
            visit [target];
        }
    }
}

walker UpdateLogEntry(find_log_entry) {
    has activity: str = "",
        category: str = "",
        repo: str = "",
        issue_link: str = "",
        pr_link: str = "",
        status: str = "",
        notes: str = "",
        reports: list[LogEntry] = [];

    can apply with LogEntry entry {
        here.activity = self.activity;
        here.category = self.category;
        here.repo = self.repo;
        here.issue_link = self.issue_link;
        here.pr_link = self.pr_link;
        here.status = self.status;
        here.notes = self.notes;
        report here;
        disengage;
    }
}

walker DeleteLogEntries {
    """Bulk delete: every id is ownership-checked before removal, the same
    rule as the single-entry lookup base."""
    has entry_ids: list[str] = [];

    can remove with Root entry {
        gone: list[str] = [];
        for eid in self.entry_ids {
            target = resolve(eid);
            if isinstance(target, LogEntry) and owned(here, target) {
                gone.append(jid(target));
                forget_entry(target);
                del target;
            }
        }
        report {"deleted": gone};
    }
}
