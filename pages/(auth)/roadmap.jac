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
    SetTaskMilestone, LinkSteps, UnlinkSteps
}
import from ...components.roadmap.Timeline { Timeline }
import from ...components.roadmap.Flow { Flow }
import from ...components.roadmap.StepInspector { StepInspector }
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

# The canvas is direct-manipulation and nothing about it is discoverable from
# looking, so the panel says plainly what the two drags do.
glob HOW_TO: list[list[str]] = [
    ["New step",
     "adds it to the tray under the canvas. Nothing is on the graph until it has an arrow."],
    ["Drag from a step's border",
     "onto another step to draw the arrow; the cursor turns to a crosshair when you are on it. Illegal targets dim as soon as you start."],
    ["Drag from the middle",
     "to move a step instead. It snaps to the next row or lane and swaps with whatever is there. Reset layout hands the arrangement back to the arrows."],
    ["Release on empty canvas",
     "to keep aiming, then click the target; that is how a tray step joins the graph. Click an arrow for its remove chip."]
];

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
        attachIds: list[str] = [],
        view: str = "flow",
        selectedId: str = "",
        connectFrom: str = "",
        selectedEdge: str = "",
        # A dragged step overrides its computed cell for this session only.
        # Nothing is persisted: reload, or Reset layout, and the arrows decide
        # again. That is deliberate, a stored position outlives the graph it
        # described and then contradicts it.
        manual: dict[str, list[int]] = {},
        # len() on a dict compiles to `.length`, which is undefined on a plain
        # JS object, so `len(manual) > 0` is silently always false. Track it.
        hasManual: bool = False,
        dragRef: Ref[any] = Ref(),
        wireRef: Ref[any] = Ref(),
        swallowRef: Ref[any] = Ref(),
        stepsRef: Ref[any] = Ref(),
        manualRef: Ref[any] = Ref();

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
    def selectStep(stepId: str) -> None;
    def armConnect -> None;
    def clearCanvas -> None;
    async def deleteEdge(fromId: str, toId: str) -> None;
    async def linkSteps(fromId: str, toId: str) -> None;
    def hitNode(e: MouseEvent) -> dict[str, any];
    def beginDrag(e: MouseEvent) -> None;
    def moveDrag(e: MouseEvent) -> None;
    async def endDrag(e: MouseEvent) -> None;
    def resetLayout -> None;

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
    # Single-element lists rather than a nullable: indexing a typed list
    # yields the element type, so no narrowing is needed inside a JSX slot.
    picked = [m for m in milestones if m.id == selectedId];
    sourced = [m for m in milestones if m.id == connectFrom];
    connectTitle = sourced[0].title if sourced else "";
    readyCount = 0;
    doneCount = 0;
    for m in milestones {
        if m.ready {
            readyCount = readyCount + 1;
        }
        if m.status == "Done" {
            doneCount = doneCount + 1;
        }
    }
    # Targets an arrow may not point at: itself, anything it already leads to,
    # and any ancestor (which would close a loop). The server refuses these
    # anyway; dimming them here just makes a bad connection hard to attempt.
    blockedTargets: list[str] = [];
    if connectFrom {
        byId: dict[str, MilestoneView] = {};
        for m in milestones {
            byId[m.id] = m;
        }
        blockedTargets = [connectFrom];
        if connectFrom in byId {
            for nid in byId[connectFrom].next_ids {
                if nid not in blockedTargets {
                    blockedTargets.append(nid);
                }
            }
        }
        frontier = [connectFrom];
        at = 0;
        while at < len(frontier) {
            current = frontier[at];
            at = at + 1;
            if current not in byId {
                continue;
            }
            for pid in byId[current].prev_ids {
                if pid not in blockedTargets {
                    blockedTargets.append(pid);
                    frontier.append(pid);
                }
            }
        }
    }

    # Flow applies the drag overrides itself; client code cannot construct a
    # MilestoneView, so the page passes the map rather than a rebuilt list.
    stepsRef.current = milestones;
    manualRef.current = manual;
    connectTitle = sourced[0].title if sourced else "";

    return <div className="mx-auto flex max-w-6xl flex-col gap-8">
        <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
                <h1 className="font-display text-3xl font-semibold tracking-tight">Roadmap</h1>
                <p className="text-sm text-muted-foreground">
                    Every step of this project, what each one waits on, and what it
                    unblocks.
                </p>
            </div>
            <div className="flex shrink-0 items-center gap-2">
                {if hasManual {
                    <Button key="reset" variant="ghost" onClick={resetLayout}>
                        Reset layout
                    </Button>
                }}
                <div className="flex items-center rounded-lg border p-0.5">
                    <Button
                        variant={"secondary" if view == "flow" else "ghost"}
                        size="sm"
                        onClick={lambda { view = "flow"; }}
                    >
                        Flow
                    </Button>
                    <Button
                        variant={"secondary" if view == "timeline" else "ghost"}
                        size="sm"
                        onClick={lambda { view = "timeline"; }}
                    >
                        Timeline
                    </Button>
                </div>
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
                <Button onClick={openCreate} disabled={not projectId}>New step</Button>
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
                {if view == "flow" {
                    <div key="flow" className="flex flex-col gap-4">
                        <div className="hidden">
                            <span>
                                {
                                    str(len(milestones)) + " steps · " + str(doneCount)
                                    + " done · " + str(readyCount) + " ready"
                                }
                            </span>
                        </div>

                        {if connectFrom {
                            <div
                                key="connecting"
                                className="flex items-center justify-between gap-4 rounded-lg border border-dashed bg-muted p-3"
                            >
                                <p className="text-sm text-pretty">
                                    <span className="font-medium">
                                        {"Drawing an arrow out of " + connectTitle + "."}
                                    </span>
                                    <span className="text-muted-foreground">
                                        {" Click the step it leads to — anything that would "
                                            + "loop back on itself is dimmed. Dragging is off "
                                            + "until this is done."}
                                    </span>
                                </p>
                                <Button
                                    size="sm"
                                    variant="ghost"
                                    onClick={lambda { connectFrom = ""; }}
                                >
                                    Cancel
                                </Button>
                            </div>
                        }}

                        <div
                            className="grid items-start gap-6"
                            style={{"gridTemplateColumns": "minmax(0,1fr) 21rem"}}
                        >
                            <div
                                onMouseDown={beginDrag}
                                onMouseMove={moveDrag}
                                onMouseUp={endDrag}
                                onMouseLeave={endDrag}
                            >
                                <Flow
                                    steps={milestones}
                                    overrides={manual}
                                    selectedId={selectedId}
                                    connectFrom={connectFrom}
                                    selectedEdge={selectedEdge}
                                    blockedTargets={blockedTargets}
                                    onSelect={selectStep}
                                    onSelectEdge={lambda (k: str) { selectedEdge = k; }}
                                    onDeleteEdge={deleteEdge}
                                    onCanvasClick={clearCanvas}
                                />
                            </div>
                            <div className="flex flex-col gap-4">
                                {if len(picked) > 0 {
                                    <StepInspector
                                        key={picked[0].id}
                                        step={picked[0]}
                                        tasks={[t for t in tasks if t.milestone_id == picked[0].id]}
                                        incoming={[m for m in milestones if m.id in picked[0].prev_ids]}
                                        outgoing={[m for m in milestones if m.id in picked[0].next_ids]}
                                        connecting={bool(connectFrom)}
                                        onConnect={armConnect}
                                        onCancelConnect={lambda { connectFrom = ""; }}
                                        onEdit={openEdit}
                                        onAttach={openAttach}
                                        onDetach={detachTask}
                                        onUnlink={deleteEdge}
                                    />
                                } else {
                                    <div key="hint" className="rounded-lg border border-dashed p-6">
                                        <p className="text-sm font-medium">Nothing selected</p>
                                        <p className="mt-1 text-sm text-pretty text-muted-foreground">
                                            Click a step on the canvas to see what it waits on,
                                            what it unblocks, and the tasks hanging off it.
                                        </p>
                                    </div>
                                }}
                                <div className="flex flex-col gap-3 rounded-lg border bg-card p-4">
                                    <h2 className="font-display text-sm font-semibold">
                                        Building the graph
                                    </h2>
                                    <div className="flex flex-col gap-2">
                                        {for (i, line) in enumerate(HOW_TO) {
                                            <div key={str(i)} className="flex items-baseline gap-2">
                                                <span className="text-xs font-medium tabular-nums text-muted-foreground">
                                                    {str(i + 1)}
                                                </span>
                                                <p className="text-xs text-pretty text-muted-foreground">
                                                    <span className="font-medium text-foreground">
                                                        {line[0]}
                                                    </span>
                                                    {" " + line[1]}
                                                </p>
                                            </div>
                                        }}
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                } else {
                    <div key="tl" className="space-y-8">
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
