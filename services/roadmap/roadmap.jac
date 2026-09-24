"""The roadmap's one read: every task with a start or due date that touches
the window, earliest first."""

import from models {
    Project,
    Task,
    TaskRow,
    hydrate_rows,
    resolve,
    owned,
    project_open,
    done_in_window
}
import from services.util { today_iso, shift_day, iso_day, ensure_tallies }

glob ROADMAP_MAX_ROWS: int = 400;

obj RoadmapData {
    """The tasks whose span overlaps the window, with that span (`starts` /
    `ends` index-aligned with `rows`), plus the open tasks with no dates."""
    has from_date: str,
        to_date: str,
        rows: list[TaskRow],
        starts: list[str],
        ends: list[str],
        unscheduled: int,
        total: int,
        truncated: bool;
}


# A task's place in time: its start and due dates, each falling back to the
# other. ["", ""] when neither is set.
def task_span(t: Task) -> list[str] {
    start = iso_day(t.start_date);
    due = iso_day(t.due_date);
    first = start or due;
    last = due or start;
    if first and last and first > last {
        return [last, first];
    }
    return [first, last];
}


walker RoadmapSnapshot {
    """One project's roadmap for [from_date, to_date], at most
    ROADMAP_MAX_ROWS rows; a foreign or unknown project reads empty. A bad
    window reads as two weeks back to eight ahead. Only open tasks and the
    Done tasks whose dates touch the window are loaded, never the history."""
    has from_date: str = "",
        to_date: str = "",
        project_id: str = "",
        reports: list[RoadmapData] = [];

    can start with Root entry {
        ensure_tallies(here);
        p = resolve(self.project_id) if self.project_id else None;
        if isinstance(p, Project) and owned(here, p) {
            visit [p];
        } else {
            report self.plan(here, [], "");
        }
    }

    can gather with Project entry {
        report self.plan(root, project_open(here), jid(here));
        disengage;
    }

    # `open` is the project's open tasks; its Done candidates are read
    # workspace-wide and kept by their project link. No project, no rows.
    def plan(holder: Root, open: list[Task], only: str) -> RoadmapData {
        lo = iso_day(self.from_date);
        hi = iso_day(self.to_date);
        if not lo or not hi or lo > hi {
            lo = shift_day(today_iso(), -14);
            hi = shift_day(today_iso(), 56);
        }
        pool = open;
        if only {
            for t in done_in_window(holder, lo, hi) {
                if t.project_id == only {
                    pool.append(t);
                }
            }
        }
        placed: list[list[any]] = [];
        unscheduled = 0;
        for t in pool {
            span = task_span(t);
            if not span[0] {
                if t.status != "Done" {
                    unscheduled = unscheduled + 1;
                }
                continue;
            }
            if span[0] <= hi and span[1] >= lo {
                placed.append([t, span[0], span[1]]);
            }
        }
        placed.sort(key=lambda (row: list[any]) { jid(row[0]); });
        placed.sort(key=lambda (row: list[any]) { row[1]; });
        page = placed[:ROADMAP_MAX_ROWS];
        tasks: list[Task] = [row[0] for row in page];
        return RoadmapData(
            from_date=lo,
            to_date=hi,
            rows=hydrate_rows(holder, tasks),
            starts=[str(row[1]) for row in page],
            ends=[str(row[2]) for row in page],
            unscheduled=unscheduled,
            total=len(placed),
            truncated=len(placed) > ROADMAP_MAX_ROWS
        );
    }
}
