"""flowline - Roadmap (/roadmap): twelve weeks of work on a timeline, each task
a bar from its start to its due date (or across its iteration), grouped by
project under the iteration band. A bar opens the board's task dialog in
place; the Iterations dialog manages the time boxes."""

import from "sonner" { toast }
import from ...models {
    Project,
    MemberView,
    TaskView,
    StepView,
    RoleView,
    IterationView
}
import from ...constants { STATUSES, STATUS_KIND, KIND_STATUS }
import from ...services.iterations.iterations { RoadmapSnapshot, ListIterations }
import from ...services.tasks.tasks { UpdateTask, DeleteTask }
import from ...services.projects.projects { ListProjects, AssignToProject }
import from ...services.roster.roster { ListMembers, ListRoles }
import from ...services.flowlines.flowlines { GetFlowLine }
import from ...components.roadmap.Timeline { RoadmapTimeline }
import from ...components.roadmap.IterationsDialog { IterationsDialog }
import from ...components.board.TaskDialog { TaskDialog }
import from ...components.ui.button { Button }
import from ...components.ui.card { Card, CardContent }
import from ...components.ui.skeleton { Skeleton }
import from ...components.ui.select {
    Select,
    SelectTrigger,
    SelectValue,
    SelectContent,
    SelectItem
}
import from ...components.common.LoadFailed { LoadFailed }
import from ...lib.dates { todayIso, prettyDay }
import from ...lib.utils { fmtEstimate, parseEstimate }
import from "@jac/runtime" { Link }

glob WEEKS: int = 12,
     # The window opens two weeks before this one, and moves four at a time.
     LEAD_WEEKS: int = 2,
     STEP_WEEKS: int = 4,
     DAY_MS: int = 86400000,
     BLANK_TASK: dict[str, str] = {
         "title": "",
         "category": "",
         "tags": "",
         "estimate": "",
         "project": "",
         "priority": "Medium",
         "status": "Backlog",
         "due_date": "",
         "start_date": "",
         "iteration": "none",
         "notes": "",
         "issue": "",
         "pr": "",
         "reviewer": "none",
         "review_due": ""
     },
     HANDOFF_KINDS: list[str] = ["handoff", "blocked"];

def shiftIso(iso: str, days: int) -> str {
    return new(
        Date, new(Date, iso + "T00:00:00Z").getTime() + days * DAY_MS
    ).toISOString()[:10];
}

# The Monday on or before an ISO day. Day 0 of the epoch was a Thursday, so
# (days + 3) % 7 counts days since Monday without a locale.
def mondayOf(iso: str) -> str {
    days = int(new(Date, iso + "T00:00:00Z").getTime() / DAY_MS + 0.5);
    return shiftIso(iso, -((days + 3) % 7));
}

def:pub RoadmapPage -> JsxPage {
    has windowStart: str = shiftIso(mondayOf(todayIso()), -7 * LEAD_WEEKS),
        fProject: str = "all",
        data: any = None,
        loading: bool = True,
        failed: bool = False,
        projects: list[Project] = [],
        members: list[MemberView] = [],
        steps: list[StepView] = [],
        roleRows: list[RoleView] = [],
        iterations: list[IterationView] = [],
        iterationsOpen: bool = False,
        taskOpen: bool = False,
        editTaskId: str = "",
        taskForm: dict[str, str] = BLANK_TASK,
        taskAssignees: list[str] = [],
        taskSaving: bool = False,
        # Only the newest fetch may paint: window and filter changes race.
        reqRef: Ref[any] = Ref();

    async can with entry {
        loadWorkspace();
    }

    async can with (windowStart, fProject) entry {
        loadRoadmap();
    }

    async def loadWorkspace -> None;
    async def loadRoadmap -> None;
    async def reloadIterations -> None;
    def columnKeys -> list[str];
    def columnKind(key: str) -> str;
    def columnKeyOf(t: TaskView, keys: list[str]) -> str;
    def mappedStatus(key: str) -> str;
    def openTask(tid: str) -> None;
    def replaceRow(view: TaskView) -> None;
    def setTaskField(key: str, value: str) -> None;
    def toggleTaskAssignee(memberId: str) -> None;
    async def saveTask -> None;
    async def deleteTask -> None;

    today = todayIso();
    windowEnd = shiftIso(windowStart, WEEKS * 7 - 1);
    rows: list[TaskView] = data["rows"] if data else [];
    activeProjects = [
        p
        for p in projects
        if p.active
    ];
    activeMembers = [
        m
        for m in members
        if m.active
    ];
    taskChecklist: list[dict[str, any]] = [];
    for t in rows {
        if t.id == editTaskId {
            taskChecklist = t.checklist;
        }
    }
    colKeys = columnKeys();
    colLabels: list[str] = [];
    handoffKeys: list[str] = [];
    for key in colKeys {
        label = key;
        for st in steps {
            if st.id == key {
                label = st.name;
            }
        }
        colLabels.append(label);
        if columnKind(key) in HANDOFF_KINDS {
            handoffKeys.append(key);
        }
    }

    return
        <div className="space-y-5">
            <div className="flex flex-wrap items-end justify-between gap-3">
                <div>
                    <h1 className="page-title">Roadmap</h1>
                    <p className="page-subtitle">
                        Work on a timeline, by its dates and iterations. Open a bar to edit it.
                    </p>
                </div>
                <Button variant="outline" onClick={lambda { iterationsOpen = True; }}>
                    Iterations
                </Button>
            </div>
            <div className="flex flex-wrap items-center gap-2">
                <Select
                    value={fProject}
                    onValueChange={lambda (v: str) { fProject = v; }}
                >
                    <SelectTrigger
                        className="h-8 w-44"
                        size="sm"
                        aria-label="Filter by project"
                    >
                        <SelectValue placeholder="Project"/>
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
                <div className="flex items-center gap-1">
                    <Button
                        variant="outline"
                        size="sm"
                        className="h-8"
                        aria-label="Earlier weeks"
                        onClick={lambda { windowStart = shiftIso(
                            windowStart, -7 * STEP_WEEKS
                        ); }}
                    >
                        ‹
                    </Button>
                    <Button
                        variant="outline"
                        size="sm"
                        className="h-8"
                        onClick={lambda { windowStart = shiftIso(
                            mondayOf(today), -7 * LEAD_WEEKS
                        ); }}
                    >
                        Today
                    </Button>
                    <Button
                        variant="outline"
                        size="sm"
                        className="h-8"
                        aria-label="Later weeks"
                        onClick={lambda { windowStart = shiftIso(
                            windowStart, 7 * STEP_WEEKS
                        ); }}
                    >
                        ›
                    </Button>
                </div>
                <span className="text-sm tabular-nums text-muted-foreground">
                    {prettyDay(windowStart) + " – " + prettyDay(windowEnd)}
                </span>
            </div>
            {if loading and not data {
                <Card key="sk">
                    <CardContent className="space-y-2 py-4">
                        {for i in range(8) {
                            <Skeleton key={str(i)} className="h-9 w-full"/>
                        }}
                    </CardContent>
                </Card>
            } elif failed and not data {
                <LoadFailed
                    key="failed"
                    title="Could not load the roadmap"
                    onRetry={loadRoadmap}
                />
            } else {
                <div
                    key="body"
                    className={"space-y-3 transition-opacity "
                        + ("opacity-60" if loading else "")}
                >
                    {if len(rows) == 0 {
                        <Card key="empty">
                            <CardContent
                                className="py-12 text-center text-sm text-muted-foreground"
                            >
                                Nothing is scheduled in these weeks. Give a task a start or due date, or plan it into an iteration.
                            </CardContent>
                        </Card>
                    } else {
                        <RoadmapTimeline
                            key="timeline"
                            fromDate={windowStart}
                            weeks={WEEKS}
                            today={today}
                            iterations={data["iterations"]}
                            rows={rows}
                            starts={data["starts"]}
                            ends={data["ends"]}
                            steps={steps}
                            onOpen={openTask}
                        />
                    } }
                    <div
                        className="flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-muted-foreground"
                    >
                        {if data and int(data["unscheduled"]) > 0 {
                            <span key="unscheduled">
                                {str(data["unscheduled"])
                                    + (
                                        " open task has"
                                            if int(data["unscheduled"]) == 1
                                            else " open tasks have"
                                    )
                                    + " no dates or iteration. "}
                                <Link
                                    to="/tasks"
                                    className="text-foreground underline-offset-4 hover:underline"
                                >
                                    See them in Tasks
                                </Link>
                            </span>
                        }}
                        {if data and data["truncated"] {
                            <span key="truncated">
                                {"Showing the first "
                                    + str(len(rows))
                                    + " of "
                                    + str(data["total"])
                                    + " scheduled tasks; narrow it by project."}
                            </span>
                        }}
                    </div>
                </div>
            }  }
            <IterationsDialog
                open={iterationsOpen}
                iterations={iterations}
                monday={mondayOf(today)}
                onOpenChange={lambda (o: bool) { iterationsOpen = o; }}
                onChanged={reloadIterations}
            />
            <TaskDialog
                open={taskOpen}
                editing={True}
                form={taskForm}
                projects={activeProjects}
                members={activeMembers}
                saving={taskSaving}
                onField={setTaskField}
                onOpenChange={lambda (o: bool) { taskOpen = o; }}
                onSave={saveTask}
                onDelete={deleteTask}
                columnKeys={colKeys}
                columnLabels={colLabels}
                handoffKeys={handoffKeys}
                assignees={taskAssignees}
                onToggleAssignee={toggleTaskAssignee}
                steps={steps}
                roles={roleRows}
                iterations={iterations}
                taskId={editTaskId}
                checklist={taskChecklist}
                onChecklist={replaceRow}
            />
        </div>;
}
