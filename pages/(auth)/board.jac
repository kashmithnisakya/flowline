"""standup - Board page (/board): the 6-column kanban, scoped by project.

Stateful shell: owns the data and every handler (bodies in index.impl.jac);
the columns, cards, filters, and dialog are presentational components.
"""

import from ...models {
    Project, MemberView, TaskView, MilestoneView, RepoView
}

glob STATUSES: list[str] = [
    "Backlog", "In Progress", "Review", "Changes Requested", "Done", "Blocked"
];
import from ...walkers.projects { ListProjects, AssignToProject }
import from ...walkers.roster { ListMembers, ListRepos }
import from ...walkers.vocab { ListVocab }
import from ...models { VocabTerm }
import from ...walkers.tasks {
    ListTasks, CreateTask, UpdateTask, MoveTask, SetMoveInfo, DeleteTask
}
import from ...walkers.roadmap { ListMilestones, SetTaskMilestone }
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
    "title": "", "category": "", "project": "none", "milestone": "none",
    "priority": "Medium", "status": "Backlog", "due_date": "", "notes": "",
    "issue": "", "pr": "", "reviewer": "none", "review_due": ""
};

glob BLANK_MOVE: dict[str, str] = {
    "reviewer": "none", "review_due": "", "pr": "", "note": ""
};

# Statuses whose moves open the optional handoff dialog.
glob HANDOFF_STATUSES: list[str] = ["Review", "Blocked", "Changes Requested"];

def:pub BoardPage() -> JsxPage {
    has showAllDone: bool = False,
        vocab: list[VocabTerm] = [],
        tasks: list[TaskView] = [],
        members: list[MemberView] = [],
        projects: list[Project] = [],
        milestones: list[MilestoneView] = [],
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
    useEffect(lambda {
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
    }, []);

    async def boot -> None;
    async def loadAll -> None;
    async def saveTask -> None;
    async def deleteTask -> None;
    async def moveTo(taskId: str, status: str) -> None;
    def arrowMove(t: TaskView, status: str) -> None;
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

    activeMembers = [m for m in members if m.active];
    activeProjects = [p for p in projects if p.active];
    allCategories = [t.value for t in vocab if t.kind == "category"];
    visible = [
        t for t in tasks
        if (fProject == "all" or t.project_id == fProject)
        and (fAssignee == "All" or fAssignee in t.assignee_ids)
        and (fCategory == "All" or t.category == fCategory)
        and (not hideDone or t.status != "Done")
    ];
    weekAgoDate = new(Date);
    weekAgoDate.setDate(weekAgoDate.getDate() - 7);
    weekAgo = weekAgoDate.toISOString()[:10];
    doneVisible = [t for t in visible if t.status == "Done"];
    recentDone = [t for t in doneVisible if t.updated_at[:10] >= weekAgo];
    olderDoneCount = len(doneVisible) - len(recentDone);
    # The dialog hides its create-issue button once a task carries an issue,
    # so the number comes from server truth rather than the form dict.
    editingIssueNumber = 0;
    for t in tasks {
        if t.id == editingId {
            editingIssueNumber = t.gh_issue_number;
        }
    }

    return <div className="space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
            <h1 className="font-display text-2xl font-bold tracking-tight">Board</h1>
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
            <div key="skeletons" className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-6">
                <Skeleton key="s1" className="h-72 w-full" />
                <Skeleton key="s2" className="h-72 w-full" />
                <Skeleton key="s3" className="h-72 w-full" />
            </div>
        } else {
            # Fluid grid: all six columns share the viewport width on xl, wrap
            # into rows below it. No horizontal scrollbar at any width.
            <div key="columns" className="grid grid-cols-2 items-start gap-3 md:grid-cols-3 xl:grid-cols-6">
                {for s in STATUSES {
                    <KanbanColumn
                        key={s}
                        status={s}
                        tasks={
                            (doneVisible if showAllDone else recentDone)
                            if s == "Done"
                            else [t for t in visible if t.status == s]
                        }
                        onOpen={openEdit}
                        onArrowMove={arrowMove}
                        onDropTask={moveTo}
                        extraCount={olderDoneCount if s == "Done" and not showAllDone else 0}
                        showingAll={showAllDone if s == "Done" else False}
                        onToggleOlder={lambda { showAllDone = not showAllDone; }}
                    />
                }}
            </div>
        }}

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
            assignees={fAssignees}
            onToggleAssignee={toggleAssignee}
            milestones={milestones}
            repos={repos}
            ghConnected={ghConnected}
            ghIssueNumber={editingIssueNumber}
            onCreateIssue={createIssue}
        />

        <MoveDialog
            open={bool(moveTaskId)}
            status={moveStatus}
            taskTitle={moveTaskTitle}
            members={activeMembers}
            form={mForm}
            saving={saving}
            onField={setMoveField}
            onOpenChange={lambda (o: bool) { if not o { moveTaskId = ""; } }}
            onSave={saveMoveInfo}
        />
    </div>;
}
