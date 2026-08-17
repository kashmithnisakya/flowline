"""standup - Board page (/board): the org's workflow as a kanban. The columns
ARE the workflow steps in designed order, so board and Workflow tab cannot
disagree; with no workflow yet it falls back to the six statuses. Stateful
shell: data and handlers here, columns/cards/filters/dialog presentational."""

import from ...models { Project, MemberView, TaskView, StepView, RepoView, RoleView }
# The one client import of constants.jac. Beyond sharing the status/kind
# mapping, it is what makes the compiler emit constants.js at all: the client
# compiles lazily, and a module nothing imports produces no output.
import from ...constants { STATUSES, STATUS_KIND, KIND_STATUS }

import from ...walkers.projects { ListProjects, AssignToProject }
import from ...walkers.roster { ListMembers, ListRepos, ListRoles }
import from ...walkers.tasks {
    ListTasks,
    CreateTask,
    UpdateTask,
    MoveTask,
    SetMoveInfo,
    DeleteTask
}
import from ...walkers.workflow { GetWorkflow }
import from ...walkers.github { GithubStatus, SyncGithub, CreateIssueFromTask }
import from ...components.common.KineticGrid { KineticGrid }
import from ...components.board.FilterBar { FilterBar }
import from ...components.board.KanbanColumn { KanbanColumn }
import from ...components.board.SwimlaneBoard { SwimlaneBoard }
import from ...components.workflow.lanes { laneLayout }
import from ...components.board.TaskDialog { TaskDialog }
import from ...components.board.MoveDialog { MoveDialog }
import from ...components.ui.button { Button }
import from ...components.ui.skeleton { Skeleton }
import from "sonner" { toast }
import from "react" { useEffect }
import from ...components.common.glyphs { Spinner }
import from ...lib.dates { todayIso, dueTone }

glob BLANK_TASK: dict[str, str] = {
         "title": "",
         "category": "",
         "project": "none",
         "priority": "Medium",
         "status": "Backlog",
         "due_date": "",
         "notes": "",
         "issue": "",
         "pr": "",
         "reviewer": "none",
         "review_due": ""
     },
     BLANK_MOVE: dict[str, str] = {
         "reviewer": "none",
         "review_due": "",
         "pr": "",
         "note": ""
     },
     # Step kinds whose moves open the optional handoff dialog: work that
     # has been passed to someone else, or has stopped.
     HANDOFF_KINDS: list[str] = ["handoff", "blocked"];


def:pub BoardPage -> JsxPage {
    has showAllDone: bool = False,
        tasks: list[TaskView] = [],
        members: list[MemberView] = [],
        projects: list[Project] = [],
        steps: list[StepView] = [],
        # Roles feed the swimlane bands (lane = owner role, as on the
        # Workflow's Lanes view).
        roles: list[RoleView] = [],
        repos: list[RepoView] = [],
        # "lanes" (bands per role, the client's requested shape) or
        # "columns" (one vertical column per step). Persisted per browser.
        boardView: str = "lanes",
        ghConnected: bool = False,
        syncing: bool = False,
        loading: bool = True,
        movesRef: Ref[any] = Ref(),
        fProject: str = "all",
        fAssignee: str = "All",
        fCategory: str = "All",
        hideDone: bool = False,
        dialogOpen: bool = False,
        editingId: str = "",
        form: dict[str, str] = BLANK_TASK,
        fAssignees: list[str] = [],
        moveTaskId: str = "",
        moveTaskTitle: str = "",
        moveStatus: str = "",
        moveKind: str = "handoff",
        mForm: dict[str, str] = BLANK_MOVE,
        saving: bool = False,
        # A /board?task=<id> deep link (the overview's attention list, the
        # palette) opens that card once the first load has landed; "new"
        # opens the create dialog (/board?new=1).
        pendingTaskId: str = "";

    async can with entry {
        movesRef.current = 0;
        stored = localStorage.getItem("standup_project") or "";
        if stored {
            fProject = stored;
        }
        storedView = localStorage.getItem("standup_board_view") or "";
        if storedView == "columns" or storedView == "lanes" {
            boardView = storedView;
        }
        w: any = window;
        params: any = new(w.URLSearchParams, w.location.search);
        wanted = params.get("task") or "";
        if wanted {
            pendingTaskId = str(wanted);
        }
        if params.get("new") {
            pendingTaskId = "new";
        }
        boot();
    }

    # Runs from the render that has the loaded tasks and steps, so openEdit
    # sees fresh state (reading `tasks` right after `await loadAll()` in boot
    # would see the pre-load snapshot).
    useEffect(
        lambda { if pendingTaskId and not loading {
            if pendingTaskId == "new" {
                openCreate("");
            } else {
                for t in tasks {
                    if t.id == pendingTaskId {
                        openEdit(t);
                    }
                }
            }
            pendingTaskId = "";
            # Consume the param only now: on a full load the page mounts
            # twice (bare, then inside the chrome once login resolves), and
            # the second mount must still find it. Stripping it here also
            # keeps a reload or the poll from reopening the card.
            w: any = window;
            if w.location.search {
                w.history.replaceState(None, "", w.location.pathname);
            }
        }},
        [pendingTaskId, loading, len(tasks)]
    );

    # Live-ish board: refetch on tab focus plus a 60s poll. One manual
    # useEffect so the listener/interval handles are visible to the cleanup
    # (entry/exit abilities compile to separate closures).
    useEffect(
        lambda {
            onFocus = lambda { loadAll(); };
            window.addEventListener("focus", onFocus);
            # The assistant dock lives in the layout, not in this tree, so an
            # applied proposal announces itself with an event rather than leaving
            # the new card invisible until the next poll.
            window.addEventListener("standup:refresh", onFocus);
            # The command palette, mounted in the layout, asks an already
            # mounted board to open a card or the new-task dialog.
            onOpenTask = lambda (e: any) { pendingTaskId = str(e.detail or ""); };
            onNewTask = lambda { pendingTaskId = "new"; };
            window.addEventListener("standup:open-task", onOpenTask);
            window.addEventListener("standup:new-task", onNewTask);
            timer = window.setInterval(lambda { loadAll(); }, 60000);
            return lambda {
                window.removeEventListener("focus", onFocus);
                window.removeEventListener("standup:refresh", onFocus);
                window.removeEventListener("standup:open-task", onOpenTask);
                window.removeEventListener("standup:new-task", onNewTask);
                window.clearInterval(timer);
            };
        },
        []
    );

    async def boot -> None;
    async def loadAll -> None;
    async def saveTask -> None;
    async def deleteTask -> None;
    # The columns ARE the workflow, so every column question routes through
    # these rather than a status literal. Page methods, not module defs,
    # because they all read `steps`.
    def columnKeys -> list[str];
    def columnLabel(key: str) -> str;
    def columnKind(key: str) -> str;
    def columnColor(key: str) -> str;
    def columnKeyOf(t: TaskView) -> str;
    def mappedStatus(key: str) -> str;
    def doneColumnKey -> str;
    async def moveTo(taskId: str, columnKey: str) -> None;
    def arrowMove(t: TaskView, columnKey: str) -> None;
    def setProjectFilter(v: str) -> None;
    def setField(key: str, value: str) -> None;
    def setMoveField(key: str, value: str) -> None;
    def toggleAssignee(memberId: str) -> None;
    async def saveMoveInfo -> None;
    # Empty inKey lands the task in the first column.
    def openCreate(inKey: str = "") -> None;
    def pickBoardView(v: str) -> None;
    def openEdit(t: TaskView) -> None;
    async def syncGithub -> None;
    async def createIssue(repoId: str) -> None;
    def markDoneFromPr(taskId: str) -> None;

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
    # Categories are whatever the org has actually typed on its tasks.
    allCategories: list[str] = [];
    for t in tasks {
        if t.category and t.category not in allCategories {
            allCategories.append(t.category);
        }
    }
    allCategories.sort();

    colKeys = columnKeys();
    doneKey = doneColumnKey();
    today = todayIso();
    # No workflow AND nothing to show: six empty placeholder columns are noise
    # on a workspace that has not decided what its columns are yet. A legacy
    # org that HAS tasks still gets the fallback columns, because hiding the
    # board would hide its work.
    noWorkflow = len(steps) == 0 and len(tasks) == 0;

    visible = [
        t
        for t in tasks
        if (fProject == "all" or t.project_id == fProject)
        and (fAssignee == "All" or fAssignee in t.assignee_ids)
        and (fCategory == "All" or t.category == fCategory)
        and (not hideDone or t.status != "Done")
    ];
    weekAgoDate = new(Date);
    weekAgoDate.setDate(weekAgoDate.getDate() - 7);
    weekAgo = weekAgoDate.toISOString()[:10];
    doneVisible = [
        t
        for t in visible
        if doneKey and columnKeyOf(t) == doneKey
    ];
    recentDone = [
        t
        for t in doneVisible
        if t.updated_at[:10] >= weekAgo
    ];
    olderDoneCount = len(doneVisible) - len(recentDone);
    # Swimlanes need real steps (a legacy status board has no owners).
    laneMode = boardView == "lanes" and len(steps) > 0;
    laneColumns: list[dict[str, str]] = [];
    laneBands: list[dict[str, str]] = [];
    tasksByKey: dict[str, list[TaskView]] = {};
    overdueByKey: dict[str, int] = {};
    if laneMode {
        plan: dict[str, any] = laneLayout(steps, roles, activeMembers);
        laneOf: dict[str, str] = plan["laneOf"];
        for key in colKeys {
            laneColumns.append(
                {
                    "key": key,
                    "label": columnLabel(key),
                    "kind": columnKind(key),
                    "color": columnColor(key),
                    "lane": laneOf[key] if key in laneOf else "__unowned"
                }
            );
            tasksByKey[key] = (
                (doneVisible if showAllDone else recentDone)
                    if key == doneKey
                    else [
                        t
                        for t in visible
                        if columnKeyOf(t) == key
                    ]
            );
            overdueByKey[key] = 0
                if key == doneKey
                else len(
                    [
                        t
                        for t in tasksByKey[key]
                        if dueTone(t.due_date, t.status, today) == "overdue"
                    ]
                );
        }
        rawLanes: list[dict[str, any]] = plan["lanes"];
        for ln in rawLanes {
            lkey = str(ln["key"]);
            # Totals from what is on screen, not the server's unfiltered
            # task_count, so they follow the filters like the headers do.
            nSteps = 0;
            nTasks = 0;
            for c in laneColumns {
                if c["lane"] == lkey {
                    nSteps = nSteps + 1;
                    nTasks = nTasks + len(tasksByKey[c["key"]]);
                }
            }
            laneBands.append(
                {
                    "key": lkey,
                    "label": str(ln["label"]),
                    "sub": str(ln["sub"]),
                    "warn": "y" if ln["warn"] else "",
                    "color": str(ln["color"]),
                    "totals": str(nSteps) + (" step" if nSteps == 1 else " steps") + " · " + str(
                        nTasks
                    ) + (" task" if nTasks == 1 else " tasks")
                }
            );
        }
    }
    # The dialog hides its create-issue button once a task carries an issue,
    # so the number comes from server truth rather than the form dict.
    editingIssueNumber = 0;
    for t in tasks {
        if t.id == editingId {
            editingIssueNumber = t.gh_issue_number;
        }
    }

    return
        <div className="space-y-4">
            <div className="flex flex-wrap items-center justify-between gap-3">
                <h1 className="page-title">Board</h1>
                {if loading {
                    <div key="tools-skel" className="flex flex-wrap items-center gap-2">
                        <Skeleton className="h-8 w-44"/>
                        <Skeleton className="h-8 w-40"/>
                        <Skeleton className="h-8 w-40"/>
                        <Skeleton className="h-8 w-24"/>
                        <Skeleton className="h-8 w-24"/>
                    </div>
                } elif not noWorkflow {
                    <div key="tools" className="flex items-center gap-2">
                        <FilterBar
                            projects={activeProjects}
                            members={activeMembers}
                            project={fProject}
                            assignee={fAssignee}
                            category={fCategory}
                            hideDone={hideDone}
                            onProject={setProjectFilter}
                            onAssignee={lambda (v: str) { fAssignee = v; }}
                            onCategory={lambda (v: str) { fCategory = v; }}
                            onHideDone={lambda { hideDone = not hideDone; }}
                            categories={allCategories}
                        />
                        {if ghConnected {
                            <Button
                                key="sync"
                                variant="outline"
                                disabled={syncing}
                                onClick={syncGithub}
                            >
                                {if syncing {
                                    <Spinner key="sp"/>
                                }}
                                {"Syncing…" if syncing else "Sync GitHub"}
                            </Button>
                        }}
                        {if len(steps) > 0 {
                            <div
                                key="view"
                                className="inline-flex items-center gap-0.5 rounded-lg border border-border/70 bg-muted p-0.5"
                                role="group"
                                aria-label="Board layout"
                            >
                                <button
                                    type="button"
                                    aria-pressed={boardView == "lanes"}
                                    className={"rounded-md bg-background px-2.5 py-1 text-sm font-medium text-foreground shadow-sm"
                                        if boardView == "lanes"
                                        else "rounded-md px-2.5 py-1 text-sm font-medium text-muted-foreground transition-colors hover:text-foreground"}
                                    onClick={lambda { pickBoardView("lanes"); }}
                                >
                                    Lanes
                                </button>
                                <button
                                    type="button"
                                    aria-pressed={boardView == "columns"}
                                    className={"rounded-md bg-background px-2.5 py-1 text-sm font-medium text-foreground shadow-sm"
                                        if boardView == "columns"
                                        else "rounded-md px-2.5 py-1 text-sm font-medium text-muted-foreground transition-colors hover:text-foreground"}
                                    onClick={lambda { pickBoardView("columns"); }}
                                >
                                    Columns
                                </button>
                            </div>
                        }}
                        <Button onClick={lambda { openCreate(""); }}>New task</Button>
                    </div>
                } }
            </div>
            {if loading {
                # Mirrors the loaded board: one row of column shells, each
                # with a header (dot, label bar, count pill) and card blocks,
                # so data landing swaps content without reflow.
                <div
                    key="skeletons"
                    className="grid snap-x snap-mandatory items-start gap-3 overflow-x-auto px-0.5 pt-1 pb-3 md:items-stretch [--lane-h:calc(100dvh-12.5rem)]"
                    style={{"gridTemplateColumns": "repeat(5, minmax(17rem, 20rem))"}}
                >
                    {for i in [0, 1, 2, 3, 4] {
                        <div
                            key={"sk" + str(i)}
                            className="flex min-h-44 w-full min-w-0 snap-start flex-col gap-2 rounded-xl border bg-muted/30 p-2 md:h-[var(--lane-h)]"
                        >
                            <div
                                className="flex items-center justify-between px-1 py-1"
                            >
                                <div className="flex items-center gap-1.5">
                                    <Skeleton className="size-2 rounded-full"/>
                                    <Skeleton className="h-4 w-20"/>
                                </div>
                                <Skeleton className="h-5 w-6 rounded-full"/>
                            </div>
                            <Skeleton className="h-20 w-full"/>
                            <Skeleton className="h-20 w-full"/>
                            {if i % 2 == 0 {
                                <Skeleton key="c3" className="h-20 w-full"/>
                            }}
                        </div>
                    }}
                </div>
            } elif noWorkflow {
                <div
                    key="noworkflow"
                    className="relative flex flex-col items-center gap-3 overflow-hidden rounded-xl border border-dashed px-6 py-16 text-center"
                >
                    <KineticGrid
                        className="[mask-image:linear-gradient(to_bottom,black_55%,transparent)]"
                    />
                    <div
                        className="anim-fade-up relative z-10 flex flex-col items-center gap-3"
                    >
                        <svg
                            width={40}
                            height={40}
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth={1.5}
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            className="text-muted-foreground/70"
                        >
                            <circle cx={5} cy={12} r={2.5}/>
                            <circle cx={19} cy={5} r={2.5}/>
                            <circle cx={19} cy={19} r={2.5}/>
                            <path d="m7.3 10.8 9.4-4.6"/>
                            <path d="m7.3 13.2 9.4 4.6"/>
                        </svg>
                        <h2 className="font-display text-lg font-semibold">
                            Your board is the workflow you design
                        </h2>
                        <p
                            className="max-w-md text-sm text-pretty text-muted-foreground"
                        >
                            Name the steps your team actually uses and connect them however work moves. The columns here follow, so the two can never disagree.
                        </p>
                        <Button
                            onClick={lambda { window.location.href = "/workflow"; }}
                        >
                            Design your workflow
                            <svg
                                width={16}
                                height={16}
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
                        </Button>
                    </div>
                </div>
            } elif laneMode {
                <div key="swimlanes" className="[--lane-h:calc(100dvh-12.5rem)]">
                    <SwimlaneBoard
                        columns={laneColumns}
                        lanes={laneBands}
                        tasksByKey={tasksByKey}
                        overdueByKey={overdueByKey}
                        onOpen={openEdit}
                        onArrowMove={arrowMove}
                        onDropTask={moveTo}
                        onAddTask={openCreate}
                        doneKey={doneKey}
                        doneExtra={olderDoneCount if not showAllDone else 0}
                        showingAllDone={showAllDone}
                        onToggleOlder={lambda { showAllDone = not showAllDone; }}
                    />
                </div>
            } else {
                # Columns view: one vertical lane per step, viewport-high on
                # md+, the row scrolling sideways at every width.
                <div
                    key="columns"
                    className="grid snap-x snap-mandatory items-start gap-3 overflow-x-auto px-0.5 pt-1 pb-3 md:items-stretch [--lane-h:calc(100dvh-12.5rem)]"
                    style={{
                        "gridTemplateColumns": "repeat(" + str(len(colKeys)) + ", minmax(17rem, 20rem))"
                    }}
                >
                    {for (ci, key) in enumerate(colKeys) {
                        <KanbanColumn
                            key={key}
                            columnKey={key}
                            label={columnLabel(key)}
                            kind={columnKind(key)}
                            color={columnColor(key)}
                            tasks={(doneVisible if showAllDone else recentDone)
                                if key == doneKey
                                else [
                                    t
                                    for t in visible
                                    if columnKeyOf(t) == key
                                ]}
                            onOpen={openEdit}
                            onArrowMove={arrowMove}
                            onDropTask={moveTo}
                            prevKey={colKeys[ci - 1] if ci > 0 else ""}
                            prevLabel={columnLabel(colKeys[ci - 1]) if ci > 0 else ""}
                            nextKey={colKeys[ci + 1] if ci < len(colKeys) - 1 else ""}
                            nextLabel={columnLabel(colKeys[ci + 1])
                                if ci < len(colKeys) - 1
                                else ""}
                            doneKey={doneKey}
                            extraCount={olderDoneCount
                                if key == doneKey and not showAllDone
                                else 0}
                            showingAll={showAllDone if key == doneKey else False}
                            onToggleOlder={lambda { showAllDone = not showAllDone; }}
                            onAddTask={openCreate}
                            overdueCount={0
                                if key == doneKey
                                else len(
                                    [
                                        t
                                        for t in visible
                                        if columnKeyOf(t) == key
                                        and dueTone(t.due_date, t.status, today) == "overdue"
                                    ]
                                )}
                        />
                    }}
                </div>
            }   }
            <TaskDialog
                open={dialogOpen}
                editing={bool(editingId)}
                form={form}
                projects={activeProjects}
                members={activeMembers}
                saving={saving}
                onField={setField}
                onOpenChange={lambda (o: bool) { dialogOpen = o; }}
                onSave={saveTask}
                onDelete={deleteTask}
                categories={allCategories}
                columnKeys={colKeys}
                columnLabels={[columnLabel(k) for k in colKeys]}
                handoffKeys={[
                    k
                    for k in colKeys
                    if columnKind(k) in HANDOFF_KINDS
                ]}
                assignees={fAssignees}
                onToggleAssignee={toggleAssignee}
                repos={repos}
                ghConnected={ghConnected}
                ghIssueNumber={editingIssueNumber}
                onCreateIssue={createIssue}
            />
            <MoveDialog
                open={bool(moveTaskId)}
                status={moveStatus}
                kind={moveKind}
                taskTitle={moveTaskTitle}
                members={activeMembers}
                form={mForm}
                saving={saving}
                onField={setMoveField}
                onOpenChange={lambda (o: bool) { if not o { moveTaskId = ""; }}}
                onSave={saveMoveInfo}
            />
        </div>;
}
