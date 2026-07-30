"""standup - Board page: the 6-column kanban.

Stateful shell: owns tasks/members/filters and every handler (bodies in
index.impl.jac). Moves are optimistic — state updates immediately, MoveTask
is spawned, and a failure rolls back and toasts.
"""

import from ..constants { STATUSES, TEAMS, CATEGORIES, PRIORITIES }
import from endpoints {
    Member, TaskView,
    ListTasks, ListMembers, CreateTask, UpdateTask, MoveTask, DeleteTask
}
import from ..components.FilterBar { FilterBar }
import from ..components.KanbanColumn { KanbanColumn }
import from ..components.ui.button { Button }
import from ..components.ui.dialog {
    Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter
}
import from ..components.ui.input { Input }
import from ..components.ui.label { Label }
import from ..components.ui.textarea { Textarea }
import from ..components.ui.select {
    Select, SelectTrigger, SelectValue, SelectContent, SelectItem
}
import from ..components.ui.skeleton { Skeleton }
import from "sonner" { toast }
import from "react" { useEffect }

def:pub BoardPage() -> JsxPage {
    has tasks: list[TaskView] = [],
        members: list[Member] = [],
        loading: bool = True,
        movesRef: Ref[any] = Ref(),
        fTeam: str = "All",
        fAssignee: str = "All",
        fCategory: str = "All",
        hideDone: bool = False,
        dialogOpen: bool = False,
        editingId: str = "",
        tTitle: str = "",
        tCategory: str = "",
        tTeam: str = "",
        tPriority: str = "",
        tStatus: str = "Backlog",
        tDueDate: str = "",
        tNotes: str = "",
        tAssignee: str = "none",
        saving: bool = False;

    async can with entry {
        # Team defaulting lives HERE, not in loadAll: the poll/focus effect
        # below holds the render-0 loadAll closure forever, so any init
        # gated on a has-flag inside loadAll would re-run on every tick
        # and snap the filter back.
        movesRef.current = 0;
        who = localStorage.getItem("standup_who") or "";
        if who {
            try {
                mResult = root spawn ListMembers();
                fetched = mResult.reports[0] if mResult.reports else [];
                for m in fetched {
                    if jid(m) == who {
                        fTeam = m.team;
                    }
                }
            } except Exception as e {
                who = "";
            }
        }
        loadAll();
    }

    # Live-ish board: refetch when the tab regains focus, plus a 60s poll.
    # One manual useEffect so the listener/interval handles are visible to
    # the cleanup (entry/exit abilities compile to separate closures).
    useEffect(lambda {
        onFocus = lambda { loadAll(); };
        window.addEventListener("focus", onFocus);
        timer = window.setInterval(lambda { loadAll(); }, 60000);
        return lambda {
            window.removeEventListener("focus", onFocus);
            window.clearInterval(timer);
        };
    }, []);

    async def loadAll -> None;
    async def saveTask -> None;
    async def deleteTask -> None;
    async def moveTo(taskId: str, status: str) -> None;
    def arrowMove(t: TaskView, status: str) -> None;
    def openCreate -> None;
    def openEdit(t: TaskView) -> None;

    activeMembers = [m for m in members if m.active];
    visible = [
        t for t in tasks
        if (fTeam == "All" or t.team == fTeam)
        and (fAssignee == "All" or t.assignee_id == fAssignee)
        and (fCategory == "All" or t.category == fCategory)
        and (not hideDone or t.status != "Done")
    ];

    <div className="space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
            <h1 className="text-2xl font-semibold tracking-tight">Board</h1>
            <div className="flex items-center gap-2">
                <FilterBar
                    members={activeMembers}
                    team={fTeam}
                    assignee={fAssignee}
                    category={fCategory}
                    hideDone={hideDone}
                    onTeam={lambda (v: str) { fTeam = v; }}
                    onAssignee={lambda (v: str) { fAssignee = v; }}
                    onCategory={lambda (v: str) { fCategory = v; }}
                    onHideDone={lambda { hideDone = not hideDone; }}
                />
                <Button onClick={openCreate}>New task</Button>
            </div>
        </div>

        {if loading {
            <div className="flex gap-3">
                <Skeleton key="s1" className="h-72 w-64" />
                <Skeleton key="s2" className="h-72 w-64" />
                <Skeleton key="s3" className="h-72 w-64" />
            </div>
        } else {
            <div className="flex items-start gap-3 overflow-x-auto pb-4">
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

        <Dialog open={dialogOpen} onOpenChange={lambda (o: bool) { dialogOpen = o; }}>
            <DialogContent className="sm:max-w-lg">
                <DialogHeader>
                    <DialogTitle>{"Edit task" if editingId else "New task"}</DialogTitle>
                </DialogHeader>
                <div className="grid gap-4 py-2">
                    <div className="grid gap-2">
                        <Label>Title</Label>
                        <Input
                            value={tTitle}
                            onChange={lambda (e: ChangeEvent) { tTitle = e.target.value; }}
                        />
                    </div>
                    <div className="grid grid-cols-2 gap-3">
                        <div className="grid gap-2">
                            <Label>Team</Label>
                            <Select value={tTeam} onValueChange={lambda (v: str) { tTeam = v; }}>
                                <SelectTrigger>
                                    <SelectValue placeholder="Team" />
                                </SelectTrigger>
                                <SelectContent>
                                    {for t in TEAMS {
                                        <SelectItem key={t} value={t}>{t}</SelectItem>
                                    }}
                                </SelectContent>
                            </Select>
                        </div>
                        <div className="grid gap-2">
                            <Label>Category</Label>
                            <Select value={tCategory} onValueChange={lambda (v: str) { tCategory = v; }}>
                                <SelectTrigger>
                                    <SelectValue placeholder="Category" />
                                </SelectTrigger>
                                <SelectContent>
                                    {for c in CATEGORIES {
                                        <SelectItem key={c} value={c}>{c}</SelectItem>
                                    }}
                                </SelectContent>
                            </Select>
                        </div>
                        <div className="grid gap-2">
                            <Label>Priority</Label>
                            <Select value={tPriority} onValueChange={lambda (v: str) { tPriority = v; }}>
                                <SelectTrigger>
                                    <SelectValue placeholder="Priority" />
                                </SelectTrigger>
                                <SelectContent>
                                    {for p in PRIORITIES {
                                        <SelectItem key={p} value={p}>{p}</SelectItem>
                                    }}
                                </SelectContent>
                            </Select>
                        </div>
                        <div className="grid gap-2">
                            <Label>Status</Label>
                            <Select value={tStatus} onValueChange={lambda (v: str) { tStatus = v; }}>
                                <SelectTrigger>
                                    <SelectValue placeholder="Status" />
                                </SelectTrigger>
                                <SelectContent>
                                    {for s in STATUSES {
                                        <SelectItem key={s} value={s}>{s}</SelectItem>
                                    }}
                                </SelectContent>
                            </Select>
                        </div>
                        <div className="grid gap-2">
                            <Label>Assignee</Label>
                            <Select value={tAssignee} onValueChange={lambda (v: str) { tAssignee = v; }}>
                                <SelectTrigger>
                                    <SelectValue placeholder="Assignee" />
                                </SelectTrigger>
                                <SelectContent>
                                    <SelectItem value="none">Unassigned</SelectItem>
                                    {for m in activeMembers {
                                        <SelectItem key={jid(m)} value={jid(m)}>{m.name}</SelectItem>
                                    }}
                                </SelectContent>
                            </Select>
                        </div>
                        <div className="grid gap-2">
                            <Label>Due date</Label>
                            <Input
                                type="date"
                                value={tDueDate}
                                onChange={lambda (e: ChangeEvent) { tDueDate = e.target.value; }}
                            />
                        </div>
                    </div>
                    <div className="grid gap-2">
                        <Label>Notes / blockers</Label>
                        <Textarea
                            value={tNotes}
                            onChange={lambda (e: ChangeEvent) { tNotes = e.target.value; }}
                        />
                    </div>
                </div>
                <DialogFooter className="gap-2 sm:justify-between">
                    {if editingId {
                        <Button variant="destructive" onClick={deleteTask} disabled={saving}>
                            Delete
                        </Button>
                    } else {
                        <span />
                    }}
                    <div className="flex gap-2">
                        <Button variant="outline" onClick={lambda { dialogOpen = False; }}>
                            Cancel
                        </Button>
                        <Button
                            onClick={saveTask}
                            disabled={saving or not tTitle.strip() or not tTeam}
                        >
                            Save
                        </Button>
                    </div>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    </div>
}
