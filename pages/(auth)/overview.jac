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
import from "sonner" { toast }
import from ...components.common.glyphs { WarnIcon }

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
     HUES: list[str] = [
         "bg-chart-1/15 text-chart-1",
         "bg-chart-2/15 text-chart-2",
         "bg-chart-3/15 text-chart-3",
         "bg-chart-4/15 text-chart-4",
         "bg-chart-5/15 text-chart-5"
     ],
     SK_BARS: list[str] = ["h-16", "h-24", "h-12", "h-32", "h-20", "h-10", "h-28"];

# Avatar hue pairs picked by name hash; whole literal strings so Tailwind scans them.

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

# Deterministic avatar hue: sum of character codes into the hue table.
def hueFor(name: any) -> str {
    total = 0;
    for i in range(len(name)) {
        total = total + name.charCodeAt(i);
    }
    return HUES[total % 5];
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
    peakEntries = 1;
    for mm in activeMembers {
        cnt = len(
            [
                e
                for e in entries
                if e.member_name == mm.name
            ]
        );
        if cnt > peakEntries {
            peakEntries = cnt;
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
                <div
                    key="failed"
                    className="flex flex-col items-center gap-4 rounded-xl border border-destructive/30 bg-destructive/10 px-6 py-12 text-center animate-in fade-in slide-in-from-top-1"
                >
                    <WarnIcon size={28} className="text-destructive"/>
                    <div>
                        <p className="text-sm font-semibold">
                            Could not load the overview.
                        </p>
                        <p className="mt-1 text-sm text-muted-foreground">
                            Something went wrong while fetching your workspace data.
                        </p>
                    </div>
                    <Button variant="outline" size="sm" onClick={loadAll}>
                        Try again
                    </Button>
                </div>
            } else {
                <div key="body" className="space-y-8">
                    <div
                        className="anim-fade-up anim-d1 grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-5"
                    >
                        <StatTile label="Members" value={str(len(activeMembers))}/>
                        <StatTile label="Projects" value={str(len(activeProjects))}/>
                        <StatTile label="Open tasks" value={str(len(openTasks))}/>
                        <StatTile
                            label="Done this week"
                            value={str(len(doneWeek))}
                            accent="text-success"
                        />
                        <StatTile
                            label="Log entries"
                            value={str(len(entries))}
                            hint="this week"
                        />
                    </div>
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
                                        <span
                                            className={"flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-xs font-bold " + hueFor(
                                                m.name
                                            )}
                                        >
                                            {(
                                                m.name.split()[0][:1] + (
                                                    m.name.split()[1][:1]
                                                        if len(m.name.split()) > 1
                                                        else ""
                                                )
                                            ).upper()}
                                        </span>
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
                                        className="flex w-full flex-1 items-center gap-3"
                                    >
                                        <div
                                            className="flex-1"
                                            title={m.name + ": " + str(
                                                len(
                                                    [
                                                        e
                                                        for e in entries
                                                        if e.member_name == m.name
                                                    ]
                                                )
                                            ) + " entries this week"}
                                        >
                                            <div
                                                className="h-2.5 rounded-full transition-[width] duration-500 ease-out"
                                                style={{
                                                    "width": scaled(
                                                        len(
                                                            [
                                                                e
                                                                for e in entries
                                                                if e.member_name == m.name
                                                            ]
                                                        ),
                                                        peakEntries,
                                                        92
                                                    ),
                                                    "background": "var(--primary)",
                                                    "minWidth": "2px"
                                                }}
                                            />
                                        </div>
                                        <span
                                            className="w-16 shrink-0 text-right text-xs tabular-nums text-muted-foreground"
                                        >
                                            {str(
                                                len(
                                                    [
                                                        e
                                                        for e in entries
                                                        if e.member_name == m.name
                                                    ]
                                                )
                                            )} entries
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
