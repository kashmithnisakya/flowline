"""standup - Overview: org-wide summary, progress and activity metrics,
aggregated client-side over the existing walkers. Charts are plain marks:
Done (pine) and Active (ember) fills over a muted Backlog track, counts
labelled so nothing is colour-alone."""

import from ...models { Project, MemberView, TaskView, LogEntry, VocabTerm }
import from ...walkers.tasks { ListTasks }
import from ...walkers.roster { ListMembers }
import from ...walkers.projects { ListProjects }
import from ...walkers.log { ListLogEntries }
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
def logged(e: LogEntry, name: str) -> bool {
    return name in e.member_name.split(", ");
}


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
    has tasks: list[TaskView] = [],
        members: list[MemberView] = [],
        projects: list[Project] = [],
        entries: list[LogEntry] = [],
        # The three weeks before this one, for deltas and sparklines.
        pastEntries: list[LogEntry] = [],
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
    openTasks = [
        t
        for t in tasks
        if t.status != "Done"
    ];
    doneWeek = [
        t
        for t in tasks
        if t.status == "Done" and t.updated_at[:10] >= monday
    ];
    lastMonday = shiftDay(monday, -7);
    doneLastWeek = [
        t
        for t in tasks
        if t.status == "Done"
        and t.updated_at[:10] >= lastMonday
        and t.updated_at[:10] < monday
    ];
    entriesLastWeek = [
        e
        for e in pastEntries
        if e.date >= lastMonday
    ];
    today = todayIso();
    overdueTasks = [
        t
        for t in tasks
        if dueTone(t.due_date, t.status, today) == "overdue"
    ];
    blockedTasks = [
        t
        for t in tasks
        if t.status == "Blocked"
    ];
    # Weekly counts for the last four weeks, oldest first. A Done task only
    # remembers its last update, the same approximation doneWeek makes.
    doneSpark: list[int] = [];
    entrySpark: list[int] = [];
    for wi in range(4) {
        wStart = shiftDay(monday, -7 * (3 - wi));
        wEnd = shiftDay(wStart, 7);
        doneSpark.append(
            len(
                [
                    t
                    for t in tasks
                    if t.status == "Done"
                    and t.updated_at[:10] >= wStart
                    and t.updated_at[:10] < wEnd
                ]
            )
        );
        entrySpark.append(
            len(
                [
                    e
                    for e in (pastEntries + entries)
                    if e.date >= wStart and e.date < wEnd
                ]
            )
        );
    }
    # Blocked first, then the most overdue; a task can be both.
    attention = blockedTasks + [
        t
        for t in overdueTasks
        if t.status != "Blocked"
    ];
    dayCounts = [
        len(
            [
                e
                for e in entries
                if e.date == d
            ]
        ) for d in weekDays
    ];
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
                            {" · " + str(len(activeMembers)) + (
                                " person" if len(activeMembers) == 1 else " people"
                            ) + " · " + str(len(activeProjects)) + (
                                " project" if len(activeProjects) == 1 else " projects"
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
                        <StatTile label="Open" value={str(len(openTasks))}/>
                        <StatTile
                            label="Done this week"
                            value={str(len(doneWeek))}
                            accent="text-success"
                            delta={len(doneWeek) - len(doneLastWeek)}
                            showDelta={True}
                            spark={doneSpark}
                        />
                        <StatTile
                            label="Overdue"
                            value={str(len(overdueTasks))}
                            accent={"text-destructive" if len(overdueTasks) > 0 else ""}
                            hint={"all clear"
                                if len(overdueTasks) == 0
                                else "past due, still open"}
                        />
                        <StatTile
                            label="Blocked"
                            value={str(len(blockedTasks))}
                            accent={"text-destructive" if len(blockedTasks) > 0 else ""}
                            hint={"all clear"
                                if len(blockedTasks) == 0
                                else "needs a decision"}
                        />
                        <StatTile
                            label="Log entries"
                            value={str(len(entries))}
                            delta={len(entries) - len(entriesLastWeek)}
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
                            {for t in attention[:8] {
                                <Link
                                    key={t.id}
                                    to={"/board?task=" + t.id}
                                    className="flex items-center gap-3 rounded-lg px-2 py-2 transition-colors hover:bg-accent"
                                >
                                    <span
                                        className={"shrink-0 rounded-md px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wide " + (
                                            "bg-destructive/10 text-destructive"
                                        )}
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
                            {if len(attention) > 8 {
                                <Link
                                    key="more"
                                    to="/board"
                                    className="block px-2 pt-2 text-xs font-medium text-primary hover:underline"
                                >
                                    {"+" + str(len(attention) - 8) + " more on the board"}
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
                                            title={DAY_LABELS[i] + ": " + str(
                                                dayCounts[i]
                                            ) + " entries"}
                                        >
                                            <span
                                                className={"h-4 text-xs tabular-nums " + (
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
                                                        len(
                                                            [
                                                                t
                                                                for t in tasks
                                                                if t.project_id == jid(
                                                                    p
                                                                )
                                                                and t.status == "Done"
                                                            ]
                                                        )
                                                    )}/{str(
                                                        len(
                                                            [
                                                                t
                                                                for t in tasks
                                                                if t.project_id == jid(
                                                                    p
                                                                )
                                                            ]
                                                        )
                                                    )} done
                                                </span>
                                                {if len(
                                                    [
                                                        t
                                                        for t in tasks
                                                        if t.project_id == jid(p)
                                                        and t.status == "Blocked"
                                                    ]
                                                ) > 0 {
                                                    <Badge
                                                        key="blocked"
                                                        variant="destructive"
                                                    >
                                                        {len(
                                                            [
                                                                t
                                                                for t in tasks
                                                                if t.project_id == jid(
                                                                    p
                                                                )
                                                                and t.status == "Blocked"
                                                            ]
                                                        )} blocked
                                                    </Badge>
                                                }}
                                            </span>
                                        </div>
                                        <div
                                            className="flex h-2.5 gap-0.5 overflow-hidden rounded-full bg-muted"
                                            title={p.name}
                                        >
                                            {if len(
                                                [
                                                    t
                                                    for t in tasks
                                                    if t.project_id == jid(p)
                                                    and t.status == "Done"
                                                ]
                                            ) > 0 {
                                                <div
                                                    key="done"
                                                    className="transition-[width] duration-500 ease-out"
                                                    style={{
                                                        "width": pct(
                                                            len(
                                                                [
                                                                    t
                                                                    for t in tasks
                                                                    if t.project_id == jid(
                                                                        p
                                                                    )
                                                                    and t.status == "Done"
                                                                ]
                                                            ),
                                                            len(
                                                                [
                                                                    t
                                                                    for t in tasks
                                                                    if t.project_id == jid(
                                                                        p
                                                                    )
                                                                ]
                                                            )
                                                        ),
                                                        "background": "var(--success)"
                                                    }}
                                                />
                                            }}
                                            {if len(
                                                [
                                                    t
                                                    for t in tasks
                                                    if t.project_id == jid(p)
                                                    and t.status in ACTIVE_STATUSES
                                                ]
                                            ) > 0 {
                                                <div
                                                    key="active"
                                                    className="transition-[width] duration-500 ease-out"
                                                    style={{
                                                        "width": pct(
                                                            len(
                                                                [
                                                                    t
                                                                    for t in tasks
                                                                    if t.project_id == jid(
                                                                        p
                                                                    )
                                                                    and t.status in ACTIVE_STATUSES
                                                                ]
                                                            ),
                                                            len(
                                                                [
                                                                    t
                                                                    for t in tasks
                                                                    if t.project_id == jid(
                                                                        p
                                                                    )
                                                                ]
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
                                                    len(
                                                        [
                                                            t
                                                            for t in openTasks
                                                            if m.id in t.assignee_ids
                                                        ]
                                                    )
                                                )} open ·{" " + str(
                                                    len(
                                                        [
                                                            t
                                                            for t in doneWeek
                                                            if m.id in t.assignee_ids
                                                        ]
                                                    )
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
                                            aria-label={m.name + ": logged on " + str(
                                                len(
                                                    [
                                                        d
                                                        for d in weekDays
                                                        if len(
                                                            [
                                                                e
                                                                for e in entries
                                                                if logged(e, m.name)
                                                                and e.date == d
                                                            ]
                                                        ) > 0
                                                    ]
                                                )
                                            ) + " of 7 days"}
                                        >
                                            {for (di, d) in enumerate(weekDays) {
                                                <span
                                                    key={d}
                                                    title={DAY_LABELS[di] + ": " + str(
                                                        len(
                                                            [
                                                                e
                                                                for e in entries
                                                                if logged(e, m.name)
                                                                and e.date == d
                                                            ]
                                                        )
                                                    ) + " entries"}
                                                    className={"h-3.5 w-3.5 rounded-[4px] " + (
                                                        "bg-primary"
                                                            if len(
                                                                [
                                                                    e
                                                                    for e in entries
                                                                    if logged(e, m.name)
                                                                    and e.date == d
                                                                ]
                                                            ) > 0
                                                            else "bg-muted"
                                                    ) + (
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
                                                len(
                                                    [
                                                        e
                                                        for e in entries
                                                        if logged(e, m.name)
                                                    ]
                                                )
                                            )}{" entry"
                                                if len(
                                                    [
                                                        e
                                                        for e in entries
                                                        if logged(e, m.name)
                                                    ]
                                                ) == 1
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
