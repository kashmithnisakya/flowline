"""standup - Overview: org-wide summary, progress and activity metrics.

Client-side aggregation over the existing walkers: tasks, members,
projects and this week's log entries. Charts are plain marks built to the
progress/status encoding: Done (pine) and Active (ember) fills over a
muted Backlog track, with counts labeled so nothing is color-alone.
"""

import from ...models { Project, MemberView, TaskView, LogEntry, VocabTerm }
import from ...walkers.tasks { ListTasks }
import from ...walkers.roster { ListMembers }
import from ...walkers.projects { ListProjects }
import from ...walkers.log { ListLogEntries }
import from ...components.dashboard.StatTile { StatTile }
import from ...components.ui.card {
    Card, CardHeader, CardTitle, CardDescription, CardContent
}
import from ...components.ui.badge { Badge }
import from ...components.ui.skeleton { Skeleton }
import from "sonner" { toast }

glob DAY_LABELS: list[str] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
glob ACTIVE_STATUSES: list[str] = ["In Progress", "Review", "Changes Requested"];

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

def:pub OverviewPage() -> JsxPage {
    has tasks: list[TaskView] = [],
        members: list[MemberView] = [],
        projects: list[Project] = [],
        entries: list[LogEntry] = [],
        loading: bool = True;

    async can with entry {
        loadAll();
    }

    async def loadAll -> None;

    monday = mondayOf(localIso(new(Date)));
    weekDays = [shiftDay(monday, i) for i in range(7)];
    activeMembers = [m for m in members if m.active];
    activeProjects = [p for p in projects if p.active];
    openTasks = [t for t in tasks if t.status != "Done"];
    doneWeek = [t for t in tasks if t.status == "Done" and t.updated_at[:10] >= monday];
    dayCounts = [len([e for e in entries if e.date == d]) for d in weekDays];
    # NOTE: max(list) compiles to JS Math.max(array) which is NaN; loop instead.
    maxDay = 1;
    for c in dayCounts {
        if c > maxDay {
            maxDay = c;
        }
    }
    peakEntries = 1;
    for mm in activeMembers {
        cnt = len([e for e in entries if e.member_name == mm.name]);
        if cnt > peakEntries {
            peakEntries = cnt;
        }
    }

    <div className="space-y-8">
        <div>
            <h1 className="font-display text-2xl font-bold tracking-tight">Overview</h1>
            <p className="text-sm text-muted-foreground">
                Where the work stands across projects and people.
            </p>
        </div>

        {if loading {
            <Skeleton key="sk" className="h-64 w-full" />
        } else {
            <div key="body" className="space-y-8">
                <div className="grid grid-cols-2 gap-4 lg:grid-cols-5">
                    <StatTile label="Members" value={str(len(activeMembers))} />
                    <StatTile label="Projects" value={str(len(activeProjects))} />
                    <StatTile label="Open tasks" value={str(len(openTasks))} />
                    <StatTile label="Done this week" value={str(len(doneWeek))} />
                    <StatTile label="Log entries" value={str(len(entries))} hint="this week" />
                </div>

                <div className="grid gap-6 lg:grid-cols-2 lg:items-start">
                    <Card>
                        <CardHeader>
                            <CardTitle className="text-base">Activity this week</CardTitle>
                            <CardDescription>Log entries per weekday.</CardDescription>
                        </CardHeader>
                        <CardContent>
                            <div className="flex h-40 items-end gap-3">
                                {for i in range(7) {
                                    <div key={DAY_LABELS[i]} className="flex h-full flex-1 flex-col items-center justify-end gap-1" title={DAY_LABELS[i] + ": " + str(dayCounts[i]) + " entries"}>
                                        <span className="text-xs text-muted-foreground">
                                            {str(dayCounts[i]) if dayCounts[i] > 0 else ""}
                                        </span>
                                        <div
                                            className="w-full rounded-t-[4px]"
                                            style={{
                                                "height": scaled(dayCounts[i], maxDay, 85) if dayCounts[i] > 0 else "2px",
                                                "background": "var(--primary)" if dayCounts[i] > 0 else "var(--border)"
                                            }}
                                        />
                                        <span className="text-[11px] font-medium text-muted-foreground">
                                            {DAY_LABELS[i]}
                                        </span>
                                    </div>
                                }}
                            </div>
                        </CardContent>
                    </Card>

                    <Card>
                        <CardHeader>
                            <CardTitle className="text-base">Project progress</CardTitle>
                            <CardDescription className="flex flex-wrap items-center gap-3">
                                <span className="inline-flex items-center gap-1.5">
                                    <span className="h-2 w-2 rounded-full" style={{"background": "var(--success)"}} /> Done
                                </span>
                                <span className="inline-flex items-center gap-1.5">
                                    <span className="h-2 w-2 rounded-full" style={{"background": "var(--primary)"}} /> Active
                                </span>
                                <span className="inline-flex items-center gap-1.5">
                                    <span className="h-2 w-2 rounded-full" style={{"background": "var(--chart-4)"}} /> Backlog
                                </span>
                            </CardDescription>
                        </CardHeader>
                        <CardContent className="space-y-4">
                            {for p in activeProjects {
                                <div key={jid(p)} className="space-y-1.5">
                                    <div className="flex items-center justify-between gap-2 text-sm">
                                        <span className="truncate font-medium">{p.name}</span>
                                        <span className="shrink-0 text-xs text-muted-foreground">
                                            {str(len([t for t in tasks if t.project_id == jid(p) and t.status == "Done"]))}
                                            /{str(len([t for t in tasks if t.project_id == jid(p)]))} done
                                            {if len([t for t in tasks if t.project_id == jid(p) and t.status == "Blocked"]) > 0 {
                                                <Badge key="blocked" variant="destructive" className="ml-2">
                                                    {len([t for t in tasks if t.project_id == jid(p) and t.status == "Blocked"])} blocked
                                                </Badge>
                                            }}
                                        </span>
                                    </div>
                                    <div className="flex h-2.5 gap-0.5 overflow-hidden rounded-full bg-muted" title={p.name}>
                                        {if len([t for t in tasks if t.project_id == jid(p) and t.status == "Done"]) > 0 {
                                            <div key="done" style={{
                                                "width": pct(len([t for t in tasks if t.project_id == jid(p) and t.status == "Done"]), len([t for t in tasks if t.project_id == jid(p)])),
                                                "background": "var(--success)"
                                            }} />
                                        }}
                                        {if len([t for t in tasks if t.project_id == jid(p) and t.status in ACTIVE_STATUSES]) > 0 {
                                            <div key="active" style={{
                                                "width": pct(len([t for t in tasks if t.project_id == jid(p) and t.status in ACTIVE_STATUSES]), len([t for t in tasks if t.project_id == jid(p)])),
                                                "background": "var(--primary)"
                                            }} />
                                        }}
                                    </div>
                                </div>
                            }}
                            {if len(activeProjects) == 0 {
                                <p key="none" className="text-sm text-muted-foreground">No projects yet.</p>
                            }}
                        </CardContent>
                    </Card>
                </div>

                <Card>
                    <CardHeader>
                        <CardTitle className="text-base">People</CardTitle>
                        <CardDescription>Open work and this week's logged activity per person.</CardDescription>
                    </CardHeader>
                    <CardContent className="space-y-3">
                        {for m in activeMembers {
                            <div key={m.id} className="flex items-center gap-3">
                                <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary/10 text-xs font-bold text-primary">
                                    {(m.name.split()[0][:1] + (m.name.split()[1][:1] if len(m.name.split()) > 1 else "")).upper()}
                                </span>
                                <div className="w-40 min-w-0">
                                    <div className="truncate text-sm font-medium">{m.name}</div>
                                    <div className="text-xs text-muted-foreground">
                                        {str(len([t for t in openTasks if t.assignee_id == m.id]))} open ·
                                        {" " + str(len([t for t in doneWeek if t.assignee_id == m.id]))} done this week
                                    </div>
                                </div>
                                <div className="flex-1" title={m.name + ": " + str(len([e for e in entries if e.member_name == m.name])) + " entries this week"}>
                                    <div
                                        className="h-2.5 rounded-full"
                                        style={{
                                            "width": scaled(len([e for e in entries if e.member_name == m.name]), peakEntries, 92),
                                            "background": "var(--primary)",
                                            "minWidth": "2px"
                                        }}
                                    />
                                </div>
                                <span className="w-16 shrink-0 text-right text-xs text-muted-foreground">
                                    {str(len([e for e in entries if e.member_name == m.name]))} entries
                                </span>
                            </div>
                        }}
                        {if len(activeMembers) == 0 {
                            <p key="none" className="text-sm text-muted-foreground">No members yet.</p>
                        }}
                    </CardContent>
                </Card>
            </div>
        }}
    </div>
}
