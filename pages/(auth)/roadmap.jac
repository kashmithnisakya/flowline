"""standup - Roadmap page (/roadmap): where a project is heading.

Stateful shell: it owns every walker call and hands the timeline, the cards
and the two dialogs finished data. One project at a time, picked in the
header. The choice is deliberately not persisted, so the page always opens
on the workspace's first project rather than on a stale archived one.
"""

import from ...models { Project, MilestoneView, TaskView }
import from ...walkers.projects { ListProjects }
import from ...walkers.tasks { ListTasks }
import from ...walkers.roadmap {
    ListMilestones, SaveMilestone, DeleteMilestone, ReorderMilestone,
    SetTaskMilestone
}
import from ...components.roadmap.Timeline { Timeline }
import from ...components.roadmap.MilestoneCard { MilestoneCard }
import from ...components.roadmap.MilestoneDialog { MilestoneDialog }
import from ...components.roadmap.AttachTasksDialog { AttachTasksDialog }
import from ...components.ui.button { Button }
import from ...components.ui.card { Card, CardContent }
import from ...components.ui.skeleton { Skeleton }
import from ...components.ui.select {
    Select, SelectTrigger, SelectValue, SelectContent, SelectItem
}
import from "sonner" { toast }

glob BLANK_MILESTONE: dict[str, str] = {
    "title": "", "description": "", "start_date": "", "due_date": "",
    "status": "Planned", "color": "violet"
};

def localIso(d: any) -> str {
    shifted = new(Date, d.getTime() - d.getTimezoneOffset() * 60000);
    return shifted.toISOString()[:10];
}

# Position in the project's full ordering, which is what the reorder
# buttons act on even though the cards render in two sections.
def indexOf(ms: list[MilestoneView], milestoneId: str) -> int {
    at = -1;
    for (i, m) in enumerate(ms) {
        if m.id == milestoneId {
            at = i;
        }
    }
    return at;
}

def:pub RoadmapPage() -> JsxPage {
    has projects: list[Project] = [],
        milestones: list[MilestoneView] = [],
        tasks: list[TaskView] = [],
        loading: bool = True,
        projectId: str = "",
        dialogOpen: bool = False,
        editingId: str = "",
        form: dict[str, str] = BLANK_MILESTONE,
        confirmDelete: bool = False,
        saving: bool = False,
        attachOpen: bool = False,
        attachStoneId: str = "",
        attachIds: list[str] = [];

    async can with entry {
        boot();
    }

    async def boot -> None;
    async def loadAll(pid: str) -> None;
    async def selectProject(v: str) -> None;
    async def saveMilestone -> None;
    async def deleteMilestone -> None;
    async def moveMilestone(milestoneId: str, delta: int) -> None;
    async def confirmAttach -> None;
    async def detachTask(taskId: str) -> None;
    def setField(key: str, value: str) -> None;
    def openCreate -> None;
    def openEdit(m: MilestoneView) -> None;
    def openAttach(milestoneId: str) -> None;
    def toggleAttach(taskId: str) -> None;

    activeProjects = [p for p in projects if p.active];
    scheduled = [m for m in milestones if m.start_date or m.due_date];
    unscheduled = [m for m in milestones if not m.start_date and not m.due_date];
    attachable = [
        t for t in tasks
        if t.project_id == projectId and t.status != "Done" and not t.milestone_id
    ];
    attachTitle = "";
    for m in milestones {
        if m.id == attachStoneId {
            attachTitle = m.title;
        }
    }

    return <div className="space-y-8">
        <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
                <h1 className="font-display text-2xl font-bold tracking-tight">Roadmap</h1>
                <p className="text-sm text-muted-foreground">
                    The phases of one project, and how far each has got.
                </p>
            </div>
            <div className="flex items-center gap-2">
                <Select value={projectId} onValueChange={selectProject}>
                    <SelectTrigger className="h-9 w-52">
                        <SelectValue placeholder="Project" />
                    </SelectTrigger>
                    <SelectContent>
                        {for p in activeProjects {
                            <SelectItem key={jid(p)} value={jid(p)}>{p.name}</SelectItem>
                        }}
                    </SelectContent>
                </Select>
                <Button onClick={openCreate} disabled={not projectId}>New milestone</Button>
            </div>
        </div>

        {if loading {
            <div key="sk" className="space-y-4">
                <Skeleton key="s1" className="h-44 w-full" />
                <Skeleton key="s2" className="h-52 w-full" />
            </div>
        } elif len(milestones) == 0 {
            <Card key="empty">
                <CardContent className="space-y-3 py-12 text-center">
                    <h2 className="font-display text-lg font-semibold">No milestones yet</h2>
                    <p className="mx-auto max-w-md text-sm text-muted-foreground">
                        A milestone is a phase of this project: give it a name, an optional
                        start and target date, then pull tasks from the board into it. The
                        timeline then shows where each phase sits and how much of it is done.
                    </p>
                    <div>
                        <Button onClick={openCreate} disabled={not projectId}>
                            New milestone
                        </Button>
                    </div>
                </CardContent>
            </Card>
        } else {
            <div key="body" className="space-y-8">
                <Timeline milestones={milestones} today={localIso(new(Date))} />

                {if len(scheduled) > 0 {
                    <div key="sched" className="space-y-3">
                        <h2 className="font-display text-lg font-semibold">Scheduled</h2>
                        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
                            {for m in scheduled {
                                <MilestoneCard
                                    key={m.id}
                                    milestone={m}
                                    tasks={[t for t in tasks if t.milestone_id == m.id]}
                                    canMoveUp={indexOf(milestones, m.id) > 0}
                                    canMoveDown={indexOf(milestones, m.id) < len(milestones) - 1}
                                    onEdit={openEdit}
                                    onMove={moveMilestone}
                                    onAttach={openAttach}
                                    onDetach={detachTask}
                                />
                            }}
                        </div>
                    </div>
                }}

                {if len(unscheduled) > 0 {
                    <div key="unsched" className="space-y-3">
                        <div>
                            <h2 className="font-display text-lg font-semibold">Unscheduled</h2>
                            <p className="text-sm text-muted-foreground">
                                No dates yet, so these stay off the timeline.
                            </p>
                        </div>
                        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
                            {for m in unscheduled {
                                <MilestoneCard
                                    key={m.id}
                                    milestone={m}
                                    tasks={[t for t in tasks if t.milestone_id == m.id]}
                                    canMoveUp={indexOf(milestones, m.id) > 0}
                                    canMoveDown={indexOf(milestones, m.id) < len(milestones) - 1}
                                    onEdit={openEdit}
                                    onMove={moveMilestone}
                                    onAttach={openAttach}
                                    onDetach={detachTask}
                                />
                            }}
                        </div>
                    </div>
                }}
            </div>
        }}

        <MilestoneDialog
            open={dialogOpen}
            editing={bool(editingId)}
            form={form}
            saving={saving}
            confirmingDelete={confirmDelete}
            onField={setField}
            onOpenChange={lambda (o: bool) {
                dialogOpen = o;
                if not o {
                    confirmDelete = False;
                }
            }}
            onSave={saveMilestone}
            onDelete={deleteMilestone}
        />

        <AttachTasksDialog
            open={attachOpen}
            milestoneTitle={attachTitle}
            tasks={attachable}
            selected={attachIds}
            saving={saving}
            onToggle={toggleAttach}
            onOpenChange={lambda (o: bool) {
                attachOpen = o;
                if not o {
                    attachStoneId = "";
                }
            }}
            onConfirm={confirmAttach}
        />
    </div>;
}
