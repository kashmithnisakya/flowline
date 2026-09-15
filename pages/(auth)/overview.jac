"""flowline - Overview: what needs someone now, then how the week is going.
Counts come from the server over the whole history (OverviewSnapshot); the
page adds three small reads: the working set sorted by due date (due this
week, overdue per project), this week's log (moves to Done per day) and the
weekly history. A workspace with no tasks gets a first-run checklist."""

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
import from ...constants { FLOW_LINE_TEMPLATES }
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
        loading: bool = True,
        failed: bool = False,
        # Open work sorted by due date, for due this week and per-project overdue.
        dueRows: list[TaskView] = [],
        dueLoaded: bool = False,
        # This week's moves to Done per weekday, read off the log.
        doneMoves: list[int] = [0, 0, 0, 0, 0, 0, 0],
        movesLoaded: bool = False,
        movesFailed: bool = False,
        weekAdded: int = -1,
        orgName: str = "",
        # First-run state, read only for a workspace with no tasks.
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

    async def loadAll -> None;
    async def loadDue -> None;
    async def loadMoves -> None;
    async def loadSetup -> None;
    async def loadHistory -> None;

    today = todayIso();
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
    fresh = (True if counts else False) and taskTotal == 0;
    # Weekly counts, oldest first, four weeks ending in this one. Guarded
    # with len(): both lists are empty until the counts land.
    doneSpark = counts.done_by_week
        if counts and len(counts.done_by_week) == 4
        else [0, 0, 0, 0];
    entrySpark = logs.by_week if logs and len(logs.by_week) == 4 else [0, 0, 0, 0];
    dayCounts = logs.by_day
        if logs and len(logs.by_day) == 7
        else [0, 0, 0, 0, 0, 0, 0];
    openCount = counts.open if counts else 0;

    # ---- Needs you: each task sits in the first group it qualifies for.
    shown: list[str] = [];
    overdueRows: list[dict] = [];
    blockedRows: list[dict] = [];
    for t in attention {
        shown.append(t.id);
        late = len(t.due_date) >= 10 and t.due_date < today;
        if t.status == "Blocked" {
            info = blockedInfo[t.id] if t.id in blockedInfo else {};
            reason = plainLine(info["reason"]) if t.id in blockedInfo else "";
            since = info["since"] if t.id in blockedInfo else t.updated_at[:10];
            blockedRows.append(
                {
                    "id": t.id,
                    "title": t.title,
                    "meta": t.project_name,
                    "note": reason,
                    "noteWarn": False,
                    "names": t.assignee_names,
                    "time": relDay(t.due_date, today)
                        if late
                        else ("since " + prettyDay(since) if len(since) >= 10 else ""),
                    "late": late
                }
            );
        } else {
            overdueRows.append(
                {
                    "id": t.id,
                    "title": t.title,
                    "meta": t.project_name,
                    "note": "",
                    "noteWarn": False,
                    "names": t.assignee_names,
                    "time": relDay(t.due_date, today),
                    "late": True
                }
            );
        }
    }
    byId: dict[str, TaskView] = {};
    for t in dueRows {
        byId[t.id] = t;
    }
    reviewRows: list[dict] = [];
    for r in reviewQueue {
        if r["task_id"] in shown {
            continue;
        }
        shown.append(r["task_id"]);
        reviewer = r["reviewer"];
        waited = r["waiting_days"];
        # The review's own due date, else the task's; the reviewer's avatar,
        # else whoever holds the card while it waits.
        due = r["review_due"];
        who: list[str] = [reviewer] if reviewer else [];
        if r["task_id"] in byId {
            held = byId[r["task_id"]];
            if len(due) < 10 {
                due = held.due_date;
            }
            if not reviewer {
                who = held.assignee_names;
            }
        }
        reviewRows.append(
            {
                "id": r["task_id"],
                "title": r["title"],
                "meta": r["project"],
                "note": (reviewer.split(" ")[0] + " reviewing")
                    if reviewer
                    else "no reviewer",
                "noteWarn": not reviewer,
                "names": who,
                "time": relDay(due, today)
                    if len(due) >= 10
                    else (
                        "waiting " + plural(waited, "day", "days") if waited > 0 else ""
                    ),
                "late": len(due) >= 10 and due < today
            }
        );
    }
    weekDueRows: list[dict] = [];
    overdueByProject: dict[str, int] = {};
    for t in dueRows {
        if t.status == "Done" or len(t.due_date) < 10 {
            continue;
        }
        if t.due_date < today and t.status != "Blocked" and t.project_id {
            overdueByProject[t.project_id] = (
                overdueByProject[t.project_id]
                    if t.project_id in overdueByProject
                    else 0
            )
                + 1;
        }
        if t.status == "Blocked" or t.id in shown or t.due_date > sunday {
            continue;
        }
        shown.append(t.id);
        weekDueRows.append(
            {
                "id": t.id,
                "title": t.title,
                "meta": t.project_name,
                "note": "",
                "noteWarn": False,
                "names": t.assignee_names,
                "time": relDay(t.due_date, today),
                "late": t.due_date < today
            }
        );
    }
    quietRows: list[dict] = [];
    for q in quiet {
        if q["task_id"] in shown {
            continue;
        }
        quietRows.append(
            {
                "id": q["task_id"],
                "title": q["title"],
                "meta": q["project"],
                "note": "",
                "noteWarn": False,
                "names": [
                    n.strip()
                    for n in q["assignees"].split(",")
                    if n.strip()
                ],
                "time": plural(q["idle_days"], "day", "days") + " idle",
                "late": False
            }
        );
    }
    hiddenAttention = attentionTotal - len(attention);
    groups: list[dict] = [];
    if len(overdueRows) > 0 {
        groups.append(
            {
                "key": "overdue",
                "label": "Overdue",
                "glyph": "blocked",
                "alarm": True,
                "rows": overdueRows,
                "more": hiddenAttention if len(blockedRows) == 0 else 0,
                "moreLabel": "overdue or blocked "
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
                "more": hiddenAttention,
                "moreLabel": "overdue or blocked "
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
                "more": 0,
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
    needsTotal = attentionTotal + len(reviewRows) + len(weekDueRows) + len(quietRows);

    # ---- This week: four figures and moves to Done per day.
    figures = [
        {"label": "moved to Done", "value": str(doneSpark[3])},
        {"label": "tasks added", "value": str(weekAdded) if weekAdded >= 0 else "…"},
        {"label": "log entries", "value": str(entrySpark[3])},
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
    chartNote = "Moved to Done per day. Days still ahead are outlined."
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
    personDays: dict[str, list[int]] = {};
    personTotal: dict[str, int] = {};
    for md in (logs.members if logs else []) {
        personDays[md.name] = md.by_day;
        personTotal[md.name] = md.total;
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
            "total": personTotal[m.name] if m.name in personTotal else 0
        } for m in activeMembers
    ];

    # ---- First run: every item from state the page already read.
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
    steps.append(
        {
            "key": "task",
            "title": "Add your first task",
            "detail": ("It lands in " + firstStepName + ".")
                if firstStepName
                else "It lands in the first column of the board.",
            "done": taskTotal > 0,
            "action": "New task",
            "to": "/board?new=1",
            "primary": False
        }
    );
    steps.append(
        {
            "key": "log",
            "title": "Write today's first log line",
            "detail": "One sentence about what you worked on.",
            "done": dayCounts[todayIdx] > 0,
            "action": "Open log",
            "to": "/log",
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
    for s in steps {
        if not s["done"] and s["key"] != "github" {
            s["primary"] = True;
            break;
        }
    }

    histWeeks = history.weeks if history else [];
    histLabels = [prettyDay(w) for w in histWeeks];
    histAny = False;
    for v in (history.scope if history else []) {
        if v > 0 {
            histAny = True;
        }
    }
    zones = "flex flex-col gap-4 lg:grid lg:grid-cols-[minmax(0,1.45fr)_minmax(0,1fr)] lg:items-start";

    return
        <div className="max-w-[1200px] space-y-4">
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
            } elif fresh {
                <div key="first" className={zones}>
                    {if setupLoaded {
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
                    <ThisWeek
                        figures={[]}
                        days={[]}
                        note="Figures and charts appear once the first task is on the board. Until then there is nothing to count, so nothing is shown."
                    />
                </div>
            } else {
                <div key="body" className={zones}>
                    <div className="flex min-w-0 flex-col gap-4 max-lg:contents">
                        <div className="min-w-0 max-lg:order-1">
                            <NeedsYou
                                groups={groups}
                                total={needsTotal}
                                pending={not dueLoaded}
                            />
                        </div>
                        {if len(peopleRows) > 0 {
                            <div key="people" className="min-w-0 max-lg:order-5">
                                <PeopleTable
                                    rows={peopleRows}
                                    dayNames={DAY_LABELS}
                                    todayIndex={todayIdx}
                                />
                            </div>
                        }}
                    </div>
                    <div className="flex min-w-0 flex-col gap-4 max-lg:contents">
                        <div className="min-w-0 max-lg:order-2">
                            <ThisWeek
                                figures={figures}
                                days={dayRows}
                                chartState={chartState}
                                chartNote={chartNote}
                            />
                        </div>
                        {if len(projRows) > 0 {
                            <div key="projects" className="min-w-0 max-lg:order-3">
                                <ProjectBars rows={projRows}/>
                            </div>
                        }}
                    </div>
                    <section
                        className="min-w-0 space-y-3 pt-2 max-lg:order-4 lg:col-span-2"
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
                            <div key="hsk" className="grid gap-4 lg:grid-cols-2">
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
                                    className="grid gap-4 lg:grid-cols-2 lg:items-start"
                                >
                                    <BurnUpChart
                                        labels={histLabels}
                                        scope={history.scope}
                                        done={history.done}
                                    />
                                    <ThroughputChart
                                        labels={histLabels}
                                        finished={history.finished}
                                        added={history.added}
                                    />
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
