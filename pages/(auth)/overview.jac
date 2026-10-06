"""flowline - Overview: what needs someone now, then how the week is going.
A workspace with nothing to count gets a first-run checklist instead of the
figures and charts; the impl annex documents each read."""

import from "@jac/runtime" { useState }
import from "react" { useEffect }
import from ...models {
    Project,
    MemberView,
    StepView,
    TaskRow,
    TaskTotals,
    LogTotals,
    WeeklyHistory
}
import from ...constants { FLOW_LINE_TEMPLATES, STATUS_KIND, KIND_COLORS }
import from ...services.insights.insights { OverviewSnapshot }
import from ...services.tasks.tasks { TaskHistory, ListTasks }
import from ...components.dashboard.NeedsYou { NeedsYou }
import from ...components.dashboard.ThisWeek { ThisWeek }
import from ...components.dashboard.ProjectBars { ProjectBars }
import from ...components.dashboard.PeopleTable { PeopleTable }
import from ...components.dashboard.OverTime { OverTime }
import from ...components.dashboard.HistoryFilters { HistoryFilters }
import from ...components.dashboard.FirstRun { FirstRun }
import from ...components.ui.skeleton { Skeleton }
import from ...components.common.Reveal { Reveal }
import from ...components.common.LoadFailed { LoadFailed }
import from ...lib.dates { todayIso, daysUntil, prettyDay }
import from ...lib.session { fetchOrgName, cachedOrgName, OVERVIEW_SHAPE_KEY }
import from ...lib.workspace { loadWorkspace }

glob DAY_LABELS: list[str] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
     DAY_NAMES: list[str] = [
         "Monday",
         "Tuesday",
         "Wednesday",
         "Thursday",
         "Friday",
         "Saturday",
         "Sunday"
     ];

# Reads in flight, by name. A remount (the page used to mount twice on a
# full load) awaits the first mount's request instead of sending its own. A
# dict cell, so a function never rebinds a glob.
glob LOADS: dict[str, any] = {},
     NEEDS_CAP: int = 6;

def inflight(key: str) -> any {
    return LOADS[key] if key in LOADS else None;
}

def clampInt(v: any, low: int, high: int, fallback: int) -> int {
    n = int(v) if v else 0;
    if not n {
        return fallback;
    }
    return low if n < low else (high if n > high else n);
}

# The panels' shape on the last visit (the day chart, rows per worklist
# group, project and people rows), so the first-load frame reserves the
# same space the loaded page will take.
def cachedShape -> dict[str, any] {
    fallback: dict[str, any] = {
        "chart": False,
        "groups": [4],
        "projects": 3,
        "people": 5
    };
    try {
        raw = localStorage.getItem(OVERVIEW_SHAPE_KEY) or "";
        if not raw {
            return fallback;
        }
        parsed: any = JSON.parse(raw);
        groups: list[int] = [];
        for n in (parsed["groups"] or []) {
            if len(groups) < 5 {
                groups.append(clampInt(n, 1, NEEDS_CAP, 1));
            }
        }
        return {
            "chart": bool(parsed["chart"]),
            "groups": groups if len(groups) > 0 else [4],
            "projects": clampInt(parsed["projects"], 1, 8, 3),
            "people": clampInt(parsed["people"], 1, 12, 5)
        };
    } except Exception as e {
        return fallback;
    }
}

def localIso(d: any) -> str {
    shifted = new(Date, d.getTime() - d.getTimezoneOffset() * 60000);
    return shifted.toISOString()[:10];
}

def shiftDay(iso: str, delta: int) -> str {
    d = new(Date, iso + "T00:00:00");
    d.setDate(d.getDate() + delta);
    return localIso(d);
}

def mondayOf(iso: str) -> str {
    d = new(Date, iso + "T00:00:00");
    offset = int((d.getDay() + 6) % 7);
    return shiftDay(iso, -offset);
}

# "2026-09-21" -> "September 21", for the week line under the title.
def longDay(iso: str) -> str {
    d = new(Date, iso + "T00:00:00");
    return d.toLocaleDateString("en-US", {"month": "long", "day": "numeric"});
}

# A due date as the worklist reads it: "today", "tomorrow", a weekday later
# this week, a date after that, or how many days it is late.
def relDay(iso: str, today: str) -> str {
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
def sinceDay(iso: str, today: str) -> str {
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
def plainLine(text: str) -> str {
    line = text.strip().split("\n")[0].replace("**", "").strip();
    if len(line) > 11 and line[4] == "-" and line[7] == "-" and line[10] == ":" {
        line = line[11:].strip();
    }
    return line;
}

def plural(n: int, one: str, many: str) -> str {
    return str(n) + " " + (one if n == 1 else many);
}

def countAll(xs: list[int]) -> int {
    n = 0;
    for x in xs {
        n = n + x;
    }
    return n;
}

def splitNames(joined: str) -> list[str] {
    return [
        n.strip()
        for n in joined.split(",")
        if n.strip()
    ];
}

# The pill a row shows: the task's own step, else the first step of its
# status's kind by the legacy status (a task need not have a step).
def stepChip(steps: list[StepView], stepId: str, status: str) -> dict[str, str] {
    for s in steps {
        if stepId and s.id == stepId {
            return {"name": s.name, "color": s.color, "kind": s.kind};
        }
    }
    kind = STATUS_KIND[status] if status in STATUS_KIND else "active";
    return {"name": status or "Open", "color": KIND_COLORS[kind], "kind": kind};
}

# One worklist row; the note, flags and step are filled in by the caller.
def workRow(
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

def dueRow(t: TaskRow, today: str) -> dict[str, any] {
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
def withBlocked(
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
def withReview(row: dict[str, any], r: dict[str, any], held: any) -> dict[str, any] {
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

def group(
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

def:pub OverviewPage -> JsxPage {
    has attention: list[TaskRow] = [],
        attentionTotal: int = 0,
        members: list[MemberView] = [],
        projects: list[Project] = [],
        # Every number on the page, counted over the whole history. None until
        # the snapshot lands: a models obj cannot be constructed client-side
        # (it crosses the wire as plain data), so the render guards the reads.
        counts: TaskTotals | None = None,
        logs: LogTotals | None = None,
        taskTotal: int = 0,
        # Digest snapshot slices, kept as dicts: typing them as the walker's
        # objs would pull services.insights.insights types into the client bundle.
        reviewQueue: list[dict[str, any]] = [],
        quiet: list[dict[str, any]] = [],
        blockedInfo: dict[str, dict[str, any]] = {},
        blockedList: list[dict[str, any]] = [],
        loading: bool = True,
        failed: bool = False,
        # Open work sorted by due date, for due this week and per-project overdue.
        dueRows: list[TaskRow] = [],
        dueLoaded: bool = False,
        dueHasMore: bool = False,
        dueFailed: bool = False,
        # Tasks that entered Done this week, per local weekday.
        weekDone: list[int] = [0, 0, 0, 0, 0, 0, 0],
        weekAdded: int = -1,
        addedFailed: bool = False,
        orgName: str = cachedOrgName(),
        # The workspace view: the flow line (row pills, checklist) and GitHub.
        sharedLoaded: bool = False,
        steps: list[StepView] = [],
        templateName: str = "",
        ghConfigured: bool = False,
        ghConnected: bool = False,
        ghLogin: str = "",
        # The charts over time, scoped by their own filter row. A refetch
        # keeps the last render on screen instead of a skeleton.
        history: WeeklyHistory | None = None,
        historyProject: str = "all",
        historyWeeks: str = "12",
        historyLoading: bool = True,
        historyFailed: bool = False;

    async can with entry {
        loadAll();
        loadDue();
        loadShared();
        orgName = await fetchOrgName();
    }

    async can with (historyProject, historyWeeks) entry {
        loadHistory();
    }

    async def fetchSnapshot(monday: str) -> any;
    async def fetchDue -> any;
    async def fetchHistory(projectId: str, weeks: int) -> any;
    async def loadAll -> None;
    async def loadDue -> None;
    async def loadShared -> None;
    async def loadHistory -> None;

    today = todayIso();
    # The snapshot flags overdue by the server's UTC day; this is that day,
    # so the page can tell which of its rows the snapshot already counted.
    serverToday = new(Date).toISOString()[:10];
    monday = mondayOf(today);
    todayIdx = daysUntil(today, monday);
    sunday = shiftDay(monday, 6);
    activeMembers = [
        m
        for m in members
        if m.active
    ];
    activeProjects = [
        p
        for p in projects
        if p.active
    ];
    # Weekly counts, oldest first, four weeks ending in this one. Guarded
    # with len(): the list is empty until the counts land.
    doneSpark = counts.done_by_week
        if counts and len(counts.done_by_week) == 4
        else [0, 0, 0, 0];
    openCount = counts.open if counts else 0;
    # Early means nothing to count: no task yet. The checklist then stands
    # in for the body; later it joins the side column while no card has
    # reached Done.
    doneEver = countAll(doneSpark);
    for pt in (counts.projects if counts else []) {
        doneEver = doneEver + pt.done;
    }
    early = (True if counts else False) and taskTotal == 0;

    # ---- Needs someone now: each task sits in the first group it qualifies
    # for, and `flagged` collects the ids the snapshot's attention_total counts.
    shown: list[str] = [];
    flagged: list[str] = [];
    overdueRows: list[dict[str, any]] = [];
    blockedRows: list[dict[str, any]] = [];
    earlyDue: list[dict[str, any]] = [];
    byId: dict[str, TaskRow] = {};
    for t in attention {
        byId[t.id] = t;
    }
    for t in dueRows {
        byId[t.id] = t;
    }
    reviewOf: dict[str, dict[str, any]] = {};
    for r in reviewQueue {
        reviewOf[r["task_id"]] = r;
    }
    for t in attention {
        flagged.append(t.id);
        if t.status == "Blocked" {
            shown.append(t.id);
            info: dict[str, any] = blockedInfo[t.id] if t.id in blockedInfo else {};
            blockedRows.append(
                withBlocked(
                    workRow(
                        t.id,
                        t.title,
                        t.project_name,
                        t.assignee_names,
                        "",
                        False,
                        t.status
                    ),
                    t.due_date,
                    today,
                    info,
                    info["since"] if "since" in info else t.updated_at[:10]
                )
            );
        } elif t.due_date < today {
            shown.append(t.id);
            overdueRows.append(
                withReview(dueRow(t, today), reviewOf[t.id], t)
                    if t.id in reviewOf
                    else dueRow(t, today)
            );
        } elif t.id not in reviewOf {
            # Late by the server's day, due today by the viewer's. A review
            # due today stays in Waiting on review.
            shown.append(t.id);
            earlyDue.append(dueRow(t, today));
        }
    }
    # The snapshot's blocked list is complete; its attention page is not.
    for b in blockedList {
        bid = b["task_id"];
        if bid not in flagged {
            flagged.append(bid);
        }
        if bid in shown {
            continue;
        }
        shown.append(bid);
        held = byId[bid] if bid in byId else None;
        blockedRows.append(
            withBlocked(
                workRow(
                    bid,
                    b["title"],
                    b["project"],
                    splitNames(b["assignees"]),
                    "",
                    False,
                    "Blocked"
                ),
                held.due_date if held else "",
                today,
                b,
                b["since"]
            )
        );
    }
    # Everything late past the attention page, most overdue first, before
    # any other group can claim it.
    overdueByProject: dict[str, int] = {};
    for t in dueRows {
        if t.status == "Done" or len(t.due_date) < 10 {
            continue;
        }
        if t.due_date < serverToday and t.id not in flagged {
            flagged.append(t.id);
        }
        if t.status == "Blocked" {
            continue;
        }
        if t.due_date < today and t.project_id {
            overdueByProject[t.project_id] = (
                overdueByProject[t.project_id]
                    if t.project_id in overdueByProject
                    else 0
            )
                + 1;
        }
        if t.id not in shown and t.due_date < today {
            shown.append(t.id);
            overdueRows.append(
                withReview(dueRow(t, today), reviewOf[t.id], t)
                    if t.id in reviewOf
                    else dueRow(t, today)
            );
        }
    }
    reviewRows: list[dict[str, any]] = [];
    for r in reviewQueue {
        if r["task_id"] in shown {
            continue;
        }
        shown.append(r["task_id"]);
        waited = r["waiting_days"];
        # The review's own due date, else the task's; the reviewer's avatar,
        # else whoever holds the card while it waits.
        held = byId[r["task_id"]] if r["task_id"] in byId else None;
        due = r["review_due"];
        if len(due) < 10 and held {
            due = held.due_date;
        }
        dated = len(due) >= 10;
        reviewRow = withReview(
            workRow(
                r["task_id"],
                r["title"],
                r["project"],
                held.assignee_names if held else [],
                relDay(due, today)
                    if dated
                    else (
                        "waiting " + plural(waited, "day", "days") if waited > 0 else ""
                    ),
                dated and due < today,
                "Review"
            ),
            r,
            held
        );
        # Soonest due first, undated last; the sort is stable, so ties keep
        # the snapshot's longest wait first.
        reviewRow["sortDue"] = due[:10] if dated else "9999-12-31";
        reviewRows.append(reviewRow);
    }
    reviewRows.sort(key=lambda (x: dict[str, any]) { x["sortDue"]; });
    weekDueRows: list[dict[str, any]] = earlyDue;
    for t in dueRows {
        if t.status == "Done"
            or t.status == "Blocked"
            or len(t.due_date) < 10
            or t.id in shown
            or t.due_date > sunday {
            continue;
        }
        shown.append(t.id);
        weekDueRows.append(dueRow(t, today));
    }
    # A page that ends inside this week may have left some due tasks out.
    lastDue = dueRows[len(dueRows) - 1].due_date if len(dueRows) > 0 else "";
    dueCut = dueHasMore and len(lastDue) >= 10 and lastDue <= sunday;
    quietRows: list[dict[str, any]] = [];
    for q in quiet {
        if q["task_id"] in shown {
            continue;
        }
        shown.append(q["task_id"]);
        quietRows.append(
            workRow(
                q["task_id"],
                q["title"],
                q["project"],
                splitNames(q["assignees"]),
                plural(q["idle_days"], "day", "days") + " idle",
                False,
                q["status"]
            )
        );
    }
    # Flagged tasks the page holds no row for: overdue past both reads.
    hiddenAttention = attentionTotal - len(flagged);
    if hiddenAttention < 0 {
        hiddenAttention = 0;
    }
    groups: list[dict[str, any]] = [];
    if len(overdueRows) > 0 or hiddenAttention > 0 {
        groups.append(
            group(
                "overdue", "Overdue", "alarm", overdueRows, hiddenAttention, "overdue"
            )
        );
    }
    if len(blockedRows) > 0 {
        groups.append(group("blocked", "Blocked", "alarm", blockedRows, 0, "blocked"));
    }
    if len(reviewRows) > 0 {
        groups.append(
            group(
                "review",
                "Waiting on review",
                "amber",
                reviewRows,
                0,
                "waiting on review"
            )
        );
    }
    if len(weekDueRows) > 0 {
        groups.append(
            group(
                "due",
                "Due this week",
                "sky",
                weekDueRows,
                -1 if dueCut else 0,
                "due this week"
            )
        );
    }
    if len(quietRows) > 0 {
        groups.append(
            group("quiet", "Gone quiet", "muted", quietRows, 0, "gone quiet")
        );
    }
    # Each row's step pill, from the task when the page holds it.
    for g in groups {
        for row in g["rows"] {
            known = byId[row["id"]] if row["id"] in byId else None;
            row["step"] = stepChip(steps, known.step_id, known.status)
                if known
                else stepChip(steps, "", row["status"]);
        }
    }

    # ---- This week: four figures and tasks that entered Done per day.
    figures = [
        {"label": "moved to Done", "value": str(doneSpark[3])},
        {
            "label": "tasks added",
            "value": str(weekAdded) if weekAdded >= 0 else ("-" if addedFailed else "…")
        },
        {"label": "open tasks", "value": str(openCount)},
        {"label": "blocked now", "value": str(counts.blocked if counts else 0)}
    ];
    anyDone = countAll(weekDone) + countAll(doneSpark) > 0;
    dayRows: list[dict[str, any]] = [];
    for i in range(7) {
        if i < 5 or weekDone[i] > 0 or todayIdx >= 5 {
            dayRows.append(
                {
                    "name": DAY_NAMES[i],
                    "label": DAY_LABELS[i],
                    "value": weekDone[i],
                    "future": i > todayIdx,
                    "today": i == todayIdx
                }
            );
        }
    }
    chartState = "loading" if loading else ("chart" if anyDone else "none");
    chartNote = "Tasks moved to Done per day. Days still ahead are outlined."
        if chartState != "none"
        else "Nothing has moved to Done in four weeks, so there is no day chart yet.";

    # ---- Projects and people.
    projRows: list[dict[str, any]] = [];
    for p in activeProjects {
        pid = jid(p);
        tally: dict[str, int] = {"total": 0, "done": 0, "blocked": 0};
        for pt in (counts.projects if counts else []) {
            if pt.project_id == pid {
                tally = {"total": pt.total, "done": pt.done, "blocked": pt.blocked};
            }
        }
        openN = tally["total"] - tally["done"];
        alarm = tally["blocked"]
            + (overdueByProject[pid] if pid in overdueByProject else 0);
        if alarm > openN {
            alarm = openN;
        }
        projRows.append(
            {
                "id": pid,
                "name": p.name,
                "done": tally["done"],
                "open": openN - alarm,
                "alarm": alarm,
                "total": tally["total"]
            }
        );
    }
    personOpen: dict[str, int] = {};
    personDone: dict[str, int] = {};
    for mt in (counts.members if counts else []) {
        personOpen[mt.member_id] = mt.open;
        personDone[mt.member_id] = mt.done_in_week;
    }
    personDays: dict[str, list[int]] = {};
    for md in (logs.members if logs else []) {
        personDays[md.name] = md.by_day;
    }
    peopleRows = [
        {
            "id": m.id,
            "name": m.name,
            "color": m.color,
            "open": personOpen[m.id] if m.id in personOpen else 0,
            "done": personDone[m.id] if m.id in personDone else 0,
            "byDay": personDays[m.name]
                if m.name in personDays and len(personDays[m.name]) == 7
                else [0, 0, 0, 0, 0, 0, 0]
        } for m in activeMembers
    ];

    # Remember the panels' shape once every read has landed, for the next
    # first-load frame. Placed after those locals: an effect's deps are read
    # where it is called.
    shapeReady = not loading and not failed and dueLoaded;
    groupRows: list[int] = [];
    for g in groups {
        groupRows.append(len(g["rows"]) if len(g["rows"]) < NEEDS_CAP else NEEDS_CAP);
    }
    shapeStamp = str(chartState == "chart")
        + "|"
        + ",".join([str(n) for n in groupRows])
        + "|"
        + str(len(activeProjects))
        + "|"
        + str(len(activeMembers));
    useEffect(
        lambda {
            if shapeReady {
                try {
                    localStorage.setItem(
                        OVERVIEW_SHAPE_KEY,
                        JSON.stringify(
                            {
                                "chart": chartState == "chart",
                                "groups": groupRows,
                                "projects": len(activeProjects),
                                "people": len(activeMembers)
                            }
                        )
                    );
                } except Exception as e {
                    groupRows = groupRows;
                }
            }
            return lambda { groupRows = groupRows; };
        },
        [shapeReady, shapeStamp]
    );

    # ---- First run: every item from state the page already read.
    noPeople = len(activeMembers) == 0;
    noProject = len(activeProjects) == 0;
    firstStepName = steps[0].name if len(steps) > 0 else "";
    checklist: list[dict[str, any]] = [];
    checklist.append(
        {
            "key": "flow",
            "title": "Pick how work moves",
            "detail": (
                (templateName + " template, " if templateName else "")
                + plural(len(steps), "step", "steps")
                + ("." if templateName else " on your flow line.")
            )
                if len(steps) > 0
                else "Start from a template or draw your own steps.",
            "done": len(steps) > 0,
            "action": "Redraw" if len(steps) > 0 else "Pick a flow line",
            "to": "/flowlines",
            "primary": False
        }
    );
    checklist.append(
        {
            "key": "people",
            "title": "Add the people you track",
            "detail": "Add teammates so work can be assigned."
                if noPeople
                else plural(len(activeMembers), "person", "people") + " on the roster.",
            "done": not noPeople,
            "action": "Add a person" if noPeople else "People",
            "to": "/workspace?tab=people",
            "primary": False
        }
    );
    # CreateTask needs an active project, and the board sends a workspace
    # without one to /setup, so the item asks for a project first.
    checklist.append(
        {
            "key": "task",
            "title": "Add your first task",
            "detail": "Tasks live in a project, so add one first."
                if noProject and taskTotal == 0
                else (
                    ("It lands in " + firstStepName + ".")
                        if firstStepName
                        else "It lands in the first column of the board."
                ),
            "done": taskTotal > 0,
            "action": "Add a project" if noProject else "New task",
            "to": "/workspace?tab=projects" if noProject else "/board?new=1",
            "primary": False
        }
    );
    if ghConfigured {
        checklist.append(
            {
                "key": "github",
                "title": "Connect GitHub",
                "detail": ("Connected as @" + ghLogin + ".")
                    if ghConnected and ghLogin
                    else "Optional. Import issues and let a merged pull request move its card.",
                "done": ghConnected,
                "action": "" if ghConnected else "Connect",
                "to": "/workspace?tab=github",
                "primary": False
            }
        );
    }
    requiredOpen = 0;
    for s in checklist {
        if not s["done"] and s["key"] != "github" {
            if requiredOpen == 0 {
                s["primary"] = True;
            }
            requiredOpen = requiredOpen + 1;
        }
    }
    # Past the early page the checklist is an extra side panel, shown once
    # the workspace read lands (so no item flips on arrival) and only while
    # a required item is open and no card has reached Done.
    sideChecklist = not early and doneEver == 0 and sharedLoaded and requiredOpen > 0;
    checklistTitle = "Get " + (orgName or "your workspace") + " moving";
    earlyNote = "Figures and charts appear once there is a task. Until then there is nothing to count, so nothing is shown.";

    historyProjects = [[jid(p), p.name] for p in activeProjects];
    shape = cachedShape();
    # Layout follows the width the page is given, not the viewport: from
    # 60rem the worklist sits beside the week; People and the charts span.
    zones = "grid gap-5 @min-[60rem]:grid-cols-[minmax(0,3fr)_minmax(0,2fr)] @min-[60rem]:items-start";
    side = "flex min-w-0 flex-col gap-5";
    wide = "min-w-0 @min-[60rem]:col-span-2";

    def overTime -> JsxElement {
        return
            <div className={wide}>
                <OverTime
                    history={history}
                    filters={<HistoryFilters
                        projects={historyProjects}
                        project={historyProject}
                        weeks={historyWeeks}
                        onProject={lambda (v: str) { historyProject = v; }}
                        onWeeks={lambda (v: str) { historyWeeks = v; }}
                    />}
                    loading={historyLoading}
                    failed={historyFailed}
                    onRetry={loadHistory}
                />
            </div>;
    }

    def loadFrame -> JsxElement {
        return
            <div key="sk" className={zones} aria-busy="true">
                <NeedsYou
                    groups={[]}
                    placeholder={True}
                    placeholderRows={shape["groups"]}
                />
                <div className={side}>
                    <ThisWeek
                        figures={[]}
                        days={[]}
                        placeholder={True}
                        chartState={"loading" if shape["chart"] else "none"}
                    />
                    <ProjectBars
                        rows={[]}
                        placeholder={True}
                        placeholderRows={shape["projects"]}
                    />
                </div>
                <div className={wide}>
                    <PeopleTable
                        rows={[]}
                        dayNames={DAY_LABELS}
                        todayIndex={todayIdx}
                        placeholder={True}
                        placeholderRows={shape["people"]}
                    />
                </div>
                {overTime()}
            </div>;
    }

    return
        <div className="@container space-y-6">
            <header>
                <p className="text-sm text-muted-foreground">
                    {orgName or "Your workspace"}
                </p>
                <h1 className="page-title">Overview</h1>
                <p className="page-subtitle">{"Week of " + longDay(monday)}</p>
            </header>
            <Reveal ready={not loading} frame={loadFrame()}>
                {if failed {
                    <LoadFailed
                        key="failed"
                        title="Could not load the overview"
                        onRetry={lambda {
                            loadAll();
                            if dueFailed {
                                loadDue();
                            }
                            if historyFailed {
                                loadHistory();
                            }
                        }}
                    />
                } elif early {
                    <div key="first" className={zones}>
                        {if sharedLoaded {
                            <FirstRun
                                key="list"
                                title={checklistTitle}
                                items={checklist}
                            />
                        } else {
                            <div key="listsk" className="space-y-3">
                                {for i in range(4) {
                                    <Skeleton
                                        key={str(i)}
                                        className="h-12 w-full rounded-xl"
                                    />
                                }}
                            </div>
                        } }
                        <ThisWeek key="note" figures={[]} days={[]} note={earlyNote}/>
                    </div>
                } else {
                    <div key="body" className={zones}>
                        <NeedsYou
                            groups={groups}
                            pending={not dueLoaded}
                            failNote={"Could not check what is due this week."
                                if dueFailed
                                else ""}
                            onRetry={loadDue}
                        />
                        <div className={side}>
                            {if sideChecklist {
                                <FirstRun
                                    key="list"
                                    title={checklistTitle}
                                    items={checklist}
                                />
                            }}
                            <ThisWeek
                                figures={figures}
                                days={dayRows}
                                chartState={chartState}
                                chartNote={chartNote}
                            />
                            <ProjectBars rows={projRows}/>
                        </div>
                        <div className={wide}>
                            <PeopleTable
                                rows={peopleRows}
                                dayNames={DAY_LABELS}
                                todayIndex={todayIdx}
                            />
                        </div>
                        {overTime()}
                    </div>
                }  }
            </Reveal>
        </div>;
}
