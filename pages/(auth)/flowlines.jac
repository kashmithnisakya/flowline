"""standup - Flow line page (/flowlines): three faces of one graph, the template
picker, the designer, and a read-only diagram (Flow or Lanes). One flow line per
org, so no project selector. Validation is advisory and never blocks saving.
The editor floats OVER the canvas; keep notes out of JSX (a `#` there renders)."""

import from ...models { Project, StepView, TaskView, MemberView, RoleView }
import from ...constants { STEP_KINDS, KIND_COLORS, KIND_STATUS }
import from ...walkers.projects { ListProjects, AssignToProject }
import from ...walkers.tasks { UpdateTask, DeleteTask }
import from ...walkers.roster { ListMembers, ListRoles }
import from ...walkers.flowlines {
    GetFlowLine,
    ApplyTemplate,
    SaveStep,
    MoveStep,
    DeleteStep,
    DeleteFlowLine,
    LinkTransition,
    LabelTransition,
    UnlinkTransition,
    GetFlowLineMeta,
    RenameFlowLine,
    ListStepTasks
}
import from ...components.flowlines.FlowCanvas { FlowCanvas }
import from ...components.flowlines.lanes { laneLayout }
import from ...components.flowlines.TemplatePicker { TemplatePicker }
import from ...components.flowlines.StepInspector { StepInspector }
import from ...components.flowlines.StepTasksPanel { StepTasksPanel }
import from ...components.board.TaskDialog { TaskDialog }
import from ...components.flowlines.geometry {
    hitStep,
    stepXY,
    canvasSize,
    NODE_W,
    NODE_H
}
import from ...components.flowlines.kinds { KIND_LABEL, DOT_FILL, colorKey }
import from ...components.ui.button { Button }
import from ...components.ui.input { Input }
import from ...components.ui.skeleton { Skeleton }
import from ...components.ui.dialog {
    Dialog,
    DialogContent,
    DialogHeader,
    DialogTitle,
    DialogDescription,
    DialogFooter
}
import from ...components.ui.select {
    Select,
    SelectTrigger,
    SelectValue,
    SelectContent,
    SelectItem
}
import from "sonner" { toast }
import from "react" { useEffect, useLayoutEffect }
import from ...components.common.glyphs { Spinner, WarnIcon }

glob BLANK_STEP: dict[str, str] = {
         "name": "",
         "kind": "active",
         "color": "indigo"
     },
     # The board's task form, so the dialog opened from the panel is the
     # board's dialog with the board's fields, not a second shape of task.
     BLANK_TASK: dict[str, str] = {
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
     # Step kinds whose task dialog offers the reviewer fields, as on the board.
     HANDOFF_KINDS: list[str] = ["handoff", "blocked"];


def:pub FlowLinePage -> JsxPage {
    has steps: list[StepView] = [],
        projects: list[Project] = [],
        # The org's roles and roster, for the who-does-what strip the
        # viewer shows under the kind legend and the Lane view's labels.
        roleRows: list[RoleView] = [],
        roleMembers: list[MemberView] = [],
        # Viewer projection: "flow" renders the hand-drawn positions,
        # "lanes" a computed swimlane layout (lane = owner role, column =
        # flow depth). Persisted per browser; editing always uses flow.
        lineView: str = "flow",
        # Shared with the board through one localStorage key, so the project
        # you are looking at follows you between the two tabs.
        projectId: str = "all",
        loading: bool = True,
        editing: bool = False,
        scratch: bool = False,
        applying: str = "",
        lineName: str = "Flow line",
        renaming: bool = False,
        nameDraft: str = "",
        selectedId: str = "",
        connectFrom: str = "",
        selectedEdge: str = "",
        # What the selected transition's label says while it is being typed.
        # Re-seeded from the edge on every selection, so it never has to be
        # cleared when the selection moves.
        edgeDraft: str = "",
        form: dict[str, str] = BLANK_STEP,
        saving: bool = False,
        confirmDelete: bool = False,
        # Deleting the whole flow line confirms in a dialog, not by re-clicking:
        # it takes every step, so it spells out what goes and what stays first.
        confirmWipe: bool = False,
        wiping: bool = False,
        # Add step opens a naming panel first: the step only exists once the
        # user has called it something, never as a placeholder card.
        creatingStep: bool = False,
        # A dragged step's live position, canvas px, for this drag only. The
        # persisted x/y takes over again after MoveStep + reload.
        live: dict[str, list[float]] = {},
        # Clicking a step outside edit mode opens its work rather than
        # selecting it: the count says how much, this says what.
        peekId: str = "",
        peekTasks: list[TaskView] = [],
        peekLoading: bool = False,
        # A row in that panel opens the BOARD's task dialog, driven from
        # here: same form dict, same walkers, so the two never drift.
        taskOpen: bool = False,
        editTaskId: str = "",
        taskForm: dict[str, str] = BLANK_TASK,
        taskAssignees: list[str] = [],
        taskSaving: bool = False,
        # Zoom instead of scrollbars: the canvas never scrolls, it scales.
        zoom: float = 1.0,
        # Screen-px offset that centers the diagram in the viewport. Applied
        # before the scale on the canvas surface, so pointerXY's rect math
        # keeps working untouched.
        panX: float = 0.0,
        panY: float = 0.0,
        # Transitions stay off until one frame AFTER the first fit. fitZoom's
        # clientWidth read forces a style recalc at the unfitted transform, so
        # with transitions live the browser animates the correction even when
        # both commits land before first paint - the corner-to-center flight.
        placed: bool = False,
        busyRef: Ref[any] = Ref(),
        viewportRef: Ref[any] = Ref(),
        # Mirrors `zoom` for handlers: a render-time read would make two
        # quick clicks on the same button collapse into one step.
        zoomRef: Ref[any] = Ref(),
        dragRef: Ref[any] = Ref(),
        wireRef: Ref[any] = Ref(),
        swallowRef: Ref[any] = Ref(),
        stepsRef: Ref[any] = Ref(),
        liveRef: Ref[any] = Ref(),
        canvasRef: Ref[any] = Ref();

    async can with entry {
        boot();
    }

    # Fit whenever the visible area changes: first load, a widened graph,
    # entering edit mode (the editor covers the right third), a view flip.
    # A LAYOUT effect so the first frame is already fitted; a plain effect
    # would animate the correction and the diagram would visibly fly in.
    # The task panel covers the same right-hand strip the editor does, so
    # opening or closing it changes the space the diagram has to fit into.
    useLayoutEffect(lambda { fitZoom(); }, [len(steps), editing, lineView, peekId]);

    # Refit when the window itself changes size: the canvas tracks the
    # viewport height, so a resize moves the centering target.
    useEffect(
        lambda {
            onResize = lambda { fitZoom(); };
            window.addEventListener("resize", onResize);
            return lambda { window.removeEventListener("resize", onResize); };
        },
        []
    );

    # Esc closes the task panel, but an open dialog owns the key first. On the
    # CAPTURE phase and asking the DOM, because by the bubble phase Radix has
    # closed its dialog and flipped the state this would have keyed on: one
    # press would then close the panel too.
    useEffect(
        lambda {
            onKey = lambda (e: any) {
                if e.key != "Escape" or not peekId {
                    return;
                }
                w: any = window;
                if w.document.querySelector("[role=dialog][data-state=open]") {
                    return;
                }
                closePeek();
            };
            window.addEventListener("keydown", onKey, True);
            return lambda { window.removeEventListener("keydown", onKey, True); };
        },
        [peekId]
    );

    async def boot -> None;
    async def reload(pid: str) -> None;
    async def selectProject(v: str) -> None;
    async def peekStep(stepId: str) -> None;
    async def refreshPeek(stepId: str, pid: str) -> None;
    def closePeek -> None;
    def openTask(tid: str) -> None;
    def setTaskField(key: str, value: str) -> None;
    def toggleTaskAssignee(memberId: str) -> None;
    async def saveTask -> None;
    async def deleteTask -> None;
    def stepName(key: str) -> str;
    def mappedStatus(key: str) -> str;
    def dockWidth -> float;
    async def loadMeta -> None;
    def switchView(v: str) -> None;
    def lanePlan -> dict[str, any];
    def viewBounds -> list[float];
    async def pickTemplate(key: str) -> None;
    def startScratch -> None;
    def startRename -> None;
    async def saveRename -> None;
    def addStep -> None;
    async def commitName -> None;
    async def commitField(key: str, value: str) -> None;
    async def deleteStep -> None;
    async def deleteFlowLine -> None;
    async def linkSteps(fromId: str, toId: str) -> None;
    async def deleteEdge(fromId: str, toId: str) -> None;
    def selectEdge(key: str, said: str) -> None;
    async def commitEdgeLabel(fromId: str, toId: str, said: str) -> None;
    def selectStep(stepId: str) -> None;
    def armConnect -> None;
    def clearCanvas -> None;
    def setField(key: str, value: str) -> None;
    def zoomBy(delta: float) -> None;
    def fitZoom -> None;
    def recenterPan -> None;
    def pointerXY(e: MouseEvent) -> list[float];
    def beginDrag(e: MouseEvent) -> None;
    def moveDrag(e: MouseEvent) -> None;
    async def endDrag(e: MouseEvent) -> None;

    stepsRef.current = steps;
    liveRef.current = live;

    # Guarded with len() everywhere it is read: `peeked and ...` compiles to
    # a bare JS `&&`, and an empty array is truthy there.
    peeked = [
        s
        for s in steps
        if s.id == peekId
    ];
    activeProjects = [
        p
        for p in projects
        if p.active
    ];
    # The task dialog's assignee picker and reviewer list, from the roster
    # already loaded for the who-does-what strip.
    activeMembers = [
        m
        for m in roleMembers
        if m.active
    ];
    # Who holds each role, for the strip under the kind legend.
    roleHolders: dict[str, str] = {};
    for rr in roleRows {
        held: list[str] = [];
        for rm in roleMembers {
            if rm.active and rr.name in rm.roles {
                held.append(rm.name);
            }
        }
        roleHolders[rr.name] = ", ".join(held);
    }
    # The inspector's owner dropdown offers exactly the managed roles.
    ownerOptions: list[str] = [];
    for rr in roleRows {
        ownerOptions.append(rr.name);
    }
    # The Lane view projection: computed fresh per render, empty in flow
    # mode so the viewer's FlowCanvas call can pass these unconditionally.
    laneMode = lineView == "lanes";
    plan: dict[str, any] = {"positions": {}, "lanes": []};
    if laneMode and not editing {
        plan = laneLayout(steps, roleRows, roleMembers);
    }
    lanePose: dict[str, list[float]] = plan["positions"];
    laneBands: list[dict[str, any]] = plan["lanes"];
    laneOfStep: dict[str, str] = plan["laneOf"] if "laneOf" in plan else {};
    # Roles that own no step: they get no lane (an empty lane only pushes
    # content down), so they are named under the canvas instead.
    owners: list[str] = [];
    for s in steps {
        said = s.owner.strip() if s.owner else "";
        if said and said not in owners {
            owners.append(said);
        }
    }
    offFlow: list[str] = [];
    for rr in roleRows {
        if rr.name not in owners {
            offFlow.append(rr.name);
        }
    }
    taskTotal = 0;
    for s in steps {
        taskTotal = taskTotal + s.task_count;
    }

    # The panel obeys the project filter, so say which scope produced this
    # list. Without it a short list under a narrowed filter reads as missing
    # work rather than as work belonging to another project.
    peekScope = "across all projects";
    for p in activeProjects {
        if jid(p) == projectId {
            peekScope = "in " + p.name;
        }
    }
    # The task dialog offers exactly the steps the canvas shows, left to
    # right, which is the order the board builds its columns in too.
    stepOrder = [st for st in steps];
    stepOrder.sort(key=lambda (st: StepView) { st.sort_order; });
    stepOrder.sort(key=lambda (st: StepView) { st.x; });
    colKeys: list[str] = [];
    colLabels: list[str] = [];
    handoffKeys: list[str] = [];
    for st in stepOrder {
        colKeys.append(st.id);
        colLabels.append(st.name);
        if st.kind in HANDOFF_KINDS {
            handoffKeys.append(st.id);
        }
    }
    # Category suggestions from what is on this step; the board's full list
    # would cost a second fetch for a datalist.
    taskCategories: list[str] = [];
    for t in peekTasks {
        if t.category and t.category not in taskCategories {
            taskCategories.append(t.category);
        }
    }

    byId: dict[str, StepView] = {};
    for s in steps {
        byId[s.id] = s;
    }
    picked = [
        s
        for s in steps
        if s.id == selectedId
    ];
    sourced = [
        s
        for s in steps
        if s.id == connectFrom
    ];
    connectTitle = sourced[0].name if sourced else "";

    linkCount = 0;
    startCount = 0;
    doneCount = 0;
    for s in steps {
        if s.kind == "start" {
            startCount = startCount + 1;
        }
        if s.kind == "done" {
            doneCount = doneCount + 1;
        }
        for nid in s.next_ids {
            if nid in byId {
                linkCount = linkCount + 1;
            }
        }
    }

    # The delete dialog's tally, counted here so copy and diagram agree.
    stepNoun = "step" if len(steps) == 1 else "steps";
    linkNoun = "transition" if linkCount == 1 else "transitions";
    wipeSummary = (
        str(len(steps)) + " " + stepNoun + " and " + str(linkCount) + " " + linkNoun + " will be removed."
    );

    # Advisory checks. All plain BFS over the views already in hand.
    issues: list[str] = [];
    if len(steps) > 0 {
        if startCount == 0 {
            issues.append("No start step yet, mark where new work lands.");
        }
        if doneCount == 0 {
            issues.append("No done step yet, every flow needs a terminal step.");
        }
        if startCount > 0 {
            seen: dict[str, bool] = {};
            frontier: list[str] = [];
            for s in steps {
                if s.kind == "start" {
                    frontier.append(s.id);
                    seen[s.id] = True;
                }
            }
            at = 0;
            while at < len(frontier) {
                current = frontier[at];
                at = at + 1;
                for nid in byId[current].next_ids {
                    if nid in byId and nid not in seen {
                        seen[nid] = True;
                        frontier.append(nid);
                    }
                }
            }
            stranded = 0;
            for s in steps {
                if s.id not in seen {
                    stranded = stranded + 1;
                }
            }
            if stranded > 0 {
                issues.append(
                    str(stranded) + (" step has" if stranded == 1 else " steps have") + " no path from a start step."
                );
            }
        }
        if doneCount > 0 {
            reach: dict[str, bool] = {};
            backlog: list[str] = [];
            for s in steps {
                if s.kind == "done" {
                    backlog.append(s.id);
                    reach[s.id] = True;
                }
            }
            at2 = 0;
            while at2 < len(backlog) {
                current2 = backlog[at2];
                at2 = at2 + 1;
                for pid in byId[current2].prev_ids {
                    if pid in byId and pid not in reach {
                        reach[pid] = True;
                        backlog.append(pid);
                    }
                }
            }
            noPath = 0;
            for s in steps {
                if s.id not in reach {
                    noPath = noPath + 1;
                }
            }
            if noPath > 0 {
                issues.append(
                    str(noPath) + (" step has" if noPath == 1 else " steps have") + " no path to a done step."
                );
            }
        }
    }

    showPicker = not loading and len(steps) == 0 and not scratch;

    return
        <div className="flex w-full flex-col gap-6">
            {if loading or showPicker {
                <div key="head" className="flex flex-col gap-2">
                    <h1 className="page-title">Flow line</h1>
                    <p className="page-subtitle">
                        The steps work moves through in your organization, drawn your way, branches and loops included.
                    </p>
                </div>
            }}
            {if loading {
                <div key="sk" className="flex flex-col gap-4">
                    <div className="flex flex-wrap items-center gap-2">
                        <Skeleton className="h-8 w-40"/>
                        <div className="flex-1"/>
                        <Skeleton className="h-8 w-44 rounded-lg"/>
                        <Skeleton className="h-8 w-32 rounded-lg"/>
                    </div>
                    <div className="flex flex-wrap items-center gap-x-5 gap-y-2">
                        <Skeleton className="h-4 w-16 rounded-full"/>
                        <Skeleton className="h-4 w-16 rounded-full"/>
                        <Skeleton className="h-4 w-16 rounded-full"/>
                        <Skeleton className="h-4 w-16 rounded-full"/>
                        <Skeleton className="h-4 w-16 rounded-full"/>
                    </div>
                    <div style={{"height": "min(74vh, 44rem)"}}>
                        <Skeleton className="h-full w-full rounded-lg"/>
                    </div>
                </div>
            } elif showPicker {
                <TemplatePicker
                    key="picker"
                    applying={applying}
                    onPick={pickTemplate}
                    onScratch={startScratch}
                />
            } elif editing {
                <div key="designer" className="flex flex-col gap-4">
                    <div className="flex flex-wrap items-center gap-2">
                        {if renaming {
                            <Input
                                key="rename"
                                className="h-auto w-80 max-w-full px-2 py-0 font-display text-2xl font-bold tracking-tight sm:text-3xl md:text-3xl"
                                value={nameDraft}
                                autoFocus={True}
                                onChange={lambda (e: any) { nameDraft = e.target.value; }}
                                onBlur={saveRename}
                                onKeyDown={lambda (e: any) { if e.key == "Enter" {
                                    saveRename();
                                }}}
                            />
                        } else {
                            <h1 key="name" className="page-title">{lineName}</h1>
                        } }
                        {if not renaming {
                            <Button
                                key="rename-btn"
                                variant="ghost"
                                size="sm"
                                onClick={startRename}
                            >
                                Rename
                            </Button>
                        }}
                        {if not renaming {
                            <Button
                                key="wipe-btn"
                                variant="ghost"
                                size="sm"
                                className="text-muted-foreground hover:bg-destructive/10 hover:text-destructive"
                                onClick={lambda { confirmWipe = True; }}
                            >
                                Delete flow line
                            </Button>
                        }}
                        <div className="flex-1"/>
                        {if len(issues) > 0 {
                            <span
                                key="issues"
                                className="inline-flex min-w-0 max-w-full items-start gap-1.5 rounded-lg border border-warning/50 bg-warning/15 px-2.5 py-1 text-left text-xs font-medium text-warning"
                            >
                                <WarnIcon size={13} className="mt-0.5 shrink-0"/>
                                <span className="tabular-nums">
                                    {issues[0] + (
                                        " (+" + str(len(issues) - 1) + ")"
                                            if len(issues) > 1
                                            else ""
                                    )}
                                </span>
                            </span>
                        }}
                        <Button
                            key="add"
                            variant="outline"
                            onClick={addStep}
                            disabled={saving or creatingStep}
                        >
                            <svg
                                width={14}
                                height={14}
                                viewBox="0 0 24 24"
                                fill="none"
                                stroke="currentColor"
                                strokeWidth={2}
                                strokeLinecap="round"
                                strokeLinejoin="round"
                            >
                                <path d="M5 12h14"/>
                                <path d="M12 5v14"/>
                            </svg>
                            Add step
                        </Button>
                        <Button
                            key="doneediting"
                            onClick={lambda {
                                editing = False;
                                renaming = False;
                                connectFrom = "";
                                selectedId = "";
                                selectedEdge = "";
                                confirmDelete = False;
                                creatingStep = False;
                            }}
                        >
                            Done editing
                        </Button>
                    </div>
                    <div className="relative">
                        <div
                            onMouseDown={beginDrag}
                            onMouseMove={moveDrag}
                            onMouseUp={endDrag}
                            onMouseLeave={endDrag}
                        >
                            <FlowCanvas
                                steps={steps}
                                live={live}
                                selectedId={selectedId}
                                connectFrom={connectFrom}
                                selectedEdge={selectedEdge}
                                zoom={zoom}
                                panX={panX}
                                panY={panY}
                                animate={placed}
                                canvasRef={canvasRef}
                                viewportRef={viewportRef}
                                onZoomBy={zoomBy}
                                onZoomFit={fitZoom}
                                onSelect={selectStep}
                                edgeDraft={edgeDraft}
                                onSelectEdge={selectEdge}
                                onEdgeDraft={lambda (v: str) { edgeDraft = v; }}
                                onSaveEdgeLabel={commitEdgeLabel}
                                onDeleteEdge={deleteEdge}
                                onCanvasClick={clearCanvas}
                                onAddStep={addStep}
                            />
                        </div>
                        {if connectFrom {
                            <div
                                key="connecting"
                                className="pointer-events-none absolute inset-x-0 top-0 z-30 flex justify-center px-3 pt-3"
                            >
                                <div
                                    className="pointer-events-auto flex max-w-md items-center gap-3 rounded-lg border border-dashed bg-background/95 px-4 py-2 shadow-md backdrop-blur animate-in fade-in slide-in-from-top-2 duration-200"
                                >
                                    <p className="text-sm text-pretty">
                                        <span className="font-medium">
                                            {"Drawing a transition out of " + connectTitle + "."}
                                        </span>
                                        <span className="text-muted-foreground">
                                            {" Click the step it flows into, backwards is fine,"
                                            " loops are the point."}
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
                            </div>
                        }}
                        <div
                            className="pointer-events-none absolute inset-y-0 right-0 flex w-[21rem] max-w-[calc(100%-1rem)] flex-col gap-4 overflow-y-auto p-4"
                        >
                            {if creatingStep {
                                <div
                                    key="create"
                                    className="pointer-events-auto flex flex-col gap-3 rounded-lg border bg-card p-4 shadow-lg animate-in fade-in slide-in-from-right-4 duration-300"
                                >
                                    <div
                                        className="text-xs font-medium uppercase tracking-wider text-muted-foreground"
                                    >
                                        New step
                                    </div>
                                    <Input
                                        value={form["name"] or ""}
                                        placeholder="What should this step be called?"
                                        autoFocus={True}
                                        onChange={lambda (e: any) { setField(
                                            "name", e.target.value
                                        ); }}
                                        onKeyDown={lambda (e: any) { if e.key == "Enter" {
                                            commitName();
                                        }}}
                                    />
                                    <div className="flex gap-2">
                                        <Button
                                            size="sm"
                                            disabled={saving
                                            or not (form["name"] or "").strip()}
                                            onClick={commitName}
                                        >
                                            Add to canvas
                                        </Button>
                                        <Button
                                            size="sm"
                                            variant="ghost"
                                            onClick={lambda { creatingStep = False; }}
                                        >
                                            Cancel
                                        </Button>
                                    </div>
                                    <p className="text-xs text-muted-foreground">
                                        Kind and color can be set once it lands.
                                    </p>
                                </div>
                            } elif len(picked) > 0 {
                                <StepInspector
                                    className="pointer-events-auto shadow-lg animate-in fade-in slide-in-from-right-4 duration-300"
                                    key={picked[0].id}
                                    step={picked[0]}
                                    steps={steps}
                                    form={form}
                                    roleOptions={ownerOptions}
                                    connecting={bool(connectFrom)}
                                    saving={saving}
                                    confirmingDelete={confirmDelete}
                                    onField={setField}
                                    onNameCommit={commitName}
                                    onConnect={armConnect}
                                    onCancelConnect={lambda { connectFrom = ""; }}
                                    onDelete={deleteStep}
                                    onUnlink={deleteEdge}
                                />
                            } }
                        </div>
                    </div>
                </div>
            } else {
                <div key="viewer" className="flex flex-col gap-3">
                    <div className="flex flex-wrap items-center gap-3">
                        <h1 className="page-title">{lineName}</h1>
                        <span
                            className="rounded-full border px-3 py-1 text-xs tabular-nums text-muted-foreground"
                        >
                            {str(len(steps)) + " steps · " + str(linkCount) + " transitions · " + str(
                                taskTotal
                            ) + (" task" if taskTotal == 1 else " tasks")}
                        </span>
                        <div className="flex-1"/>
                        {if len(issues) > 0 {
                            <span
                                key="issues"
                                className="inline-flex min-w-0 max-w-full items-start gap-1.5 rounded-lg border border-warning/50 bg-warning/15 px-2.5 py-1 text-left text-xs font-medium text-warning"
                            >
                                <WarnIcon size={13} className="mt-0.5 shrink-0"/>
                                <span>{issues[0]}</span>
                            </span>
                        }}
                        <div
                            className="flex items-center gap-0.5 rounded-lg border border-border/70 bg-muted p-0.5"
                        >
                            <button
                                type="button"
                                className={"rounded-md px-2.5 py-1 text-xs font-medium " + (
                                    "bg-background text-foreground shadow-sm"
                                        if not laneMode
                                        else "text-muted-foreground transition-colors hover:text-foreground"
                                )}
                                onClick={lambda { switchView("flow"); }}
                            >
                                Flow
                            </button>
                            <button
                                type="button"
                                className={"rounded-md px-2.5 py-1 text-xs font-medium " + (
                                    "bg-background text-foreground shadow-sm"
                                        if laneMode
                                        else "text-muted-foreground transition-colors hover:text-foreground"
                                )}
                                onClick={lambda { switchView("lanes"); }}
                            >
                                Lanes
                            </button>
                        </div>
                        <Select value={projectId} onValueChange={selectProject}>
                            <SelectTrigger className="w-44">
                                <SelectValue placeholder="All projects"/>
                            </SelectTrigger>
                            <SelectContent position="popper">
                                <SelectItem value="all">All projects</SelectItem>
                                {for p in activeProjects {
                                    <SelectItem key={jid(p)} value={jid(p)}>
                                        {p.name}
                                    </SelectItem>
                                }}
                            </SelectContent>
                        </Select>
                        <Button
                            key="edit"
                            onClick={lambda {
                                switchView("flow");
                                editing = True;
                            }}
                        >
                            Edit flow line
                        </Button>
                    </div>
                    <div className="flex flex-wrap items-center gap-x-5 gap-y-2">
                        {for k in STEP_KINDS {
                            <span
                                key={k}
                                className="inline-flex items-center gap-1.5 text-xs text-muted-foreground"
                            >
                                <span
                                    className={"h-2 w-2 rounded-full " + DOT_FILL[
                                        KIND_COLORS[k]
                                    ]}
                                />
                                {KIND_LABEL[k]}
                            </span>
                        }}
                    </div>
                    {if len(roleRows) > 0 and not laneMode {
                        <div
                            key="rolestrip"
                            className="flex flex-wrap items-center gap-2"
                        >
                            {for rr in roleRows {
                                <span
                                    key={rr.id}
                                    className="inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-xs"
                                >
                                    <span
                                        className={"h-2 w-2 shrink-0 rounded-full " + DOT_FILL[
                                            colorKey(rr.color or "slate")
                                        ]}
                                    />
                                    <span className="font-medium">{rr.name}</span>
                                    <span className="text-muted-foreground">
                                        {roleHolders[rr.name]
                                            if roleHolders[rr.name]
                                            else "no one yet"}
                                    </span>
                                </span>
                            }}
                            <a
                                href="/workspace?tab=roles"
                                className="text-xs text-muted-foreground underline-offset-2 hover:underline"
                            >
                                Manage roles
                            </a>
                        </div>
                    }}
                    <div className="relative">
                        <FlowCanvas
                            steps={steps}
                            live={lanePose}
                            lanes={laneBands}
                            laneOf={laneOfStep}
                            selectedId={peekId}
                            zoom={zoom}
                            panX={panX}
                            panY={panY}
                            animate={placed}
                            showGrid={False}
                            viewportRef={viewportRef}
                            onZoomBy={zoomBy}
                            onZoomFit={fitZoom}
                            onSelect={peekStep}
                            onCanvasClick={closePeek}
                        />
                        {if len(peeked) > 0 {
                            <div
                                key="peekdock"
                                className="mt-3 flex flex-col sm:pointer-events-none sm:absolute sm:inset-y-0 sm:right-0 sm:z-30 sm:mt-0 sm:w-[21rem] sm:max-w-[calc(100%-1rem)] sm:p-4"
                            >
                                <StepTasksPanel
                                    step={peeked[0]}
                                    tasks={peekTasks}
                                    loading={peekLoading}
                                    scope={peekScope}
                                    onOpenTask={openTask}
                                    onClose={closePeek}
                                />
                            </div>
                        }}
                    </div>
                    {if laneMode and len(offFlow) > 0 {
                        <p key="offflow" className="text-xs text-muted-foreground">
                            {"Not on the flow yet: "}
                            <span className="font-medium text-foreground">
                                {", ".join(offFlow)}
                            </span>
                            {(
                                " · owns no step"
                                    if len(offFlow) == 1
                                    else " · own no step"
                            )}
                        </p>
                    }}
                </div>
            }   }
            <Dialog
                open={confirmWipe}
                onOpenChange={lambda (o: bool) { if not o and not wiping {
                    confirmWipe = False;
                }}}
            >
                <DialogContent className="sm:max-w-md">
                    <DialogHeader>
                        <DialogTitle>Delete this flow line?</DialogTitle>
                        <DialogDescription>{wipeSummary}</DialogDescription>
                    </DialogHeader>
                    <p className="text-sm text-muted-foreground">
                        Tasks keep their status and land by kind on whatever you design next. Roles and the flow line name stay. You start again from the template picker.
                    </p>
                    <DialogFooter>
                        <Button
                            variant="outline"
                            disabled={wiping}
                            onClick={lambda { confirmWipe = False; }}
                        >
                            Cancel
                        </Button>
                        <Button
                            variant="destructive"
                            disabled={wiping}
                            onClick={deleteFlowLine}
                        >
                            {if wiping {
                                <Spinner key="sp"/>
                            }}
                            {"Deleting…" if wiping else "Delete flow line"}
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
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
                categories={taskCategories}
                columnKeys={colKeys}
                columnLabels={colLabels}
                handoffKeys={handoffKeys}
                assignees={taskAssignees}
                onToggleAssignee={toggleTaskAssignee}
            />
        </div>;
}
