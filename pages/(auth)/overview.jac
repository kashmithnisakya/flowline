"""flowline - Overview: org-wide summary, progress and activity metrics.
Every number here is counted server-side over the whole history (TaskCounts
and LogCounts); the one list, needs-attention, is a page of eight from
ListTasks(scope="attention") with the full count beside it. The page never
loads the workspace to add it up. Charts are plain marks: Done (pine) and
Active (ember) fills over a muted Backlog track, counts labelled so nothing
is colour-alone."""

import from "@jac/runtime" { useState }
import from "react" { useEffect }
import from ...models {
    Project,
    MemberView,
    TaskView,
    TaskTotals,
    ProjectTally,
    LogTotals,
    MemberDays,
    VocabTerm
}
import from ...walkers.tasks { ListTasks, TaskCounts }
import from ...walkers.roster { ListMembers }
import from ...walkers.projects { ListProjects }
import from ...walkers.log { LogCounts }
import from ...components.dashboard.StatTile { StatTile }
import from ...components.ui.card {
    Card,
    CardHeader,
    CardTitle,
    CardDescription,
    CardContent
}
import from ...components.ui.badge { Badge }
import from ...components.ui.button { Button }
import from ...components.ui.skeleton { Skeleton }
import from "@jac/runtime" { Link }
import from ...components.common.LoadFailed { LoadFailed }
import from ...components.common.Avatar { Avatar, AvatarStack }
import from ...lib.dates { todayIso, dueTone, dueLabel, prettyDay }
import from ...lib.session { spaceRoot }

glob DAY_LABELS: list[str] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
     ACTIVE_STATUSES: list[str] = ["In Progress", "Review", "Changes Requested"],
     MONTHS: list[str] = [
         "Jan",
         "Feb",
         "Mar",
         "Apr",
         "May",
         "Jun",
         "Jul",
         "Aug",
         "Sep",
         "Oct",
         "Nov",
         "Dec"
     ],
     SK_BARS: list[str] = ["h-16", "h-24", "h-12", "h-32", "h-20", "h-10", "h-28"];

# Fixed bar-stub heights for the loading chart skeleton (literal classes).
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

# Short human label for an ISO day, e.g. "Aug 4".
def fmtDay(iso: str) -> str {
    d = new(Date, iso + "T00:00:00");
    mi = int(d.getMonth());
    return MONTHS[mi] + " " + str(d.getDate());
}


# An entry's member_name is every assignee, comma-joined, so a plain
# equality misses shared tasks.
def pct(part: int, whole: int) -> str {
    if whole == 0 {
        return "0%";
    }
    return str(part * 100.0 / whole) + "%";
}

# Like pct but capped: the largest value maps to cap% of the track.
def scaled(part: int, whole: int, cap: int) -> str {
    if whole == 0 {
        return "0%";
    }
    return str(part * cap * 1.0 / whole) + "%";
}

def:pub OverviewPage -> JsxPage {
    has attention: list[TaskView] = [],
        attentionTotal: int = 0,
        members: list[MemberView] = [],
        projects: list[Project] = [],
        # Every number on the page, counted over the whole history.
        counts: TaskTotals = TaskTotals(),
        logs: LogTotals = LogTotals(),
        loading: bool = True,
        failed: bool = False;

    async can with entry {
        loadAll();
    }

    async def loadAll -> None;

    monday = mondayOf(localIso(new(Date)));
    weekDays = [shiftDay(monday, i) for i in range(7)];
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
    doneSpark = counts.done_by_week if len(counts.done_by_week) == 4 else [0, 0, 0, 0];
    entrySpark = logs.by_week if len(logs.by_week) == 4 else [0, 0, 0, 0];
    doneWeekCount = doneSpark[3];
    doneLastWeekCount = doneSpark[2];
    entriesWeekCount = entrySpark[3];
    entriesLastWeekCount = entrySpark[2];
    dayCounts = logs.by_day if len(logs.by_day) == 7 else [0, 0, 0, 0, 0, 0, 0];
    # Per project over the whole history (server), and over the working set
    # for the two states that only open work can be in.
    projTotal: dict[str, int] = {};
    projDone: dict[str, int] = {};
    for tally in counts.projects {
        projTotal[tally.project_id] = tally.total;
        projDone[tally.project_id] = tally.done;
    }
    projBlocked: dict[str, int] = {};
    projActive: dict[str, int] = {};
    for tally in counts.projects {
        projBlocked[tally.project_id] = tally.blocked;
        projActive[tally.project_id] = tally.active;
    }
    # Per person, by member jid, over the whole history.
    personOpen: dict[str, int] = {};
    personDone: dict[str, int] = {};
    for mt in counts.members {
        personOpen[mt.member_id] = mt.open;
        personDone[mt.member_id] = mt.done_in_week;
    }
    # Per person this week: a count per weekday and the total, by name.
    personDays: dict[str, list[int]] = {};
    personTotal: dict[str, int] = {};
    for md in logs.members {
        personDays[md.name] = md.by_day;
        personTotal[md.name] = md.total;
    }
    today = todayIso();
    # NOTE: max(list) compiles to JS Math.max(array) which is NaN; loop instead.
    maxDay = 1;
    for c in dayCounts {
        if c > maxDay {
            maxDay = c;
        }
    }

    return
        <div className="space-y-8">
            <div className="anim-fade-up">
                <div className="flex flex-wrap items-center gap-x-3 gap-y-1">
                    <h1 className="page-title">Overview</h1>
                    <span
                        className="inline-flex items-center gap-1.5 rounded-full border border-border/70 bg-muted px-2.5 py-0.5 text-xs font-medium tabular-nums text-muted-foreground"
                    >
                        <svg
                            width={14}
                            height={14}
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth={2}
                            strokeLinecap="round"
                            strokeLinejoin="round"
                        >
                            <path d="M8 2v4"/>
                            <path d="M16 2v4"/>
                            <rect width={18} height={18} x={3} y={4} rx={2}/>
                            <path d="M3 10h18"/>
                        </svg>
                        {fmtDay(monday) + " – " + fmtDay(weekDays[6])}
                    </span>
                </div>
                <p className="page-subtitle">
                    Where the work stands across projects and people.
                    {if not loading and not failed {
                        <span key="counts" className="text-muted-foreground/70">
                            {" · "
                                + str(len(activeMembers))
                                + (" person" if len(activeMembers) == 1 else " people")
                                + " · "
                                + str(len(activeProjects))
                                + (
                                    " project"
                                        if len(activeProjects) == 1
                                        else " projects"
                                )}
                        </span>
                    }}
                </p>
            </div>
            {if loading {
                <div key="sk" className="space-y-8">
                    <div
                        className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-5"
                    >
                        {for i in range(5) {
                            <Card key={str(i)} className="gap-0 py-4">
                                <CardContent className="px-4">
                                    <Skeleton className="h-3 w-16"/>
                                    <Skeleton className="mt-2 h-8 w-12"/>
                                    <Skeleton className="mt-2 h-3 w-14"/>
                                </CardContent>
                            </Card>
                        }}
                    </div>
                    <div className="grid gap-6 lg:grid-cols-2 lg:items-start">
                        <Card>
                            <CardHeader>
                                <Skeleton className="h-4 w-36"/>
                                <Skeleton className="h-3 w-44"/>
                            </CardHeader>
                            <CardContent>
                                <div className="flex h-40 items-end gap-3">
                                    {for i in range(7) {
                                        <div
                                            key={DAY_LABELS[i]}
                                            className="flex h-full flex-1 flex-col items-center justify-end gap-1"
                                        >
                                            <Skeleton
                                                className={"w-full " + SK_BARS[i]}
                                            />
                                            <Skeleton className="h-3 w-6"/>
                                        </div>
                                    }}
                                </div>
                            </CardContent>
                        </Card>
                        <Card>
                            <CardHeader>
                                <Skeleton className="h-4 w-32"/>
                                <Skeleton className="h-3 w-52"/>
                            </CardHeader>
                            <CardContent className="space-y-4">
                                {for i in range(3) {
                                    <div key={str(i)} className="space-y-1.5">
                                        <div
                                            className="flex items-center justify-between"
                                        >
                                            <Skeleton className="h-4 w-28"/>
                                            <Skeleton className="h-3 w-16"/>
                                        </div>
                                        <Skeleton
                                            className="h-2.5 w-full rounded-full"
                                        />
                                    </div>
                                }}
                            </CardContent>
                        </Card>
                    </div>
                    <Card>
                        <CardHeader>
                            <Skeleton className="h-4 w-20"/>
                            <Skeleton className="h-3 w-56"/>
                        </CardHeader>
                        <CardContent className="space-y-3">
                            {for i in range(3) {
                                <div key={str(i)} className="flex items-center gap-3">
                                    <Skeleton
                                        className="h-8 w-8 shrink-0 rounded-full"
                                    />
                                    <div className="w-40 space-y-1.5">
                                        <Skeleton className="h-4 w-24"/>
                                        <Skeleton className="h-3 w-32"/>
                                    </div>
                                    <Skeleton className="h-2.5 flex-1 rounded-full"/>
                                    <Skeleton className="h-3 w-14 shrink-0"/>
                                </div>
                            }}
                        </CardContent>
                    </Card>
                </div>
            } elif failed {
                <LoadFailed
                    key="failed"
                    title="Could not load the overview"
                    onRetry={loadAll}
                />
            } else {
                <div key="body" className="space-y-8">
                    <div
                        className="anim-fade-up anim-d1 grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-5"
                    >
                        <StatTile label="Open" value={str(counts.open)}/>
                        <StatTile
                            label="Done this week"
                            value={str(doneWeekCount)}
                            accent="text-success"
                            delta={doneWeekCount - doneLastWeekCount}
                            showDelta={True}
                            spark={doneSpark}
                        />
                        <StatTile
                            label="Overdue"
                            value={str(counts.overdue)}
                            accent={"text-destructive" if counts.overdue > 0 else ""}
                            hint={"all clear"
                                if counts.overdue == 0
                                else "past due, still open"}
                        />
                        <StatTile
                            label="Blocked"
                            value={str(counts.blocked)}
                            accent={"text-destructive" if counts.blocked > 0 else ""}
                            hint={"all clear"
                                if counts.blocked == 0
                                else "needs a decision"}
                        />
                        <StatTile
                            label="Log entries"
                            value={str(entriesWeekCount)}
                            delta={entriesWeekCount - entriesLastWeekCount}
                            showDelta={True}
                            spark={entrySpark}
                        />
                    </div>
                    <Card className="anim-fade-up anim-d2">
                        <CardHeader>
                            <CardTitle className="text-base">Needs attention</CardTitle>
                            <CardDescription>
                                Blocked and overdue work, most urgent first. Open a row to work on it.
                            </CardDescription>
                        </CardHeader>
                        <CardContent className="space-y-1">
                            {for t in attention {
                                <Link
                                    key={t.id}
                                    to={"/board?task=" + t.id}
                                    className="flex items-center gap-3 rounded-lg px-2 py-2 transition-colors hover:bg-accent"
                                >
                                    <span
                                        className={"shrink-0 rounded-md px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wide "
                                            + ("bg-destructive/10 text-destructive")}
                                    >
                                        {"Blocked"
                                            if t.status == "Blocked"
                                            else "Overdue"}
                                    </span>
                                    <span
                                        className="min-w-0 flex-1 truncate text-sm font-medium"
                                    >
                                        {t.title}
                                    </span>
                                    {if len(t.assignee_names) > 0 {
                                        <AvatarStack
                                            key="who"
                                            names={t.assignee_names}
                                        />
                                    }}
                                    <span
                                        className="hidden shrink-0 text-xs text-muted-foreground sm:inline"
                                    >
                                        {(t.project_name + " · ")
                                            if t.project_name
                                            else ""}{(
                                            ("since " + prettyDay(t.updated_at[:10]))
                                                if t.status == "Blocked"
                                                    and len(t.updated_at) >= 10
                                                else dueLabel(
                                                    t.due_date, t.status, today
                                                )
                                        )}
                                    </span>
                                </Link>
                            }}
                            {if attentionTotal > len(attention) {
                                <Link
                                    key="more"
                                    to="/board"
                                    className="block px-2 pt-2 text-xs font-medium text-primary hover:underline"
                                >
                                    {"+"
                                        + str(attentionTotal - len(attention))
                                        + " more on the board"}
                                </Link>
                            }}
                            {if len(attention) == 0 {
                                <div
                                    key="clear"
                                    className="flex items-center gap-2 px-2 py-3 text-sm text-success"
                                >
                                    <svg
                                        width={16}
                                        height={16}
                                        viewBox="0 0 24 24"
                                        fill="none"
                                        stroke="currentColor"
                                        strokeWidth={2}
                                        strokeLinecap="round"
                                        strokeLinejoin="round"
                                        aria-hidden="true"
                                    >
                                        <circle cx={12} cy={12} r={10}/>
                                        <path d="m9 12 2 2 4-4"/>
                                    </svg>
                                    Nothing needs attention. Nothing is blocked or past due.
                                </div>
                            }}
                        </CardContent>
                    </Card>
                    <div
                        className="anim-fade-up anim-d2 grid gap-6 lg:grid-cols-2 lg:items-start"
                    >
                        <Card>
                            <CardHeader>
                                <CardTitle className="text-base">
                                    Activity this week
                                </CardTitle>
                                <CardDescription>
                                    Log entries per weekday.
                                </CardDescription>
                            </CardHeader>
                            <CardContent>
                                <div className="flex h-40 items-end gap-3">
                                    {for i in range(7) {
                                        <div
                                            key={DAY_LABELS[i]}
                                            className="group flex h-full flex-1 flex-col items-center justify-end gap-1"
                                            title={DAY_LABELS[i]
                                                + ": "
                                                + str(dayCounts[i])
                                                + " entries"}
                                        >
                                            <span
                                                className={"h-4 text-xs tabular-nums "
                                                    + (
                                                        "text-muted-foreground"
                                                            if dayCounts[i] > 0
                                                            else "text-muted-foreground/70 opacity-0 transition-opacity duration-200 group-hover:opacity-100"
                                                    )}
                                            >
                                                {str(dayCounts[i])}
                                            </span>
                                            <div
                                                className="w-full rounded-t-sm transition-[height] duration-500 ease-out"
                                                style={{
                                                    "height": scaled(
                                                        dayCounts[i], maxDay, 85
                                                    )
                                                        if dayCounts[i] > 0
                                                        else "2px",
                                                    "background": "var(--primary)"
                                                        if dayCounts[i] > 0
                                                        else "var(--border)"
                                                }}
                                            />
                                            <span
                                                className="text-xs font-medium text-muted-foreground"
                                            >
                                                {DAY_LABELS[i]}
                                            </span>
                                        </div>
                                    }}
                                </div>
                            </CardContent>
                        </Card>
                        <Card>
                            <CardHeader>
                                <CardTitle className="text-base">
                                    Project progress
                                </CardTitle>
                                <CardDescription
                                    className="flex flex-wrap items-center gap-3"
                                >
                                    <span className="inline-flex items-center gap-1.5">
                                        <span
                                            className="h-2 w-2 rounded-full"
                                            style={{"background": "var(--success)"}}
                                        />{" "}
                                        Done
                                    </span>
                                    <span className="inline-flex items-center gap-1.5">
                                        <span
                                            className="h-2 w-2 rounded-full"
                                            style={{"background": "var(--primary)"}}
                                        />{" "}
                                        Active
                                    </span>
                                    <span className="inline-flex items-center gap-1.5">
                                        <span
                                            className="h-2 w-2 rounded-full"
                                            style={{"background": "var(--chart-4)"}}
                                        />{" "}
                                        Backlog
                                    </span>
                                </CardDescription>
                            </CardHeader>
                            <CardContent className="space-y-4">
                                {for p in activeProjects {
                                    <div key={jid(p)} className="space-y-1.5">
                                        <div
                                            className="flex items-center justify-between gap-2 text-sm"
                                        >
                                            <span className="truncate font-medium">
                                                {p.name}
                                            </span>
                                            <span
                                                className="flex shrink-0 items-center gap-2 text-xs tabular-nums text-muted-foreground"
                                            >
                                                <span>
                                                    {str(
                                                        (
                                                            projDone[jid(p)]
                                                                if jid(p) in projDone
                                                                else 0
                                                        )
                                                    )}/{str(
                                                        (
                                                            projTotal[jid(p)]
                                                                if jid(p) in projTotal
                                                                else 0
                                                        )
                                                    )} done
                                                </span>
                                                {if (
                                                    projBlocked[jid(p)]
                                                        if jid(p) in projBlocked
                                                        else 0
                                                )
                                                    > 0 {
                                                    <Badge
                                                        key="blocked"
                                                        variant="destructive"
                                                    >
                                                        {(
                                                            projBlocked[jid(p)]
                                                                if jid(p) in projBlocked
                                                                else 0
                                                        )} blocked
                                                    </Badge>
                                                }}
                                            </span>
                                        </div>
                                        <div
                                            className="flex h-2.5 gap-0.5 overflow-hidden rounded-full bg-muted"
                                            title={p.name}
                                        >
                                            {if (
                                                projDone[jid(p)]
                                                    if jid(p) in projDone
                                                    else 0
                                            )
                                                > 0 {
                                                <div
                                                    key="done"
                                                    className="transition-[width] duration-500 ease-out"
                                                    style={{
                                                        "width": pct(
                                                            (
                                                                projDone[jid(p)]
                                                                    if jid(p)
                                                                        in projDone
                                                                    else 0
                                                            ),
                                                            (
                                                                projTotal[jid(p)]
                                                                    if jid(p)
                                                                        in projTotal
                                                                    else 0
                                                            )
                                                        ),
                                                        "background": "var(--success)"
                                                    }}
                                                />
                                            }}
                                            {if (
                                                projActive[jid(p)]
                                                    if jid(p) in projActive
                                                    else 0
                                            )
                                                > 0 {
                                                <div
                                                    key="active"
                                                    className="transition-[width] duration-500 ease-out"
                                                    style={{
                                                        "width": pct(
                                                            (
                                                                projActive[jid(p)]
                                                                    if jid(p)
                                                                        in projActive
                                                                    else 0
                                                            ),
                                                            (
                                                                projTotal[jid(p)]
                                                                    if jid(p)
                                                                        in projTotal
                                                                    else 0
                                                            )
                                                        ),
                                                        "background": "var(--primary)"
                                                    }}
                                                />
                                            }}
                                        </div>
                                    </div>
                                }}
                                {if len(activeProjects) == 0 {
                                    <div key="none" className="py-10 text-center">
                                        <svg
                                            className="mx-auto text-muted-foreground/50"
                                            width={28}
                                            height={28}
                                            viewBox="0 0 24 24"
                                            fill="none"
                                            stroke="currentColor"
                                            strokeWidth={2}
                                            strokeLinecap="round"
                                            strokeLinejoin="round"
                                        >
                                            <path
                                                d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"
                                            />
                                        </svg>
                                        <p className="mt-3 text-sm font-semibold">
                                            No projects yet
                                        </p>
                                        <p
                                            className="mt-1 text-sm text-muted-foreground"
                                        >
                                            Progress lands here once a project has tasks.
                                        </p>
                                        <Link
                                            to="/workspace"
                                            className="mt-3 inline-flex items-center gap-1.5 text-sm font-medium text-primary hover:underline"
                                        >
                                            Add a project
                                            <svg
                                                width={14}
                                                height={14}
                                                viewBox="0 0 24 24"
                                                fill="none"
                                                stroke="currentColor"
                                                strokeWidth={2}
                                                strokeLinecap="round"
                                                strokeLinejoin="round"
                                            >
                                                <path d="M5 12h14"/>
                                                <path d="m12 5 7 7-7 7"/>
                                            </svg>
                                        </Link>
                                    </div>
                                }}
                            </CardContent>
                        </Card>
                    </div>
                    <Card className="anim-fade-up anim-d3">
                        <CardHeader>
                            <CardTitle className="text-base">People</CardTitle>
                            <CardDescription>
                                Open work and this week's logged activity per person.
                            </CardDescription>
                        </CardHeader>
                        <CardContent className="space-y-3">
                            {for m in activeMembers {
                                <div
                                    key={m.id}
                                    className="flex flex-col gap-2 sm:flex-row sm:items-center sm:gap-3"
                                >
                                    <div
                                        className="flex min-w-0 items-center gap-3 sm:w-52 sm:shrink-0"
                                    >
                                        <Avatar name={m.name} size="md"/>
                                        <div className="min-w-0 flex-1">
                                            <div
                                                className="truncate text-sm font-medium"
                                            >
                                                {m.name}
                                            </div>
                                            <div
                                                className="text-xs tabular-nums text-muted-foreground"
                                            >
                                                {str(
                                                    personOpen[m.id]
                                                        if m.id in personOpen
                                                        else 0
                                                )} open ·{" "
                                                    + str(
                                                        personDone[m.id]
                                                            if m.id in personDone
                                                            else 0
                                                    )} done this week
                                            </div>
                                        </div>
                                    </div>
                                    <div
                                        className="flex w-full flex-1 items-center justify-end gap-3"
                                    >
                                        <span
                                            className="inline-grid grid-cols-7 gap-1"
                                            role="img"
                                            aria-label={m.name
                                                + ": logged on "
                                                + str(
                                                    len(
                                                        [
                                                            c
                                                            for c in (
                                                                personDays[m.name]
                                                                    if m.name
                                                                        in personDays
                                                                    else []
                                                            )
                                                            if c > 0
                                                        ]
                                                    )
                                                )
                                                + " of 7 days"}
                                        >
                                            {for (di, d) in enumerate(weekDays) {
                                                <span
                                                    key={d}
                                                    title={DAY_LABELS[di]
                                                        + ": "
                                                        + str(
                                                            (
                                                                personDays[m.name][di]
                                                                    if m.name
                                                                        in personDays
                                                                    else 0
                                                            )
                                                        )
                                                        + " entries"}
                                                    className={"h-3.5 w-3.5 rounded-[4px] "
                                                        + (
                                                            "bg-primary"
                                                                if (
                                                                    personDays[m.name][
                                                                        di
                                                                    ]
                                                                        if m.name
                                                                            in personDays
                                                                        else 0
                                                                )
                                                                    > 0
                                                                else "bg-muted"
                                                        )
                                                        + (
                                                            " ring-1 ring-foreground/60 ring-offset-1 ring-offset-card"
                                                                if d == today
                                                                else ""
                                                        )}
                                                />
                                            }}
                                        </span>
                                        <span
                                            className="w-16 shrink-0 text-right text-xs tabular-nums text-muted-foreground"
                                        >
                                            {str(
                                                (
                                                    personTotal[m.name]
                                                        if m.name in personTotal
                                                        else 0
                                                )
                                            )}{" entry"
                                                if (
                                                    personTotal[m.name]
                                                        if m.name in personTotal
                                                        else 0
                                                )
                                                    == 1
                                                else " entries"}
                                        </span>
                                    </div>
                                </div>
                            }}
                            {if len(activeMembers) == 0 {
                                <div key="none" className="py-10 text-center">
                                    <svg
                                        className="mx-auto text-muted-foreground/50"
                                        width={28}
                                        height={28}
                                        viewBox="0 0 24 24"
                                        fill="none"
                                        stroke="currentColor"
                                        strokeWidth={2}
                                        strokeLinecap="round"
                                        strokeLinejoin="round"
                                    >
                                        <path
                                            d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"
                                        />
                                        <circle cx={9} cy={7} r={4}/>
                                        <path d="M22 21v-2a4 4 0 0 0-3-3.87"/>
                                        <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
                                    </svg>
                                    <p className="mt-3 text-sm font-semibold">
                                        No members yet
                                    </p>
                                    <p className="mt-1 text-sm text-muted-foreground">
                                        Invite your team so activity shows up here.
                                    </p>
                                    <Link
                                        to="/workspace"
                                        className="mt-3 inline-flex items-center gap-1.5 text-sm font-medium text-primary hover:underline"
                                    >
                                        Invite people
                                        <svg
                                            width={14}
                                            height={14}
                                            viewBox="0 0 24 24"
                                            fill="none"
                                            stroke="currentColor"
                                            strokeWidth={2}
                                            strokeLinecap="round"
                                            strokeLinejoin="round"
                                        >
                                            <path d="M5 12h14"/>
                                            <path d="m12 5 7 7-7 7"/>
                                        </svg>
                                    </Link>
                                </div>
                            }}
                        </CardContent>
                    </Card>
                </div>
            }  }
        </div>;
}
