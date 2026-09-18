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
import from ...services.projects.projects { AssignToProject }
import from ...services.roster.roster { ListMembers }
import from ...lib.workspace { loadWorkspace, forgetWorkspace }
import from ...components.roadmap.Timeline { RoadmapTimeline }
import from ...components.roadmap.RoadmapToolbar { RoadmapToolbar }
import from ...components.roadmap.IterationsDialog { IterationsDialog }
import from ...components.board.TaskDialog { TaskDialog }
import from ...components.ui.button { Button }
import from ...components.ui.skeleton { Skeleton }
import from ...components.common.Reveal { Reveal }
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
        fProject: str = "",
        fIteration: str = "",
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
        loadShared();
    }

    async can with (windowStart, fProject) entry {
        loadRoadmap();
    }

    async def loadShared -> None;
    async def loadRoadmap -> None;
    async def reloadIterations -> None;
    def stepWindow(weeksDelta: int) -> None;
    def goToday -> None;
    def jumpToIteration(iterationId: str) -> None;
    def clearFilters -> None;
    def columnKeys -> list[str];
    def columnKind(key: str) -> str;
    def columnKeyOf(t: TaskView, keys: list[str]) -> str;
    def mappedStatus(key: str) -> str;
    def openTask(tid: str) -> None;
    def closeTask(isOpen: bool) -> None;
    def replaceRow(view: TaskView) -> None;
    def setTaskField(key: str, value: str) -> None;
    def toggleTaskAssignee(memberId: str) -> None;
    async def saveTask -> None;
    async def deleteTask -> None;

    today = todayIso();
    windowEnd = shiftIso(windowStart, WEEKS * 7 - 1);
    allRows: list[TaskView] = data["rows"] if data else [];
    allStarts: list[str] = data["starts"] if data else [];
    allEnds: list[str] = data["ends"] if data else [];
    # The iteration filter is a client-side narrowing of the window's rows, so
    # the three lists have to stay index-aligned.
    rows: list[TaskView] = [];
    starts: list[str] = [];
    ends: list[str] = [];
    for (i, t) in enumerate(allRows) {
        if not fIteration or t.iteration_id == fIteration {
            rows.append(t);
            starts.append(allStarts[i]);
            ends.append(allEnds[i]);
        }
    }
    total = int(data["total"]) if data else 0;
    unscheduled = int(data["unscheduled"]) if data else 0;
    countLabel = str(len(rows)) + (" task" if len(rows) == 1 else " tasks");
    if len(rows) != total {
        countLabel = str(len(rows)) + " of " + str(total) + " tasks";
    }
    unscheduledLabel = (
        "1 open task has" if unscheduled == 1 else str(unscheduled) + " open tasks have"
    )
        + " no dates or iteration";
    projectName = "";
    for p in projects {
        if jid(p) == fProject {
            projectName = p.name;
        }
    }
    iterationName = "";
    for it in iterations {
        if it.id == fIteration {
            iterationName = it.name;
        }
    }
    # The empty panel names why these weeks are blank in one sentence, and its
    # one action is whatever fixes that reason.
    hasToday = today >= windowStart and today <= windowEnd;
    emptyText = "No task has a start or due date in these weeks.";
    emptyAction = "new";
    if fIteration {
        emptyText = "No task "
            + (("in " + projectName + " ") if projectName else "")
            + "is planned into "
            + (iterationName or "this iteration")
            + ".";
        emptyAction = "clear";
    } elif fProject {
        emptyText = "Nothing in "
            + (projectName or "this project")
            + " is scheduled in these weeks.";
        emptyAction = "clear";
    } elif not hasToday {
        emptyText = "Nothing is scheduled in these weeks.";
        emptyAction = "today";
    } elif unscheduled > 0 {
        emptyText = unscheduledLabel + " yet.";
        emptyAction = "tasks";
    }
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
    taskCreated: str = "";
    taskUpdated: str = "";
    taskPrState: str = "";
    for t in allRows {
        if t.id == editTaskId {
            taskChecklist = t.checklist;
            taskCreated = t.created_at;
            taskUpdated = t.updated_at;
            taskPrState = t.pr_state;
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

    def loadFrame -> JsxElement {
        return
            <div key="sk" aria-busy="true">
                <RoadmapTimeline
                    fromDate={windowStart}
                    weeks={WEEKS}
                    today={today}
                    iterations={[]}
                    rows={[]}
                    starts={[]}
                    ends={[]}
                    steps={[]}
                    onOpen={openTask}
                    placeholder={8}
                />
                <div
                    className="flex flex-wrap items-center gap-x-4 gap-y-1 border-t px-4 py-2 text-xs text-muted-foreground"
                >
                    <Skeleton className="h-3 w-16"/>
                    <span className="text-subtle sm:ml-auto">
                        A bar runs from start to due date, or across its iteration.
                    </span>
                </div>
            </div>;
    }

    return
        <div className="flex min-w-0 flex-col gap-4">
            <h1 className="page-title">Roadmap</h1>
            <div className="surface min-w-0 overflow-hidden">
                <RoadmapToolbar
                    projects={activeProjects}
                    iterations={iterations}
                    project={fProject}
                    iteration={fIteration}
                    rangeLabel={prettyDay(windowStart) + " – " + prettyDay(windowEnd)}
                    onProject={lambda (v: str) { fProject = v; }}
                    onIteration={jumpToIteration}
                    onClear={clearFilters}
                    onEarlier={lambda { stepWindow(-STEP_WEEKS); }}
                    onToday={goToday}
                    onLater={lambda { stepWindow(STEP_WEEKS); }}
                    onIterations={lambda { iterationsOpen = True; }}
                    busy={loading and bool(data)}
                />
                <Reveal ready={bool(data) or not loading} frame={loadFrame()}>
                    {if failed and not data {
                        <div key="failed" className="p-4">
                            <LoadFailed
                                title="Could not load the roadmap"
                                onRetry={loadRoadmap}
                            />
                        </div>
                    } elif len(rows) == 0 {
                        <div
                            key="empty"
                            className="flex flex-col items-center gap-4 px-6 py-16 text-center"
                            aria-busy={loading}
                        >
                            <p className="max-w-md text-sm text-muted-foreground">
                                {emptyText}
                            </p>
                            {if emptyAction == "clear" {
                                <Button
                                    key="clear"
                                    variant="outline"
                                    size="sm"
                                    onClick={lambda { clearFilters(); }}
                                >
                                    Clear filters
                                </Button>
                            } elif emptyAction == "today" {
                                <Button
                                    key="today"
                                    variant="outline"
                                    size="sm"
                                    onClick={lambda { goToday(); }}
                                >
                                    Back to this week
                                </Button>
                            } elif emptyAction == "tasks" {
                                <Button key="tasks" size="sm" asChild={True}>
                                    <Link to="/tasks">Set dates in Tasks</Link>
                                </Button>
                            } else {
                                <Button key="new" size="sm" asChild={True}>
                                    <Link to="/board?new=1">New task</Link>
                                </Button>
                            }   }
                        </div>
                    } else {
                        <div key="body" aria-busy={loading}>
                            <RoadmapTimeline
                                fromDate={windowStart}
                                weeks={WEEKS}
                                today={today}
                                iterations={data["iterations"]}
                                rows={rows}
                                starts={starts}
                                ends={ends}
                                steps={steps}
                                onOpen={openTask}
                                remember={not fProject and not fIteration}
                            />
                            <div
                                className="flex flex-wrap items-center gap-x-4 gap-y-1 border-t px-4 py-2 text-xs text-muted-foreground"
                            >
                                <span className="num">{countLabel}</span>
                                {if unscheduled > 0 {
                                    <span key="unscheduled">
                                        {unscheduledLabel + ". "}
                                        <Link
                                            to="/tasks"
                                            className="font-medium text-foreground underline underline-offset-4 hover:decoration-2"
                                        >
                                            See them in Tasks
                                        </Link>
                                    </span>
                                }}
                                {if data["truncated"] {
                                    <span key="truncated">
                                        {"Showing the first "
                                            + str(len(allRows))
                                            + " scheduled tasks. Narrow it by project."}
                                    </span>
                                }}
                                <span className="text-subtle sm:ml-auto">
                                    A bar runs from start to due date, or across its iteration.
                                </span>
                            </div>
                        </div>
                    }  }
                </Reveal>
            </div>
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
                onOpenChange={closeTask}
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
                createdAt={taskCreated}
                historyKey={taskUpdated}
                prState={taskPrState}
            />
        </div>;
}
