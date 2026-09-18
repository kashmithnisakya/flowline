"""Iteration walkers: the time boxes a workspace plans in, and the roadmap's
one read. Iterations hang off their box; a task points at one through
Task.iteration_id, so deleting an iteration clears that field on its tasks."""

import from models {
    Iteration,
    Iterations,
    Project,
    Task,
    TaskView,
    IterationView,
    iteration_view,
    iterations_box,
    iterations_of,
    hydrate_views,
    resolve,
    on_attached,
    owned,
    open_tasks,
    project_open,
    done_in_window,
    tasks_in_iteration
}
import from services.util { now_iso, today_iso, shift_day, iso_day, ensure_tallies }

glob ROADMAP_MAX_ROWS: int = 400;

obj RoadmapData {
    """The roadmap window: its iterations, and the tasks whose span overlaps
    it with that span (`starts` / `ends` index-aligned with `rows`), plus the
    open tasks nothing places in time."""
    has from_date: str,
        to_date: str,
        iterations: list[IterationView],
        rows: list[TaskView],
        starts: list[str],
        ends: list[str],
        unscheduled: int,
        total: int,
        truncated: bool;
}


# A task's place in time: its start and due dates, each falling back to its
# iteration's span, then to the other date. ["", ""] when nothing places it.
def task_span(t: Task, spans: dict[str, list[str]]) -> list[str] {
    start = iso_day(t.start_date);
    due = iso_day(t.due_date);
    box = spans[t.iteration_id] if t.iteration_id in spans else ["", ""];
    first = start or box[0] or due;
    last = due or box[1] or start;
    if first and last and first > last {
        return [last, first];
    }
    return [first, last];
}


def iteration_order(rows: list[IterationView]) {
    rows.sort(key=lambda (v: IterationView) { v.id; });
    rows.sort(key=lambda (v: IterationView) { v.start_date; });
}


walker ListIterations {
    """Every iteration, earliest first. A read never makes the box."""
    has reports: list[list[IterationView]] = [];

    can start with Root entry {
        visit [here-->[?:Iterations]] else {
            report [];
        }
    }

    can gather with Iterations entry {
        rows = [iteration_view(it) for it in [here-->[?:Iteration]]];
        iteration_order(rows);
        report rows;
    }
}


walker SaveIteration {
    """Create an iteration (no `iteration_id`) or update the addressed one.
    The name is required and dates are ISO days with start on or before end;
    anything else is refused with {"ok": False}."""
    has iteration_id: str = "",
        name: str = "",
        start_date: str = "",
        end_date: str = "",
        reports: list[dict[str, any]] = [];

    can start with Root entry {
        self.name = self.name.strip()[:80];
        self.start_date = iso_day(self.start_date);
        self.end_date = iso_day(self.end_date);
        if not self.name or not self.start_date or not self.end_date {
            report {
                "ok": False,
                "error": "invalid",
                "message": "An iteration needs a name, a start and an end."
            };
            disengage;
        }
        if self.start_date > self.end_date {
            report {
                "ok": False,
                "error": "invalid",
                "message": "An iteration cannot end before it starts."
            };
            disengage;
        }
        if not self.iteration_id {
            visit iterations_box(here);
        } else {
            target = resolve(self.iteration_id);
            if isinstance(target, Iteration) and owned(here, target) {
                visit [target];
            } else {
                report {
                    "ok": False,
                    "error": "not_found",
                    "message": "Unknown iteration."
                };
            }
        }
    }

    can create with Iterations entry {
        fresh = here ++> Iteration(
            name=self.name,
            start_date=self.start_date,
            end_date=self.end_date,
            created_at=now_iso()
        );
        on_attached(root, fresh);
        report {"ok": True, "iteration": iteration_view(fresh)};
        disengage;
    }

    can update with Iteration entry {
        here.name = self.name;
        here.start_date = self.start_date;
        here.end_date = self.end_date;
        report {"ok": True, "iteration": iteration_view(here)};
        disengage;
    }
}


walker DeleteIteration {
    """Delete one iteration and clear it from every task planned into it."""
    has iteration_id: str = "",
        reports: list[dict[str, any]] = [];

    can start with Root entry {
        target = resolve(self.iteration_id);
        if isinstance(target, Iteration) and owned(here, target) {
            visit [target];
        } else {
            report {"ok": False, "error": "not_found", "message": "Unknown iteration."};
        }
    }

    can remove with Iteration entry {
        gone = jid(here);
        cleared = 0;
        for t in tasks_in_iteration(root, gone) {
            t.iteration_id = "";
            cleared = cleared + 1;
        }
        del here;
        report {"ok": True, "deleted": gone, "cleared": cleared};
        disengage;
    }
}


walker RoadmapSnapshot {
    """The roadmap for [from_date, to_date]: the iterations overlapping it and
    the tasks whose span (task_span) does, earliest first, at most
    ROADMAP_MAX_ROWS. `project_id` narrows to that project; open tasks with
    no span count as unscheduled. A bad window reads as two weeks back to
    eight ahead. Only the open tasks and the Done tasks whose dates or
    iteration touch the window are loaded (done_in_window), never the
    history."""
    has from_date: str = "",
        to_date: str = "",
        project_id: str = "",
        reports: list[RoadmapData] = [];

    can start with Root entry {
        ensure_tallies(here);
        if self.project_id {
            p = resolve(self.project_id);
            if isinstance(p, Project) and owned(here, p) {
                visit [p];
            } else {
                report self.plan(here, [], "");
            }
        } else {
            report self.plan(here, open_tasks(here), "");
        }
    }

    can gather with Project entry {
        report self.plan(root, project_open(here), jid(here));
        disengage;
    }

    # `open` is the open pool; `only` narrows the Done candidates (read
    # workspace-wide, then kept by their project link) to one project.
    def plan(holder: Root, open: list[Task], only: str) -> RoadmapData {
        lo = iso_day(self.from_date);
        hi = iso_day(self.to_date);
        if not lo or not hi or lo > hi {
            lo = shift_day(today_iso(), -14);
            hi = shift_day(today_iso(), 56);
        }
        spans: dict[str, list[str]] = {};
        windows: list[IterationView] = [];
        window_ids: list[str] = [];
        after_ids: list[str] = [];
        before_ids: list[str] = [];
        for it in iterations_of(holder) {
            spans[jid(it)] = [it.start_date, it.end_date];
            if it.start_date <= hi and it.end_date >= lo {
                windows.append(iteration_view(it));
                window_ids.append(jid(it));
            }
            if it.end_date >= lo {
                after_ids.append(jid(it));
            }
            if it.start_date <= hi {
                before_ids.append(jid(it));
            }
        }
        iteration_order(windows);
        pool = open;
        if self.project_id and not only {
            pool = [];
        } else {
            for t in done_in_window(
                holder, lo, hi, window_ids, after_ids, before_ids
            ) {
                if not only or t.project_id == only {
                    pool.append(t);
                }
            }
        }
        placed: list[list[any]] = [];
        unscheduled = 0;
        for t in pool {
            span = task_span(t, spans);
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
            iterations=windows,
            rows=hydrate_views(holder, tasks),
            starts=[str(row[1]) for row in page],
            ends=[str(row[2]) for row in page],
            unscheduled=unscheduled,
            total=len(placed),
            truncated=len(placed) > ROADMAP_MAX_ROWS
        );
    }
}
