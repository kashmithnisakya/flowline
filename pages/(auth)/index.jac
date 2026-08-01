"""standup - Board page: the 6-column kanban, scoped by project.

Stateful shell: owns the data and every handler (bodies in index.impl.jac);
the columns, cards, filters, and dialog are presentational components.
"""

import from ...constants { STATUSES }
import from ...models { Project, MemberView, TaskView }
import from ...walkers.projects { ListProjects }
import from ...walkers.roster { ListMembers }
import from ...walkers.tasks {
    ListTasks, CreateTask, UpdateTask, MoveTask, DeleteTask
}
import from ...components.board.FilterBar { FilterBar }
import from ...components.board.KanbanColumn { KanbanColumn }
import from ...components.board.TaskDialog { TaskDialog }
import from ...components.ui.button { Button }
import from ...components.ui.skeleton { Skeleton }
import from "sonner" { toast }
import from "react" { useEffect }

glob BLANK_TASK: dict[str, str] = {
    "title": "", "category": "", "project": "none", "priority": "Medium",
    "status": "Backlog", "due_date": "", "notes": "", "assignee": "none"
};

def:pub BoardPage() -> JsxPage {
    has tasks: list[TaskView] = [],
        members: list[MemberView] = [],
        projects: list[Project] = [],
        loading: bool = True,
        movesRef: Ref[any] = Ref(),
        fProject: str = "all",
        fAssignee: str = "All",
        fCategory: str = "All",
        hideDone: bool = False,
        dialogOpen: bool = False,
        editingId: str = "",
        form: dict[str, str] = BLANK_TASK,
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
        timer = window.setInterval(lambda { loadAll(); }, 60000);
        return lambda {
            window.removeEventListener("focus", onFocus);
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
    def openCreate -> None;
    def openEdit(t: TaskView) -> None;

    activeMembers = [m for m in members if m.active];
    activeProjects = [p for p in projects if p.active];
    visible = [
        t for t in tasks
        if (fProject == "all" or t.project_id == fProject)
        and (fAssignee == "All" or t.assignee_id == fAssignee)
        and (fCategory == "All" or t.category == fCategory)
        and (not hideDone or t.status != "Done")
    ];

    <div className="space-y-4">
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
                />
                <Button onClick={openCreate}>New task</Button>
            </div>
        </div>

        {if loading {
            <div key="skeletons" className="flex gap-3">
                <Skeleton key="s1" className="h-72 w-64" />
                <Skeleton key="s2" className="h-72 w-64" />
                <Skeleton key="s3" className="h-72 w-64" />
            </div>
        } else {
            <div key="columns" className="flex items-start gap-3 overflow-x-auto pb-4">
                {for s in STATUSES {
                    <KanbanColumn
                        key={s}
                        status={s}
                        tasks={[t for t in visible if t.status == s]}
                        onOpen={openEdit}
                        onArrowMove={arrowMove}
                        onDropTask={moveTo}
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
        />
    </div>
}
