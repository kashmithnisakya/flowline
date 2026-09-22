"""The tasks table's history scopes, paged in the store. Scope, filters and sort
are picked per request, so the query is assembled from the parts a graph
reference compiles to (jaclang.lib.jaclib) instead of one literal per
combination. Every field it names is fixed in this module."""

import from jaclang.lib.jaclib { GraphQuery, QHop, QPred, QOrder, EdgeDir, refs }
import from models { Project, Task, AssignedTo, WorkflowStep, steps_of }
import from constants { STATUSES, STATUS_KIND }

# The table's sort columns and the Task field the store orders each by.
glob SORT_FIELDS: dict[str, str] = {
         "title": "title_key",
         "category": "category_key",
         "priority": "priority_rank",
         "estimate": "estimate",
         "due": "due_key",
         "created": "created_at",
         "updated": "updated_at"
     };

# Where a history query starts: the Projects box (every project), one
# project, or one member (back over AssignedTo), and the predicates every
# task it answers must meet.
obj HistoryBase {
    has origin: list[any],
        via: str,
        preds: list[QPred];
}

# A board column as the disjoint task sets it holds, each a predicate list.
obj Column {
    has key: str,
        parts: list[list[QPred]];
}


def task_query(
    base: HistoryBase, extra: list[QPred], order: list[QOrder]
) -> GraphQuery {
    preds = base.preds + extra;
    hops: list[QHop] = [];
    if base.via == "member" {
        hops.append(QHop(dir=EdgeDir.IN.value, `edge=AssignedTo, nd=Task, preds=preds));
    } elif base.via == "project" {
        hops.append(QHop(dir=EdgeDir.OUT.value, nd=Task, preds=preds));
    } else {
        hops.append(QHop(dir=EdgeDir.OUT.value, nd=Project));
        hops.append(QHop(dir=EdgeDir.OUT.value, nd=Task, preds=preds));
    }
    return GraphQuery(base.origin, hops=hops, order=order);
}


# How many tasks a part holds. A graph reference under len() is a count in
# the store only without a signed-in caller on jac 0.37.18; for a tenant it
# loads the matching rows (jaseci-labs/jac#9416), so callers count only
# under a filter, where the tallies cannot answer.
def part_count(base: HistoryBase, extra: list[QPred]) -> int {
    return len(refs(task_query(base, extra, []), lazy=True));
}


def parts_count(base: HistoryBase, parts: list[list[QPred]]) -> int {
    n = 0;
    for extra in parts {
        n = n + part_count(base, extra);
    }
    return n;
}


# Rows [start, stop) of one part in `order`.
def part_window(
    base: HistoryBase, extra: list[QPred], order: list[QOrder], start: int, stop: int
) -> list[Task] {
    rows: list[Task] = [];
    for t in refs(task_query(base, extra, order), slc=slice(start, stop)) {
        if isinstance(t, Task) {
            rows.append(t);
        }
    }
    return rows;
}


# The order a sort answers in, the unique row_key breaking ties: the same
# as a Python sort by row_key and then by the field, reversed or not.
def field_order(field: str, desc: bool) -> list[QOrder] {
    return [QOrder(field=field, desc=desc), QOrder(field="row_key")];
}


def by_field(rows: list[Task], field: str, desc: bool) {
    rows.sort(key=lambda (t: Task) { t.row_key; });
    rows.sort(key=lambda (t: Task) { getattr(t, field); }, reverse=desc);
}


# Rows [start, end) across disjoint parts in `field` order. One part pages
# in the store; several each answer their first `end` rows, merged here.
def sorted_window(
    base: HistoryBase,
    parts: list[list[QPred]],
    field: str,
    desc: bool,
    start: int,
    end: int
) -> list[Task] {
    order = field_order(field, desc);
    if len(parts) == 1 {
        return part_window(base, parts[0], order, start, end);
    }
    pool: list[Task] = [];
    for extra in parts {
        pool.extend(part_window(base, extra, order, 0, end));
    }
    by_field(pool, field, desc);
    return pool[start:end];
}


# The board's columns in order (canvas x, then sort_order), each with the
# tasks the board places there: its own step, and in the first column of a
# kind the tasks with no current step whose status maps to that kind (a kind
# the flow line lacks goes to the first column). No flow line: the statuses.
def board_columns(holder: Root) -> list[Column] {
    steps = steps_of(holder);
    steps.sort(key=lambda (s: WorkflowStep) { s.sort_order; });
    steps.sort(key=lambda (s: WorkflowStep) { s.x; });
    columns: list[Column] = [];
    if len(steps) == 0 {
        for st in STATUSES {
            columns.append(
                Column(key=st, parts=[[QPred(field="status", op="==", value=st)]])
            );
        }
        return columns;
    }
    first_of_kind: dict[str, int] = {};
    stepless: list[QPred] = [];
    for (i, s) in enumerate(steps) {
        sid = jid(s);
        columns.append(
            Column(key=sid, parts=[[QPred(field="step_id", op="==", value=sid)]])
        );
        stepless.append(QPred(field="step_id", op="!=", value=sid));
        if s.kind not in first_of_kind {
            first_of_kind[s.kind] = i;
        }
    }
    for st in STATUSES {
        kind = STATUS_KIND[st] if st in STATUS_KIND else "active";
        at = first_of_kind[kind] if kind in first_of_kind else 0;
        columns[at].parts.append(stepless + [QPred(field="status", op="==", value=st)]);
    }
    return columns;
}


# Rows [start, end) in board column order (reversed when `desc`), cards in
# board order within a column. Each column answers at most the rows the page
# still needs past the offset; a column that answers fewer is whole, so its
# size comes off the offset. No count: the cost is the page's end.
def column_window(
    base: HistoryBase, columns: list[Column], desc: bool, start: int, end: int
) -> list[Task] {
    walk = [c for c in columns];
    if desc {
        walk.reverse();
    }
    order = field_order("sort_order", False);
    rows: list[Task] = [];
    offset = start;
    size = end - start;
    for c in walk {
        if len(rows) >= size {
            break;
        }
        need = offset + size - len(rows);
        pool: list[Task] = [];
        for extra in c.parts {
            pool.extend(part_window(base, extra, order, 0, need));
        }
        if len(pool) <= offset {
            offset = offset - len(pool);
            continue;
        }
        by_field(pool, "sort_order", False);
        rows.extend(pool[offset:need]);
        offset = 0;
    }
    return rows;
}
