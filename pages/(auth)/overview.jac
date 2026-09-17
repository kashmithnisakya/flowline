"""flowline - Overview: what needs someone now, then how the week is going.
A workspace with nothing to count gets a first-run checklist instead of the
figures and charts; the impl annex documents each read."""

import from "@jac/runtime" { useState }
import from "react" { useEffect }
import from ...models {
    Project,
    MemberView,
    TaskView,
    TaskTotals,
    LogTotals,
    WeeklyHistory
}
import from ...constants { FLOW_LINE_TEMPLATES, STATUS_KIND }
import from ...services.insights.insights { OverviewSnapshot }
import from ...services.tasks.tasks { TaskHistory, ListTasks }
import from ...services.log.log { ListLogEntries }
import from ...services.flowlines.flowlines { GetFlowLine, GetFlowLineMeta }
import from ...services.github.github { GithubStatus }
import from ...components.dashboard.HistoryCharts { BurnUpChart, ThroughputChart }
import from ...components.dashboard.NeedsYou { NeedsYou }
import from ...components.dashboard.ThisWeek { ThisWeek }
import from ...components.dashboard.Breakdown { ProjectBars, PeopleTable }
import from ...components.dashboard.FirstRun { FirstRun }
import from ...components.ui.select {
    Select,
    SelectTrigger,
    SelectValue,
    SelectContent,
    SelectItem
}
import from ...components.ui.skeleton { Skeleton }
import from ...components.common.LoadFailed { LoadFailed }
import from ...lib.dates { todayIso, daysUntil, prettyDay }
import from ...lib.session { fetchOrgName }

glob DAY_LABELS: list[str] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
     DAY_NAMES: list[str] = [
         "Monday",
         "Tuesday",
         "Wednesday",
         "Thursday",
         "Friday",
         "Saturday",
         "Sunday"
     ],
     HISTORY_RANGES: list[list[str]] = [
         ["8", "Last 8 weeks"],
         ["12", "Last 12 weeks"],
         ["26", "Last 26 weeks"]
     ];

# Reads in flight, by name. A full load mounts the page twice; the second
# mount awaits the first one's request instead of sending its own. A dict
# cell, so a function never rebinds a glob.
glob LOADS: dict[str, any] = {};

def inflight(key: str) -> any {
    return LOADS[key] if key in LOADS else None;
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

# The local day of a log row's UTC stamp ("2026-09-15T20:39:12.123456Z"),
# else the server's date for it.
def localDayOf(at: str, fallback: str) -> str {
    base = at.replace("Z", "");
    if len(base) < 19 or base[10] != "T" or base[13] != ":" {
        return fallback[:10];
    }
    return localIso(new(Date, base[:23] + "Z"));
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

# One worklist row; the note, kind and flags are filled in by the caller.
def workRow(
    id: str, title: str, meta: str, names: list[str], time: str, late: bool
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
        "kind": "",
        "kindLabel": ""
    };
}

def dueRow(t: TaskView, today: str) -> dict[str, any] {
    return workRow(
        t.id,
        t.title,
        t.project_name,
        t.assignee_names,
        relDay(t.due_date, today),
        t.due_date < today
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

def:pub OverviewPage -> JsxPage {
    has attention: list[TaskView] = [],
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
        reviewQueue: list[dict] = [],
        quiet: list[dict] = [],
        blockedInfo: dict[str, dict] = {},
        blockedList: list[dict] = [],
        loading: bool = True,
        failed: bool = False,
        # Open work sorted by due date, for due this week and per-project overdue.
        dueRows: list[TaskView] = [],
        dueLoaded: bool = False,
        dueHasMore: bool = False,
        dueFailed: bool = False,
        # This week off the log, by local day: tasks that entered Done per
        # weekday, hand-written lines, and when each blocked task stopped.
        doneMoves: list[int] = [0, 0, 0, 0, 0, 0, 0],
        handEntries: int = 0,
        blockedSince: dict[str, str] = {},
        # The week's entries by the same local day rule, per roster name, for
        # the People strip and the entries figure. -1 until a complete read.
        weekPeople: dict[str, list[int]] = {},
        weekEntries: int = -1,
        movesLoaded: bool = False,
        movesFailed: bool = False,
        weekAdded: int = -1,
        addedFailed: bool = False,
        orgName: str = "",
        # First-run state, read only while no card has reached Done.
        setupLoaded: bool = False,
        stepCount: int = 0,
        firstStepName: str = "",
        templateName: str = "",
        ghConfigured: bool = False,
        ghConnected: bool = False,
        ghLogin: str = "",
        # The charts over time, scoped by their own filter row. A refetch
        # keeps the last render on screen, dimmed, instead of a skeleton.
        history: WeeklyHistory | None = None,
        historyProject: str = "all",
        historyWeeks: str = "12",
        historyLoading: bool = True,
        historyFailed: bool = False;

    async can with entry {
        loadAll();
        loadDue();
        loadMoves();
        orgName = await fetchOrgName();
    }

    async can with (historyProject, historyWeeks) entry {
        loadHistory();
    }

    async def fetchSnapshot(monday: str) -> any;
    async def fetchDue -> any;
    async def fetchWeekLog(monday: str) -> any;
    async def fetchSetup -> any;
    async def fetchHistory(projectId: str, weeks: int) -> any;
    async def loadAll -> None;
    async def loadDue -> None;
    async def loadMoves -> None;
    async def loadSetup -> None;
    async def loadHistory -> None;
    async def loadWeekAdded -> None;

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
    # with len(): both lists are empty until the counts land.
    doneSpark = counts.done_by_week
        if counts and len(counts.done_by_week) == 4
        else [0, 0, 0, 0];
    entrySpark = logs.by_week if logs and len(logs.by_week) == 4 else [0, 0, 0, 0];
    openCount = counts.open if counts else 0;
    # Early means nothing to count: no task and no log row in four weeks. The
    # checklist then stands in for the body; later it joins the rail while no
    # card has reached Done (loadAll reads the setup on the same rule).
    doneEver = countAll(doneSpark);
    for pt in (counts.projects if counts else []) {
        doneEver = doneEver + pt.done;
    }
    early = (True if counts else False)
        and taskTotal == 0
        and countAll(entrySpark) == 0;

    # ---- Needs you: each task sits in the first group it qualifies for, and
    # `flagged` collects the ids the snapshot's attention_total counts.
    shown: list[str] = [];
    flagged: list[str] = [];
    overdueRows: list[dict] = [];
    blockedRows: list[dict] = [];
    earlyDue: list[dict] = [];
    byId: dict[str, TaskView] = {};
    for t in attention {
        byId[t.id] = t;
    }
    for t in dueRows {
        byId[t.id] = t;
    }
    reviewOf: dict[str, dict] = {};
    for r in reviewQueue {
        reviewOf[r["task_id"]] = r;
    }
    for t in attention {
        flagged.append(t.id);
        if t.status == "Blocked" {
            shown.append(t.id);
            info: dict[str, any] = blockedInfo[t.id] if t.id in blockedInfo else {};
            since = blockedSince[t.id]
                if t.id in blockedSince
                else (info["since"] if "since" in info else t.updated_at[:10]);
            blockedRows.append(
                withBlocked(
                    workRow(t.id, t.title, t.project_name, t.assignee_names, "", False),
                    t.due_date,
                    today,
                    info,
                    since
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
                    bid, b["title"], b["project"], splitNames(b["assignees"]), "", False
                ),
                held.due_date if held else "",
                today,
                b,
                blockedSince[bid] if bid in blockedSince else b["since"]
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
    reviewRows: list[dict] = [];
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
                dated and due < today
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
    weekDueRows: list[dict] = earlyDue;
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
    quietRows: list[dict] = [];
    for q in quiet {
        if q["task_id"] in shown {
            continue;
        }
        shown.append(q["task_id"]);
        row = workRow(
            q["task_id"],
            q["title"],
            q["project"],
            splitNames(q["assignees"]),
            plural(q["idle_days"], "day", "days") + " idle",
            False
        );
        row["kind"] = STATUS_KIND[q["status"]]
            if q["status"] in STATUS_KIND
            else "active";
        row["kindLabel"] = q["status"];
        quietRows.append(row);
    }
    # Flagged tasks the page holds no row for: overdue past both reads.
    hiddenAttention = attentionTotal - len(flagged);
    if hiddenAttention < 0 {
        hiddenAttention = 0;
    }
    groups: list[dict] = [];
    if len(overdueRows) > 0 or hiddenAttention > 0 {
        groups.append(
            {
                "key": "overdue",
                "label": "Overdue",
                "glyph": "blocked",
                "alarm": True,
                "rows": overdueRows,
                "more": hiddenAttention,
                "moreLabel": "overdue "
            }
        );
    }
    if len(blockedRows) > 0 {
        groups.append(
            {
                "key": "blocked",
                "label": "Blocked",
                "glyph": "blocked",
                "alarm": True,
                "rows": blockedRows,
                "more": 0,
                "moreLabel": "blocked "
            }
        );
    }
    if len(reviewRows) > 0 {
        groups.append(
            {
                "key": "review",
                "label": "Waiting on review",
                "glyph": "handoff",
                "alarm": False,
                "rows": reviewRows,
                "more": 0,
                "moreLabel": "waiting on review "
            }
        );
    }
    if len(weekDueRows) > 0 {
        groups.append(
            {
                "key": "due",
                "label": "Due this week",
                "glyph": "calendar",
                "alarm": False,
                "rows": weekDueRows,
                "more": -1 if dueCut else 0,
                "moreLabel": "due this week "
            }
        );
    }
    if len(quietRows) > 0 {
        groups.append(
            {
                "key": "quiet",
                "label": "Gone quiet",
                "glyph": "quiet",
                "alarm": False,
                "rows": quietRows,
                "more": 0,
                "moreLabel": "gone quiet "
            }
        );
    }
    needsTotal = len(shown) + hiddenAttention;

    # ---- This week: four figures and tasks that entered Done per day. Log
    # counts come from the page's own week read once it lands, so every day
    # on the page follows one rule; the snapshot's UTC days are the fallback.
    useWeekLog = movesLoaded and not movesFailed and weekEntries >= 0;
    figures = [
        {"label": "moved to Done", "value": str(doneSpark[3])},
        {
            "label": "tasks added",
            "value": str(weekAdded) if weekAdded >= 0 else ("-" if addedFailed else "…")
        },
        {
            "label": "log entries",
            "value": str(weekEntries)
                if useWeekLog
                else ("…" if not movesLoaded else str(entrySpark[3]))
        },
        {"label": "open tasks", "value": str(openCount)}
    ];
    anyDone = False;
    for v in doneMoves {
        if v > 0 {
            anyDone = True;
        }
    }
    for v in doneSpark {
        if v > 0 {
            anyDone = True;
        }
    }
    dayRows: list[dict] = [];
    for i in range(7) {
        if i < 5 or doneMoves[i] > 0 or todayIdx >= 5 {
            dayRows.append(
                {
                    "name": DAY_NAMES[i],
                    "label": DAY_LABELS[i],
                    "value": doneMoves[i],
                    "future": i > todayIdx,
                    "today": i == todayIdx
                }
            );
        }
    }
    chartState = "loading"
        if not movesLoaded
        else ("chart" if anyDone and not movesFailed else "none");
    chartNote = "Tasks moved to Done per day. Days still ahead are outlined."
        if chartState != "none"
        else (
            "The day chart could not load."
                if movesFailed
                else "Nothing has moved to Done in four weeks, so there is no day chart yet."
        );

    # ---- Projects and people.
    projRows: list[dict] = [];
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
    personDays: dict[str, list[int]] = weekPeople if useWeekLog else {};
    if not useWeekLog {
        for md in (logs.members if logs else []) {
            personDays[md.name] = md.by_day;
        }
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
                else [0, 0, 0, 0, 0, 0, 0],
            "total": countAll(personDays[m.name]) if m.name in personDays else 0
        } for m in activeMembers
    ];

    # ---- First run: every item from state the page already read. A
    # hand-written line this week ticks the log item (task events are log
    # rows too), so a working team does not get it back each morning.
    noPeople = len(activeMembers) == 0;
    noProject = len(activeProjects) == 0;
    logKnown = movesLoaded and not movesFailed;
    loggedWeek = logKnown and handEntries > 0;
    steps: list[dict] = [];
    steps.append(
        {
            "key": "flow",
            "title": "Pick how work moves",
            "detail": (
                (templateName + " template, " if templateName else "")
                + plural(stepCount, "step", "steps")
                + ("." if templateName else " on your flow line.")
            )
                if stepCount > 0
                else "Start from a template or draw your own steps.",
            "done": stepCount > 0,
            "action": "Redraw" if stepCount > 0 else "Pick a flow line",
            "to": "/flowlines",
            "primary": False
        }
    );
    # CreateTask needs an active project, and the board sends a workspace
    # without one to /setup, so the item asks for a project first.
    steps.append(
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
    steps.append(
        {
            "key": "log",
            "title": "Write today's first log line",
            "detail": "Add a person first, then log what they worked on."
                if noPeople and not loggedWeek
                else (
                    "Logged this week."
                        if loggedWeek
                        else "One sentence about what you worked on."
                ),
            "done": loggedWeek,
            "action": "Add a person" if noPeople else "Open log",
            "to": "/workspace?tab=people" if noPeople else "/log",
            "primary": False
        }
    );
    if ghConfigured {
        steps.append(
            {
                "key": "github",
                "title": "Connect GitHub",
                "detail": ("Connected as @" + ghLogin + ".")
                    if ghConnected and ghLogin
                    else "Optional. Import issues and let a merged pull request move its card.",
                "done": ghConnected,
                "action": "" if ghConnected else "Connect",
                "to": "/github",
                "primary": False
            }
        );
    }
    requiredOpen = 0;
    for s in steps {
        if not s["done"] and s["key"] != "github" {
            if requiredOpen == 0 {
                s["primary"] = True;
            }
            requiredOpen = requiredOpen + 1;
        }
    }
    # Past the early page the checklist is an extra rail panel, shown once
    # both reads land (so no item flips on arrival) and only while a
    # required item is open and no card has reached Done.
    checklistReady = setupLoaded and movesLoaded;
    railChecklist = not early
        and doneEver == 0
        and checklistReady
        and logKnown
        and requiredOpen > 0;
    earlyNote = "Figures and charts appear once there is a task or a log line. Until then there is nothing to count, so nothing is shown.";

    histWeeks = history.weeks if history else [];
    histLabels = [prettyDay(w) for w in histWeeks];
    histAny = countAll(history.scope if history else []) > 0;
    histFinished = countAll(history.finished if history else []) > 0;
    # Layout follows the width the page is given (Ask docks beside it at
    # 1280px), not the viewport: two zones from 52rem, and from 90rem (what
    # 2xl gives the page without Ask) three columns: Needs you, the week, People.
    # People keeps 37rem so its own 36rem column query holds behind the border.
    zones = "flex flex-col gap-4 @min-[52rem]:grid @min-[52rem]:grid-cols-[minmax(0,1.45fr)_minmax(0,1fr)] @min-[52rem]:items-start @min-[90rem]:grid-cols-[minmax(0,5fr)_minmax(0,4fr)_minmax(37rem,5fr)]";

    return
        <div className="@container space-y-4">
            <div className="flex flex-wrap items-baseline gap-x-3 gap-y-1">
                <h1 className="page-title">Overview</h1>
                <span className="num text-[12.5px] text-subtle">
                    {"Week of " + prettyDay(monday)}
                </span>
            </div>
            {if loading {
                <div key="sk" className={zones}>
                    <div className="surface space-y-3 p-3.5">
                        <Skeleton className="h-4 w-24"/>
                        {for i in range(5) {
                            <Skeleton key={str(i)} className="h-6 w-full"/>
                        }}
                    </div>
                    <div className="surface space-y-3 p-3.5">
                        <Skeleton className="h-4 w-20"/>
                        <div className="grid grid-cols-2 gap-3">
                            {for i in range(4) {
                                <Skeleton key={str(i)} className="h-11 w-full"/>
                            }}
                        </div>
                        <Skeleton className="h-28 w-full"/>
                    </div>
                </div>
            } elif failed {
                <LoadFailed
                    key="failed"
                    title="Could not load the overview"
                    onRetry={loadAll}
                />
            } elif early {
                <div key="first" className={zones}>
                    {if checklistReady {
                        <FirstRun
                            key="list"
                            title={"Get " + (orgName or "your workspace") + " moving"}
                            items={steps}
                        />
                    } else {
                        <div key="listsk" className="surface space-y-3 p-3.5">
                            <Skeleton className="h-4 w-48"/>
                            {for i in range(4) {
                                <Skeleton key={str(i)} className="h-10 w-full"/>
                            }}
                        </div>
                    } }
                    <div key="note" className="min-w-0 @min-[90rem]:col-span-2">
                        <ThisWeek figures={[]} days={[]} note={earlyNote}/>
                    </div>
                </div>
            } else {
                <div key="body" className={zones}>
                    <div className="min-w-0 @max-[52rem]:order-1">
                        <NeedsYou
                            groups={groups}
                            total={needsTotal}
                            totalPlus={dueCut}
                            pending={not dueLoaded}
                            failNote={"Could not check what is due this week."
                                if dueFailed
                                else ""}
                            onRetry={loadDue}
                        />
                    </div>
                    <div className="flex min-w-0 flex-col gap-4 @max-[52rem]:contents">
                        {if railChecklist {
                            <div key="list" className="min-w-0 @max-[52rem]:order-2">
                                <FirstRun
                                    title={"Get "
                                        + (orgName or "your workspace")
                                        + " moving"}
                                    items={steps}
                                />
                            </div>
                        }}
                        <div className="min-w-0 @max-[52rem]:order-3">
                            <ThisWeek
                                figures={figures}
                                days={dayRows}
                                chartState={chartState}
                                chartNote={chartNote}
                                onRetry={loadMoves if movesFailed else None}
                            />
                        </div>
                        <div className="min-w-0 @max-[52rem]:order-4">
                            <ProjectBars rows={projRows}/>
                        </div>
                    </div>
                    <div
                        className="min-w-0 @max-[52rem]:order-6 @min-[52rem]:col-span-2 @min-[90rem]:col-span-1"
                    >
                        <PeopleTable
                            rows={peopleRows}
                            dayNames={DAY_LABELS}
                            todayIndex={todayIdx}
                        />
                    </div>
                    <section
                        className="min-w-0 space-y-3 pt-2 @max-[52rem]:order-5 @min-[52rem]:col-span-2 @min-[90rem]:col-span-3"
                        aria-labelledby="over-time"
                    >
                        <div className="flex flex-wrap items-center gap-2">
                            <h2
                                id="over-time"
                                className="section-title mr-auto max-sm:w-full"
                            >
                                Over time
                            </h2>
                            <Select
                                value={historyProject}
                                onValueChange={lambda (v: str) { historyProject = v; }}
                            >
                                <SelectTrigger
                                    className="h-8 w-44 max-sm:w-auto max-sm:flex-1"
                                    size="sm"
                                    aria-label="Chart project"
                                >
                                    <SelectValue/>
                                </SelectTrigger>
                                <SelectContent>
                                    <SelectItem value="all">All projects</SelectItem>
                                    {for p in activeProjects {
                                        <SelectItem key={jid(p)} value={jid(p)}>
                                            {p.name}
                                        </SelectItem>
                                    }}
                                </SelectContent>
                            </Select>
                            <Select
                                value={historyWeeks}
                                onValueChange={lambda (v: str) { historyWeeks = v; }}
                            >
                                <SelectTrigger
                                    className="h-8 w-40 max-sm:w-auto max-sm:flex-1"
                                    size="sm"
                                    aria-label="Chart range"
                                >
                                    <SelectValue/>
                                </SelectTrigger>
                                <SelectContent>
                                    {for r in HISTORY_RANGES {
                                        <SelectItem key={r[0]} value={r[0]}>
                                            {r[1]}
                                        </SelectItem>
                                    }}
                                </SelectContent>
                            </Select>
                        </div>
                        {if historyFailed and not history {
                            <LoadFailed
                                key="hfail"
                                title="Could not load the charts"
                                onRetry={loadHistory}
                            />
                        } elif not history {
                            <div
                                key="hsk"
                                className="grid gap-4 @min-[52rem]:grid-cols-2"
                            >
                                <Skeleton className="h-64 w-full"/>
                                <Skeleton className="h-64 w-full"/>
                            </div>
                        } elif not histAny {
                            <p
                                key="hempty"
                                className="surface px-3.5 py-6 text-[13.5px] text-muted-foreground"
                            >
                                No tasks in this range yet.
                            </p>
                        } else {
                            <div
                                key="hcharts"
                                className={"space-y-3 transition-opacity "
                                    + ("opacity-60" if historyLoading else "")}
                            >
                                <div
                                    className="grid gap-4 @min-[52rem]:grid-cols-2 @min-[52rem]:items-start"
                                >
                                    <BurnUpChart
                                        labels={histLabels}
                                        scope={history.scope}
                                        done={history.done}
                                    />
                                    {if histFinished {
                                        <ThroughputChart
                                            key="tp"
                                            labels={histLabels}
                                            finished={history.finished}
                                            added={history.added}
                                        />
                                    } else {
                                        <section
                                            key="tpnone"
                                            className="surface min-w-0 px-3.5 pt-3 pb-4"
                                            aria-label="Throughput"
                                        >
                                            <h3 className="section-title text-[15px]">
                                                Throughput
                                            </h3>
                                            <p
                                                className="mt-1.5 text-[13.5px] text-muted-foreground"
                                            >
                                                Nothing moved to Done in these weeks, so there are no bars to draw.
                                            </p>
                                        </section>
                                    } }
                                </div>
                                <details className="text-[13px]">
                                    <summary
                                        className="cursor-pointer select-none text-muted-foreground hover:text-foreground"
                                    >
                                        View as table
                                    </summary>
                                    <div className="surface mt-2 overflow-x-auto">
                                        <table className="data-table w-full">
                                            <thead>
                                                <tr>
                                                    <th className="text-left">
                                                        Week of
                                                    </th>
                                                    <th className="text-right!">
                                                        Added
                                                    </th>
                                                    <th className="text-right!">
                                                        Done
                                                    </th>
                                                    <th className="text-right!">
                                                        Scope
                                                    </th>
                                                    <th className="text-right!">
                                                        Done total
                                                    </th>
                                                </tr>
                                            </thead>
                                            <tbody>
                                                {for (i, w) in enumerate(histWeeks) {
                                                    <tr key={w}>
                                                        <td className="num">
                                                            {histLabels[i]}
                                                        </td>
                                                        <td className="num text-right">
                                                            {str(history.added[i])}
                                                        </td>
                                                        <td className="num text-right">
                                                            {str(history.finished[i])}
                                                        </td>
                                                        <td className="num text-right">
                                                            {str(history.scope[i])}
                                                        </td>
                                                        <td className="num text-right">
                                                            {str(history.done[i])}
                                                        </td>
                                                    </tr>
                                                }}
                                            </tbody>
                                        </table>
                                    </div>
                                </details>
                            </div>
                        }   }
                    </section>
                </div>
            }   }
        </div>;
}
