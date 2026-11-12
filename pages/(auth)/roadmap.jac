"""flowline - Roadmap (/roadmap): twelve weeks of one project's work, each
task a bar from its start to its due date, grouped by step in the board's
column order. A bar opens the board's task sheet in place."""

import from "sonner" { toast }
import from "react" { useEffect }
import from ...models { Project, MemberView, TaskRow, TaskView, StepView, RoleView }
import from ...constants { STATUSES, STATUS_KIND, KIND_STATUS, KIND_COLORS }
import from ...services.roadmap.roadmap { RoadmapSnapshot }
import from ...services.tasks.tasks { UpdateTask, DeleteTask }
import from ...services.projects.projects { AssignToProject }
import from ...services.roster.roster { ListMembers }
import from ...lib.workspace { loadWorkspace, forgetWorkspace, cachedProjects }
import from ...lib.project { currentProject }
import from ...lib.filters { defaultProject }
import from ...components.flowlines.kinds { colorKey, moveRefusal }
import from ...components.roadmap.span { shiftIso, mondayOf }
import from ...components.roadmap.Timeline { RoadmapTimeline }
import from ...components.roadmap.RoadmapToolbar { RoadmapToolbar }
import from ...components.common.ProjectHead { ProjectHead }
import from ...components.common.LineBar { LineBar }
import from ...components.roadmap.RoadmapEmpty { RoadmapEmpty }
import from ...components.roadmap.RoadmapNotes { RoadmapNotes }
import from ...components.board.TaskDialog { TaskDialog }
import from ...components.common.Reveal { Reveal }
import from ...components.common.LoadFailed { LoadFailed }
import from ...lib.dates { todayIso, prettyDay, dueTone }
import from ...lib.utils { fmtEstimate, parseEstimate }

glob WEEKS: int = 12,
     # The window opens two weeks before this one, and moves four at a time.
     LEAD_WEEKS: int = 2,
     STEP_WEEKS: int = 4,
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
         "notes": "",
         "issue": "",
         "pr": "",
         "reviewer": "none",
         "review_due": ""
     },
     HANDOFF_KINDS: list[str] = ["handoff", "blocked"];

def:pub RoadmapPage -> JsxPage {
    has windowStart: str = shiftIso(mondayOf(todayIso()), -7 * LEAD_WEEKS),
        fProject: str = currentProject(),
        data: any = None,
        loading: bool = True,
        failed: bool = False,
        projects: list[Project] = cachedProjects(),
        # The workspace read has landed, so the line bar names the real steps.
        shared: bool = False,
        members: list[MemberView] = [],
        steps: list[StepView] = [],
        roleRows: list[RoleView] = [],
        taskOpen: bool = False,
        editTaskId: str = "",
        taskForm: dict[str, str] = BLANK_TASK,
        taskAssignees: list[str] = [],
        taskSaving: bool = False,
        # Only the newest fetch may paint: window and project changes race.
        reqRef: Ref[any] = Ref();

    async can with entry {
        loadShared();
    }

    async can with (windowStart, fProject) entry {
        loadRoadmap();
    }

    # The sidebar (or the title's menu) moved every page to another project.
    useEffect(
        lambda {
            onProject = lambda (e: any) { fProject = str(e.detail or "")
                or defaultProject(projects); };
            window.addEventListener("flowline:project", onProject);
            return lambda { window.removeEventListener(
                "flowline:project", onProject
            ); };
        },
        []
    );

    async def loadShared -> None;
    async def loadRoadmap -> None;
    def stepWindow(weeksDelta: int) -> None;
    def goToday -> None;
    def columnKeys -> list[str];
    def columnKind(key: str) -> str;
    def columnKeyOf(t: TaskRow, keys: list[str]) -> str;
    def stepGroups(keys: list[str]) -> list[dict[str, any]];
    def mappedStatus(key: str) -> str;
    def openTask(tid: str) -> None;
    def closeTask(isOpen: bool) -> None;
    def replaceRow(view: TaskView) -> None;
    def absorbDetails(view: TaskView) -> None;
    def setTaskField(key: str, value: str) -> None;
    def toggleTaskAssignee(memberId: str) -> None;
    async def saveTask -> None;
    async def deleteTask -> None;

    today = todayIso();
    windowEnd = shiftIso(windowStart, WEEKS * 7 - 1);
    rows: list[TaskRow] = data["rows"] if data else [];
    unscheduled = int(data["unscheduled"]) if data else 0;
    late = 0;
    for t in rows {
        if dueTone(t.due_date, t.status, today) == "overdue" {
            late += 1;
        }
    }
    summary = str(len(rows)) + " scheduled";
    if late > 0 {
        summary = summary + ", " + str(late) + " past due";
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
    projectName = "";
    for p in activeProjects {
        if jid(p) == fProject {
            projectName = p.name;
        }
    }
    # The empty state names why these weeks are blank and the one fix.
    emptyText = "Nothing in "
        + (projectName or "this project")
        + " is scheduled in these weeks.";
    emptyAction = "new";
    if not fProject {
        emptyText = "The roadmap shows one project's tasks. Add a project to start.";
        emptyAction = "project";
    } elif not (today >= windowStart and today <= windowEnd) {
        emptyAction = "today";
    } elif unscheduled > 0 {
        emptyText = (
            "1 open task has"
                if unscheduled == 1
                else str(unscheduled) + " open tasks have"
        )
            + " no dates yet. Dates are set in the task sheet on the board.";
        emptyAction = "board";
    }
    taskCreated = "";
    taskUpdated = "";
    taskPrState = "";
    for t in rows {
        if t.id == editTaskId {
            taskCreated = t.created_at;
            taskUpdated = t.updated_at;
            taskPrState = t.pr_state;
        }
    }
    colKeys = columnKeys();
    groups = stepGroups(colKeys);
    colLabels: list[str] = [];
    handoffKeys: list[str] = [];
    colKinds: list[str] = [];
    colColors: list[str] = [];
    colCounts: list[int] = [];
    colAi: list[bool] = [];
    lineCounts: dict[str, any] = data["counts"] if data else {};
    for key in colKeys {
        label = key;
        keyKind = columnKind(key);
        tint = KIND_COLORS[keyKind] if keyKind in KIND_COLORS else "slate";
        runsAi = False;
        for st in steps {
            if st.id == key {
                label = st.name;
                tint = colorKey(st.color);
                runsAi = len(st.ai) > 0;
            }
        }
        colLabels.append(label);
        colKinds.append(keyKind);
        colColors.append(tint);
        colCounts.append(int(lineCounts[key]) if key in lineCounts else 0);
        colAi.append(runsAi);
        if keyKind in HANDOFF_KINDS {
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
                    groups={[]}
                    onOpen={openTask}
                    placeholder={8}
                />
            </div>;
    }

    return
        <div className="flex min-w-0 flex-col gap-3">
            <ProjectHead projects={activeProjects} project={fProject} view="roadmap">
                <div className="min-h-[30px]">
                    {if shared and fProject {
                        <LineBar
                            key="line"
                            name="Flow line"
                            keys={colKeys}
                            labels={colLabels}
                            kinds={colKinds}
                            colors={colColors}
                            counts={colCounts}
                            ai={colAi}
                        />
                    }}
                </div>
            </ProjectHead>
            <RoadmapToolbar
                rangeLabel={prettyDay(windowStart)
                    + " to "
                    + prettyDay(windowEnd)
                    + ", twelve weeks"}
                onEarlier={lambda { stepWindow(-STEP_WEEKS); }}
                onToday={goToday}
                onLater={lambda { stepWindow(STEP_WEEKS); }}
                summary={summary if data else ""}
                undated={unscheduled}
                busy={loading and bool(data)}
            />
            <Reveal ready={bool(data) or not loading} frame={loadFrame()}>
                {if failed and not data {
                    <LoadFailed
                        key="failed"
                        title="Could not load the roadmap"
                        onRetry={loadRoadmap}
                    />
                } elif len(rows) == 0 {
                    <RoadmapEmpty
                        key="empty"
                        text={emptyText}
                        action={emptyAction}
                        onToday={goToday}
                        busy={loading}
                    />
                } else {
                    <div
                        key="body"
                        className="flex min-w-0 flex-col gap-3"
                        aria-busy={loading}
                    >
                        <RoadmapTimeline
                            fromDate={windowStart}
                            weeks={WEEKS}
                            today={today}
                            groups={groups}
                            onOpen={openTask}
                        />
                        {if bool(data["truncated"]) {
                            <RoadmapNotes key="notes" shown={len(rows)}/>
                        }}
                    </div>
                }  }
            </Reveal>
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
                taskId={editTaskId}
                onLoaded={absorbDetails}
                onChecklist={replaceRow}
                createdAt={taskCreated}
                historyKey={taskUpdated}
                prState={taskPrState}
            />
        </div>;
}
