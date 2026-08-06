"""standup - Board page (/board): the org's workflow as a kanban.

The columns ARE the workflow steps, in the order they were designed, so the
board and the Workflow tab can never disagree. An org that has not designed
one yet falls back to the classic six statuses.

Stateful shell: owns the data and every handler (bodies in the impl annex);
the columns, cards, filters, and dialog are presentational components.
"""

import from ...models { Project, MemberView, TaskView, StepView, RepoView }
# The one client import of constants.jac. Beyond sharing the status/kind
# mapping with the server, it is what makes the Jac compiler emit
# constants.js at all: the client compiles lazily, so a module nothing
# imports produces no output and the design-sync bundle barrel cannot
# resolve it.
import from ...constants { STATUSES, STATUS_KIND, KIND_STATUS }

import from ...walkers.projects { ListProjects, AssignToProject }
import from ...walkers.roster { ListMembers, ListRepos }
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
import from ...components.board.FilterBar { FilterBar }
import from ...components.board.KanbanColumn { KanbanColumn }
import from ...components.board.TaskDialog { TaskDialog }
import from ...components.board.MoveDialog { MoveDialog }
import from ...components.ui.button { Button }
import from ...components.ui.skeleton { Skeleton }
import from "sonner" { toast }
import from "react" { useEffect }

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
        repos: list[RepoView] = [],
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
        saving: bool = False;

    async can with entry {
        movesRef.current = 0;
        stored = localStorage.getItem("standup_project") or "";
        if stored {
            fProject = stored;
        }
        boot();
    }

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
            timer = window.setInterval(lambda { loadAll(); }, 60000);
            return lambda {
                window.removeEventListener("focus", onFocus);
                window.removeEventListener("standup:refresh", onFocus);
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
    def openCreate -> None;
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
                <h1 className="font-display text-2xl font-bold tracking-tight">
                    Board
                </h1>
                <div className="flex items-center gap-2">
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
                            Sync GitHub
                        </Button>
                    }}
                    <Button onClick={openCreate}>New task</Button>
                </div>
            </div>
            {if loading {
                <div
                    key="skeletons"
                    className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-6"
                >
                    <Skeleton key="s1" className="h-72 w-full"/>
                    <Skeleton key="s2" className="h-72 w-full"/>
                    <Skeleton key="s3" className="h-72 w-full"/>
                </div>
            } else {
                # Fluid grid: however many columns the workflow has, they share
                # the viewport width and wrap into rows when they stop fitting.
                # No horizontal scrollbar at any width or column count.
                <div
                    key="columns"
                    className="grid items-start justify-start gap-3"
                    style={{
                        "gridTemplateColumns": "repeat(auto-fit, minmax(min(11rem, 100%), 22rem))"
                    }}
                >
                    {for (ci, key) in enumerate(colKeys) {
                        <KanbanColumn
                            key={key}
                            columnKey={key}
                            label={columnLabel(key)}
                            kind={columnKind(key)}
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
                        />
                    }}
                </div>
            } }
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
