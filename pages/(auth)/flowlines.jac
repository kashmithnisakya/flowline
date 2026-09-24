"""flowline - Flow line page (/flowlines): the template picker, then one framed
diagram with a single toolbar, View or Edit, Flow or Lanes. Drag pans, ctrl or
cmd + wheel and pinch zoom, F fits. Phones open on an ordered step list.
Validation is advisory and never blocks saving. Keep notes out of JSX."""

import from ...models {
    Project,
    StepView,
    TaskRow,
    TaskView,
    MemberView,
    RoleView,
    IterationView
}
import from ...constants { KIND_STATUS }
import from ...services.projects.projects { AssignToProject }
import from ...services.tasks.tasks { UpdateTask, DeleteTask }
import from ...services.flowlines.flowlines {
    GetFlowLine,
    ApplyTemplate,
    SaveStep,
    MoveStep,
    DeleteStep,
    DeleteFlowLine,
    LinkTransition,
    LabelTransition,
    UnlinkTransition,
    RenameFlowLine,
    ListStepTasks
}
import from ...lib.workspace { loadWorkspace, forgetWorkspace }
import from ...lib.filters { defaultProject }
import from ...components.flowlines.FlowCanvas { FlowCanvas }
import from ...components.flowlines.lanes {
    laneLayout,
    laneRects,
    laneFitCap,
    LANE_ZOOM_CAP,
    LANE_ZOOM_MIN,
    LANE_LABEL_W,
    LANE_LABEL_NARROW
}
import from ...components.flowlines.TemplatePicker { TemplatePicker }
import from ...components.flowlines.StepInspector { StepInspector }
import from ...components.flowlines.StepTasksPanel { StepTasksPanel }
import from ...components.flowlines.StepList { StepList }
import from ...components.flowlines.controls { Segmented, ZoomControls }
import from ...components.board.TaskDialog { TaskDialog }
import from ...components.flowlines.geometry {
    hitRect,
    nodeRects,
    stepXY,
    clampZoom,
    nextStop,
    detailOf,
    NODE_W,
    NODE_H
}
import from ...components.flowlines.kinds { KIND_LABEL, KIND_TONE, DOT_FILL, colorKey }
import from ...components.common.KindGlyph { KindGlyph }
import from ...components.ui.button { Button }
import from ...components.ui.input { Input }
import from ...components.ui.skeleton { Skeleton }
import from ...components.common.Reveal { Reveal }
import from ...components.common.LoadFailed { LoadFailed }
import from ...components.ui.dialog {
    Dialog,
    DialogContent,
    DialogHeader,
    DialogTitle,
    DialogDescription,
    DialogFooter
}
import from ...components.ui.sheet { Sheet, SheetContent, SheetTitle, SheetDescription }
import from ...components.ui.popover { Popover, PopoverTrigger, PopoverContent }
import from ...components.ui.dropdown_menu {
    DropdownMenu,
    DropdownMenuTrigger,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuSeparator
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
import from ...lib.utils { fmtEstimate, parseEstimate }

glob BLANK_STEP: dict[str, str] = {
         "name": "",
         "kind": "active",
         "color": "indigo",
         "blurb": ""
     },
     # The board's task form, so the dialog opened from the panel is the
     # board's dialog with the board's fields, not a second shape of task.
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
     # Step kinds whose task dialog offers the reviewer fields, as on the board.
     HANDOFF_KINDS: list[str] = ["handoff", "blocked"],
     KIND_ORDER: list[str] = ["start", "active", "handoff", "blocked", "done"],
     # The step panel floats over the canvas at this width (22rem).
     PANEL_W: float = 352.0;


def:pub FlowLinePage -> JsxPage {
    has steps: list[StepView] = [],
        projects: list[Project] = [],
        # The org's roles and roster, for the Lane view's labels and the
        # task dialog's people.
        roleRows: list[RoleView] = [],
        roleMembers: list[MemberView] = [],
        # Viewer projection: "flow" renders the hand-drawn positions,
        # "lanes" a computed swimlane layout (lane = owner role, column =
        # flow depth). Persisted per browser; editing always uses flow.
        lineView: str = "flow",
        # The project on screen, one always: shared with the board through
        # one localStorage key, so the project you are looking at follows
        # you between the two tabs. "" until the default is known.
        projectId: str = "",
        loading: bool = True,
        # The first read produced nothing: the page says so itself, with a
        # retry, rather than offering the template picker over a real line.
        failed: bool = False,
        retrying: bool = False,
        editing: bool = False,
        scratch: bool = False,
        applying: str = "",
        lineName: str = "Flow line",
        renaming: bool = False,
        nameDraft: str = "",
        selectedId: str = "",
        connectFrom: str = "",
        selectedEdge: str = "",
        # What the selected transition's label says while it is being typed,
        # re-seeded from the edge on every selection.
        edgeDraft: str = "",
        edgeCarry: str = "",
        form: dict[str, str] = BLANK_STEP,
        saving: bool = False,
        confirmDelete: bool = False,
        # Deleting the whole flow line confirms in a dialog that spells out
        # what goes and what stays.
        confirmWipe: bool = False,
        wiping: bool = False,
        # Add step opens a naming panel first: the step only exists once the
        # user has called it something, never as a placeholder card.
        creatingStep: bool = False,
        # A dragged step's live position, canvas px, for this drag only.
        live: dict[str, list[float]] = {},
        dragId: str = "",
        # Clicking a step outside edit mode opens its work.
        peekId: str = "",
        peekTasks: list[TaskRow] = [],
        peekLoading: bool = False,
        peekTotal: int = 0,
        peekMore: bool = False,
        peekPage: int = 0,
        peekLoadingMore: bool = False,
        # Which step the panel is on, live, for checks after an await.
        peekRef: Ref[any] = Ref(),
        # A row in that panel opens the BOARD's task dialog, driven from
        # here: same form dict, same walkers, so the two never drift.
        taskOpen: bool = False,
        editTaskId: str = "",
        taskForm: dict[str, str] = BLANK_TASK,
        taskAssignees: list[str] = [],
        taskSaving: bool = False,
        iterations: list[IterationView] = [],
        zoom: float = 1.0,
        # Screen-px offset of the drawing's origin inside the viewport.
        panX: float = 0.0,
        panY: float = 0.0,
        # The canvas viewport's inner box, measured in the fit's layout
        # effect; the lane layout grows its bands into the spare height.
        boxW: float = 0.0,
        boxH: float = 0.0,
        # Phones: below 640px the page opens on the step list, and the
        # diagram is one tap away.
        narrow: bool = False,
        phoneView: str = "list",
        # First task titles per step for the high-detail zoom, read off
        # the flow line with its counts.
        stepTitles: dict[str, list[str]] = {},
        busyRef: Ref[any] = Ref(),
        viewportRef: Ref[any] = Ref(),
        # Mirrors of zoom and pan for native listeners and quick repeats.
        zoomRef: Ref[any] = Ref(),
        panRef: Ref[any] = Ref(),
        fittedRef: Ref[any] = Ref(),
        dragRef: Ref[any] = Ref(),
        wireRef: Ref[any] = Ref(),
        gestureRef: Ref[any] = Ref(),
        pointersRef: Ref[any] = Ref(),
        spaceRef: Ref[any] = Ref(),
        swallowRef: Ref[any] = Ref(),
        stepsRef: Ref[any] = Ref(),
        liveRef: Ref[any] = Ref(),
        canvasRef: Ref[any] = Ref(),
        layoutRef: Ref[any] = Ref(),
        # The zoom the last lane fit landed on (the bands grow for it), and
        # the zoom and pan of the last fit, to tell whether anyone moved since.
        laneFitRef: Ref[any] = Ref(),
        lastFitRef: Ref[any] = Ref(),
        refitRef: Ref[any] = Ref();

    async can with entry {
        # Setup's "Draw my own" lands here with start=blank: open the empty
        # designer, not the template picker. Setting it on each mount is safe.
        w: any = window;
        params: any = new(w.URLSearchParams, w.location.search);
        if params.get("start") == "blank" {
            startScratch();
        }
        boot();
    }

    # Fit when the visible area changes: first load, a new step count, a
    # view flip, the edit column appearing, or a resize. Not when the step
    # panel opens: it floats over the canvas instead of taking its width.
    useLayoutEffect(
        lambda {
            measureBox();
            fitZoom();
        },
        [len(steps), editing, lineView, boxW, boxH, narrow, phoneView, loading]
    );

    # A resize refits through measureBox. Late web fonts widen the measured
    # names, so they refit too, unless the view was moved since the last fit.
    useEffect(
        lambda {
            onResize: any = lambda { measureBox(); };
            window.addEventListener("resize", onResize);
            w: any = window;
            alive: any = {"on": True};
            if w.document and w.document.fonts {
                w.document.fonts.ready.then(
                    lambda { w.requestAnimationFrame(
                        lambda { if alive["on"] { refitIfUntouched(); }}
                    ); }
                );
            }
            return lambda {
                alive["on"] = False;
                window.removeEventListener("resize", onResize);
            };
        },
        []
    );

    # Phone or not, from the same 640px breakpoint the layout uses.
    useEffect(
        lambda {
            w: any = window;
            media: any = w.matchMedia("(max-width: 639px)");
            narrow = bool(media.matches);
            onChange: any = lambda (e: any) { narrow = bool(e.matches); };
            media.addEventListener("change", onChange);
            return lambda { media.removeEventListener("change", onChange); };
        },
        []
    );

    # Wheel over the canvas: ctrl or cmd (and trackpad pinch) zooms around
    # the pointer, a plain wheel pans. Native and non-passive, so the page
    # does not scroll or zoom underneath.
    useEffect(
        lambda {
            view: any = viewportRef.current;
            handler: any = lambda (e: any) { onWheel(e); };
            if view {
                view.addEventListener("wheel", handler, {"passive": False});
            }
            return lambda { if view { view.removeEventListener("wheel", handler); }};
        },
        [loading, editing, narrow, phoneView, len(steps) == 0]
    );

    # Keys: F or 0 fits, + and - zoom, Space held turns a drag into a pan,
    # Esc closes the task panel. Never while typing or while a dialog owns
    # the keyboard; on the CAPTURE phase so Radix has not closed it yet.
    useEffect(
        lambda {
            onKey: any = lambda (e: any) { onKeyDown(e); };
            onUp: any = lambda (e: any) { if e.key == " " {
                spaceRef.current = False;
            }};
            window.addEventListener("keydown", onKey, True);
            window.addEventListener("keyup", onUp);
            return lambda {
                window.removeEventListener("keydown", onKey, True);
                window.removeEventListener("keyup", onUp);
            };
        },
        []
    );

    async def boot -> None;
    async def loadShared -> None;
    async def reload(pid: str) -> None;
    async def retryLoad -> None;
    async def selectProject(v: str) -> None;
    async def peekStep(stepId: str) -> None;
    async def refreshPeek(stepId: str, pid: str) -> None;
    async def morePeek -> None;
    def loadTitles(fresh: list[StepView]) -> None;
    def closePeek -> None;
    def revealStep(stepId: str) -> None;
    def openTask(tid: str) -> None;
    def replacePeekRow(view: TaskView) -> None;
    def absorbDetails(view: TaskView) -> None;
    def setTaskField(key: str, value: str) -> None;
    def toggleTaskAssignee(memberId: str) -> None;
    async def saveTask -> None;
    async def deleteTask -> None;
    def stepName(key: str) -> str;
    def mappedStatus(key: str) -> str;
    def switchView(v: str) -> None;
    def switchMode(v: str) -> None;
    def finishEditing -> None;
    def lanePlan -> dict[str, any];
    def laneLabelW -> float;
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
    def selectEdge(key: str, said: str, carried: str) -> None;
    async def commitEdgeLabel(fromId: str, toId: str, said: str, carried: str) -> None;
    def selectStep(stepId: str) -> None;
    def armConnect -> None;
    def clearCanvas -> None;
    def setField(key: str, value: str) -> None;
    def zoomStep(dirn: int) -> None;
    def zoomActual -> None;
    def zoomTo(z: float, sx: float, sy: float) -> None;
    def applyPan(x: float, y: float) -> None;
    def contentBox(z: float) -> list[float];
    def panRects(z: float) -> dict[str, list[float]];
    def drawnRects -> dict[str, list[float]];
    def measureBox -> None;
    def fitZoom -> None;
    def refitIfUntouched -> None;
    def onWheel(e: any) -> None;
    def onKeyDown(e: any) -> None;
    def swallowed -> bool;
    def pointerXY(e: any) -> list[float];
    def surfaceXY(e: any) -> list[float];
    def beginDrag(e: any) -> None;
    def moveDrag(e: any) -> None;
    async def endDrag(e: any) -> None;

    peekRef.current = peekId;
    stepsRef.current = steps;
    liveRef.current = live;
    if zoomRef.current is None {
        zoomRef.current = zoom;
    }

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
    activeMembers = [
        m
        for m in roleMembers
        if m.active
    ];
    ownerOptions: list[str] = [];
    for rr in roleRows {
        ownerOptions.append(rr.name);
    }
    # Phones show the list unless the diagram was asked for; editing always
    # needs the diagram.
    showList = narrow and phoneView == "list" and not editing;
    laneMode = lineView == "lanes" and not editing;
    # The lane projection, the SAME plan the fit measured (box size included),
    # so the bands drawn are the bands fitted.
    plan: dict[str, any] = lanePlan();
    lanePose: dict[str, list[float]] = plan["positions"];
    laneBands: list[dict[str, any]] = plan["lanes"];
    laneOfStep: dict[str, str] = plan["laneOf"] if "laneOf" in plan else {};
    laneColOf: dict[str, int] = plan["colOf"] if "colOf" in plan else {};
    listPlan: dict[str, any] = laneLayout(steps, roleRows, roleMembers)
        if showList
        else {"colOf": {}};
    listCols: dict[str, int] = listPlan["colOf"];
    taskTotal = 0;
    for s in steps {
        taskTotal = taskTotal + s.task_count;
    }
    # The org's roles and who holds them, for the key row's Roles popover.
    roleList: list[dict[str, any]] = [];
    for rr in roleRows {
        held: list[str] = [];
        for m in roleMembers {
            if m.active and rr.name in m.roles {
                held.append(m.name);
            }
        }
        roleList.append(
            {
                "id": rr.id,
                "name": rr.name,
                "dot": DOT_FILL[colorKey(rr.color or "slate")],
                "holders": ", ".join(held) if len(held) > 0 else "No one yet",
                "none": len(held) == 0
            }
        );
    }

    peekScope = "in this project";
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
    connectTitle = sourced[0].name if len(sourced) > 0 else "";

    linkCount = 0;
    startCount = 0;
    doneCount = 0;
    usedKinds: list[str] = [];
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
    # The key lists only the kinds this flow line uses, in kind order.
    for k in KIND_ORDER {
        for s in steps {
            if s.kind == k and k not in usedKinds {
                usedKinds.append(k);
            }
        }
    }
    hasBack = False;
    for s in steps {
        for nid in s.next_ids {
            if nid in byId and byId[nid].sort_order < s.sort_order {
                hasBack = True;
            }
        }
    }

    stepNoun = "step" if len(steps) == 1 else "steps";
    linkNoun = "transition" if linkCount == 1 else "transitions";
    wipeSummary = (
        str(len(steps))
        + " "
        + stepNoun
        + " and "
        + str(linkCount)
        + " "
        + linkNoun
        + " will be removed."
    );

    # Advisory checks. All plain BFS over the views already in hand.
    issues: list[str] = [];
    if len(steps) > 0 {
        if startCount == 0 {
            issues.append("No start step yet. Mark where new work lands.");
        }
        if doneCount == 0 {
            issues.append(
                "No done step yet. Every flow line needs somewhere to finish."
            );
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
            at: int = 0;
            while at < len(frontier) {
                current: str = frontier[at];
                at = at + 1;
                for nid in byId[current].next_ids {
                    if nid in byId and nid not in seen {
                        seen[nid] = True;
                        frontier.append(nid);
                    }
                }
            }
            stranded: int = 0;
            for s in steps {
                if s.id not in seen {
                    stranded = stranded + 1;
                }
            }
            if stranded > 0 {
                issues.append(
                    str(stranded)
                        + (" step has" if stranded == 1 else " steps have")
                        + " no path from a start step."
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
            at2: int = 0;
            while at2 < len(backlog) {
                current2: str = backlog[at2];
                at2 = at2 + 1;
                for pid in byId[current2].prev_ids {
                    if pid in byId and pid not in reach {
                        reach[pid] = True;
                        backlog.append(pid);
                    }
                }
            }
            noPath: int = 0;
            for s in steps {
                if s.id not in reach {
                    noPath = noPath + 1;
                }
            }
            if noPath > 0 {
                issues.append(
                    str(noPath)
                        + (" step has" if noPath == 1 else " steps have")
                        + " no path to a done step."
                );
            }
        }
    }

    showFailed = not loading and failed and len(steps) == 0;
    showPicker = not loading and not failed and len(steps) == 0 and not scratch;
    # The diagram fills the window below the toolbar and key; edit mode's
    # bar takes one more row.
    canvasH = "max(20rem, calc(100dvh - 12rem))"
        if narrow
        else (
            "max(24rem, calc(100dvh - 16.5rem))"
                if editing
                else "max(24rem, calc(100dvh - 13.5rem))"
        );
    modeOptions: list[dict[str, str]] = [
        {"value": "view", "label": "View"},
        {"value": "edit", "label": "Edit"}
    ];
    layoutOptions: list[dict[str, str]] = [
        {"value": "flow", "label": "Flow"},
        {"value": "lanes", "label": "Lanes"}
    ];
    phoneOptions: list[dict[str, str]] = [
        {"value": "list", "label": "List"},
        {"value": "diagram", "label": "Diagram"}
    ];

    def loadFrame -> JsxElement {
        return
            <div
                className="surface flex min-w-0 flex-col overflow-hidden"
                aria-busy="true"
            >
                <div
                    data-flow-toolbar="true"
                    className="pointer-events-none flex min-w-0 flex-wrap items-center gap-x-3 gap-y-2 border-b bg-card px-4 py-2.5"
                >
                    <h1 className="page-title mr-1 min-w-0 truncate">{lineName}</h1>
                    <Segmented label="Mode" options={modeOptions} value="view"/>
                    {if not showList {
                        <Segmented
                            key="layout"
                            label="Layout"
                            options={layoutOptions}
                            value={lineView}
                        />
                    }}
                    <Select value="" disabled={True}>
                        <SelectTrigger
                            className="toolbar-filter max-w-48"
                            data-active="true"
                            aria-label="Project"
                        >
                            <SelectValue placeholder="Project"/>
                        </SelectTrigger>
                        <SelectContent position="popper"></SelectContent>
                    </Select>
                    <div className="ml-auto flex shrink-0 items-center gap-3">
                        {if not showList {
                            <ZoomControls key="zoom" zoom={1.0} pending={True}/>
                        }}
                        {if not narrow {
                            <Button
                                key="edit"
                                size="sm"
                                className="h-[30px]"
                                disabled={True}
                            >
                                Edit flow line
                            </Button>
                        }}
                    </div>
                </div>
                <div className="relative min-w-0" style={{"height": canvasH}}>
                    <div
                        className="absolute inset-0 flex items-center justify-center px-6"
                    >
                        {for i in range(3) {
                            <div key={"n" + str(i)} className="flex items-center">
                                {if i > 0 {
                                    <span
                                        key="w"
                                        aria-hidden="true"
                                        className="h-0.5 w-8 shrink-0 bg-wire sm:w-16"
                                    />
                                }}
                                <div
                                    className="flex h-[52px] w-[132px] shrink-0 flex-col justify-center gap-2 rounded-md border bg-card px-3"
                                >
                                    <Skeleton className="h-3 w-16"/>
                                    <Skeleton className="h-2.5 w-20"/>
                                </div>
                            </div>
                        }}
                    </div>
                </div>
                {if not showList {
                    <div
                        key="legend"
                        aria-label="Key"
                        className="flex min-w-0 flex-wrap items-center gap-x-4 gap-y-1.5 border-t bg-card px-4 py-2 text-[12.5px] text-muted-foreground"
                    >
                        {for i in range(4) {
                            <span
                                key={"k" + str(i)}
                                className="inline-flex h-[18px] items-center gap-1.5"
                            >
                                <Skeleton className="size-3.5 rounded-full"/>
                                <Skeleton className="h-3 w-12"/>
                            </span>
                        }}
                        <span className="inline-flex h-[18px] items-center gap-1.5">
                            <svg
                                width={22}
                                height={8}
                                aria-hidden="true"
                                className="text-wire"
                            >
                                <path
                                    d="M1 4 H21"
                                    stroke="currentColor"
                                    strokeWidth={1.6}
                                    strokeLinecap="round"
                                />
                            </svg>
                            Moves forward
                        </span>
                        <span className="ml-auto inline-flex h-6 items-center">
                            <Skeleton className="h-3 w-44"/>
                        </span>
                    </div>
                }}
            </div>;
    }

    return
        <div className="flex w-full min-w-0 flex-col gap-4">
            <Reveal ready={not loading} frame={loadFrame()} className="min-w-0">
                {if showFailed {
                    <div key="failed" className="flex flex-col gap-6">
                        <h1 className="page-title">Flow line</h1>
                        <LoadFailed
                            title="Could not load the flow line"
                            onRetry={retryLoad}
                            retrying={retrying}
                        />
                    </div>
                } elif showPicker {
                    <div key="picker" className="flex flex-col gap-6">
                        <h1 className="page-title">Flow line</h1>
                        <TemplatePicker
                            applying={applying}
                            onPick={pickTemplate}
                            onScratch={startScratch}
                        />
                    </div>
                } else {
                    <div
                        key="line"
                        className="surface flex min-w-0 flex-col overflow-hidden"
                    >
                        <div
                            data-flow-toolbar="true"
                            className="flex min-w-0 flex-wrap items-center gap-x-3 gap-y-2 border-b bg-card px-4 py-2.5"
                        >
                            {if renaming {
                                <Input
                                    key="rename"
                                    aria-label="Flow line name"
                                    className="h-8 w-64 max-w-full text-base font-semibold"
                                    value={nameDraft}
                                    autoFocus={True}
                                    onChange={lambda (e: any) { nameDraft = e.target.value; }}
                                    onBlur={saveRename}
                                    onKeyDown={lambda (e: any) { if e.key == "Enter" {
                                        saveRename();
                                    }}}
                                />
                            } else {
                                <h1
                                    key="name"
                                    className="page-title mr-1 min-w-0 truncate"
                                >
                                    {lineName}
                                </h1>
                            } }
                            <Segmented
                                label="Mode"
                                options={modeOptions}
                                value={"edit" if editing else "view"}
                                onChange={switchMode}
                            />
                            {if narrow and not editing {
                                <Segmented
                                    key="phoneview"
                                    label="Show"
                                    options={phoneOptions}
                                    value={phoneView}
                                    onChange={lambda (v: str) { phoneView = v; }}
                                />
                            }}
                            {if not editing and not showList {
                                <Segmented
                                    key="layout"
                                    label="Layout"
                                    options={layoutOptions}
                                    value={lineView}
                                    onChange={switchView}
                                />
                            }}
                            {if not editing {
                                <Select
                                    key="project"
                                    value={projectId}
                                    onValueChange={selectProject}
                                >
                                    <SelectTrigger
                                        className="toolbar-filter max-w-48"
                                        data-active="true"
                                        aria-label="Project"
                                    >
                                        <SelectValue placeholder="Project"/>
                                    </SelectTrigger>
                                    <SelectContent position="popper">
                                        {for p in activeProjects {
                                            <SelectItem key={jid(p)} value={jid(p)}>
                                                {p.name}
                                            </SelectItem>
                                        }}
                                    </SelectContent>
                                </Select>
                            }}
                            <div className="ml-auto flex shrink-0 items-center gap-3">
                                {if not showList {
                                    <ZoomControls
                                        key="zoom"
                                        zoom={zoom}
                                        onOut={lambda { zoomStep(-1); }}
                                        onIn={lambda { zoomStep(1); }}
                                        onActual={zoomActual}
                                        onFit={lambda {
                                            fittedRef.current = False;
                                            fitZoom();
                                        }}
                                    />
                                }}
                                {if not editing and not narrow {
                                    <Button
                                        key="edit"
                                        size="sm"
                                        className="h-[30px]"
                                        onClick={lambda { switchMode("edit"); }}
                                    >
                                        Edit flow line
                                    </Button>
                                }}
                            </div>
                        </div>
                        {if editing {
                            <div
                                key="editbar"
                                role="region"
                                aria-label="Editing"
                                className="flex min-w-0 flex-wrap items-center gap-x-4 gap-y-2 border-b bg-card px-4 py-2"
                            >
                                <span
                                    className="inline-flex items-center gap-2 text-[13px]"
                                >
                                    <span
                                        className="size-2 shrink-0 rounded-full bg-primary"
                                        aria-hidden="true"
                                    />
                                    <span className="font-semibold">Editing</span>
                                    <span className="text-muted-foreground">
                                        Changes save as you go.
                                    </span>
                                </span>
                                <span
                                    className="hidden min-w-0 items-center gap-x-1.5 text-xs text-subtle xl:flex"
                                >
                                    Drag a step to move it · Drag from its edge to connect · Click a transition to label it
                                </span>
                                <div className="ml-auto flex items-center gap-2">
                                    <Button
                                        key="add"
                                        variant="outline"
                                        size="sm"
                                        onClick={addStep}
                                        disabled={saving or creatingStep}
                                    >
                                        <svg
                                            width={14}
                                            height={14}
                                            viewBox="0 0 16 16"
                                            fill="none"
                                            stroke="currentColor"
                                            strokeWidth={1.7}
                                            strokeLinecap="round"
                                            aria-hidden="true"
                                        >
                                            <path d="M8 3v10M3 8h10"/>
                                        </svg>
                                        Add step
                                    </Button>
                                    <DropdownMenu>
                                        <DropdownMenuTrigger
                                            asChild={False}
                                            aria-label="More flow line actions"
                                            className="flex size-7 items-center justify-center rounded-md text-muted-foreground transition-colors outline-none hover:bg-accent hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring"
                                        >
                                            <svg
                                                width={16}
                                                height={16}
                                                viewBox="0 0 16 16"
                                                aria-hidden="true"
                                            >
                                                <circle
                                                    cx={3.5}
                                                    cy={8}
                                                    r={1.3}
                                                    fill="currentColor"
                                                />
                                                <circle
                                                    cx={8}
                                                    cy={8}
                                                    r={1.3}
                                                    fill="currentColor"
                                                />
                                                <circle
                                                    cx={12.5}
                                                    cy={8}
                                                    r={1.3}
                                                    fill="currentColor"
                                                />
                                            </svg>
                                        </DropdownMenuTrigger>
                                        <DropdownMenuContent
                                            align="end"
                                            className="w-48"
                                        >
                                            <DropdownMenuItem onSelect={startRename}>
                                                Rename flow line
                                            </DropdownMenuItem>
                                            <DropdownMenuSeparator/>
                                            <DropdownMenuItem
                                                variant="destructive"
                                                onSelect={lambda { confirmWipe = True; }}
                                            >
                                                Delete flow line
                                            </DropdownMenuItem>
                                        </DropdownMenuContent>
                                    </DropdownMenu>
                                    <Button
                                        key="doneediting"
                                        size="sm"
                                        onClick={finishEditing}
                                    >
                                        Done editing
                                    </Button>
                                </div>
                            </div>
                        }}
                        {if showList {
                            <div key="list" className="bg-card">
                                <StepList
                                    steps={steps}
                                    colOf={listCols}
                                    selectedId={peekId}
                                    onOpen={peekStep}
                                />
                            </div>
                        } else {
                            <div
                                key="canvasrow"
                                className="flex min-w-0 flex-col sm:flex-row"
                            >
                                <div
                                    className="relative min-w-0 sm:flex-1"
                                    style={{"height": canvasH}}
                                >
                                    <div
                                        className="absolute inset-0"
                                        onPointerDown={beginDrag}
                                        onPointerMove={moveDrag}
                                        onPointerUp={endDrag}
                                        onPointerCancel={endDrag}
                                    >
                                        <FlowCanvas
                                            steps={steps}
                                            live={lanePose if laneMode else live}
                                            lanes={laneBands if laneMode else []}
                                            laneOf={laneOfStep}
                                            laneCols={laneColOf}
                                            laneLabelW={laneLabelW()}
                                            selectedId={selectedId
                                                if editing
                                                else peekId}
                                            connectFrom={connectFrom if editing else ""}
                                            selectedEdge={selectedEdge
                                                if editing
                                                else ""}
                                            zoom={zoom}
                                            panX={panX}
                                            panY={panY}
                                            editing={editing}
                                            dragId={dragId}
                                            stepTitles={stepTitles}
                                            canvasRef={canvasRef}
                                            layoutRef={layoutRef}
                                            viewportRef={viewportRef}
                                            onSelect={selectStep
                                                if editing
                                                else peekStep}
                                            edgeDraft={edgeDraft}
                                            edgeCarry={edgeCarry}
                                            onSelectEdge={selectEdge}
                                            onEdgeDraft={lambda (v: str) { edgeDraft = v; }}
                                            onEdgeCarry={lambda (v: str) { edgeCarry = v; }}
                                            onSaveEdgeLabel={commitEdgeLabel}
                                            onDeleteEdge={deleteEdge}
                                            onCanvasClick={clearCanvas
                                                if editing
                                                else closePeek}
                                            onAddStep={lambda {
                                                editing = True;
                                                addStep();
                                            }}
                                        />
                                    </div>
                                    {if editing and connectFrom {
                                        <div
                                            key="connecting"
                                            className="pointer-events-none absolute inset-x-0 top-0 z-40 flex justify-center px-3 pt-3"
                                        >
                                            <div
                                                className="pointer-events-auto flex max-w-md items-center gap-3 rounded-xl border bg-popover px-4 py-2 shadow-md"
                                            >
                                                <p className="text-[13px] text-pretty">
                                                    <span className="font-semibold">
                                                        {"Connecting from "
                                                            + connectTitle
                                                            + "."}
                                                    </span>
                                                    <span
                                                        className="text-muted-foreground"
                                                    >
                                                        {" Click the step work moves to. Going back is fine."}
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
                                    {if not editing
                                        and not narrow
                                        and len(peeked) > 0 {
                                        <div
                                            key="peekdock"
                                            className="absolute top-3 right-3 z-40 flex max-h-[calc(100%-1.5rem)] w-[22rem] max-w-[calc(100%-1.5rem)] flex-col overflow-hidden rounded-xl border shadow-xl"
                                        >
                                            <StepTasksPanel
                                                className="max-h-full"
                                                step={peeked[0]}
                                                tasks={peekTasks}
                                                loading={peekLoading}
                                                total={peekTotal}
                                                hasMore={peekMore}
                                                loadingMore={peekLoadingMore}
                                                onMore={morePeek}
                                                scope={peekScope}
                                                onOpenTask={openTask}
                                                onClose={closePeek}
                                            />
                                        </div>
                                    }}
                                </div>
                                {if editing {
                                    <div
                                        key="inspector"
                                        className="flex min-w-0 flex-col gap-4 overflow-y-auto border-t bg-card p-4 sm:w-[21rem] sm:shrink-0 sm:border-t-0 sm:border-l"
                                        style={{
                                            "maxHeight": "none" if narrow else canvasH
                                        }}
                                    >
                                        {if creatingStep {
                                            <div
                                                key="create"
                                                className="flex flex-col gap-3"
                                            >
                                                <h2 className="section-title">
                                                    New step
                                                </h2>
                                                <Input
                                                    aria-label="Step name"
                                                    value={form["name"] or ""}
                                                    placeholder="What should this step be called?"
                                                    autoFocus={True}
                                                    onChange={lambda (e: any) { setField(
                                                        "name", e.target.value
                                                    ); }}
                                                    onKeyDown={lambda (e: any) { if e.key
                                                        == "Enter" {
                                                        commitName();
                                                    }}}
                                                />
                                                <div className="flex gap-2">
                                                    <Button
                                                        size="sm"
                                                        disabled={saving
                                                            or not (
                                                                form["name"] or ""
                                                            ).strip()}
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
                                                <p className="text-xs text-subtle">
                                                    Kind, colour and owner can be set once it is on the canvas.
                                                </p>
                                            </div>
                                        } elif len(picked) > 0 {
                                            <StepInspector
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
                                        } else {
                                            <div
                                                key="howto"
                                                className="flex flex-col gap-4"
                                            >
                                                <div className="flex flex-col gap-2.5">
                                                    <h2 className="section-title">
                                                        How to edit
                                                    </h2>
                                                    <ol
                                                        className="flex flex-col gap-2 text-[13px]"
                                                    >
                                                        <li className="flex gap-2.5">
                                                            <span
                                                                className="num w-4 shrink-0 text-subtle"
                                                            >
                                                                1
                                                            </span>
                                                            <span>
                                                                Drag a step to move it. Drag empty canvas to pan.
                                                            </span>
                                                        </li>
                                                        <li className="flex gap-2.5">
                                                            <span
                                                                className="num w-4 shrink-0 text-subtle"
                                                            >
                                                                2
                                                            </span>
                                                            <span>
                                                                Drag from a step's edge (the dots) to another step to connect them.
                                                            </span>
                                                        </li>
                                                        <li className="flex gap-2.5">
                                                            <span
                                                                className="num w-4 shrink-0 text-subtle"
                                                            >
                                                                3
                                                            </span>
                                                            <span>
                                                                Click a transition to label it, or a step to rename it, change its kind or remove it.
                                                            </span>
                                                        </li>
                                                    </ol>
                                                </div>
                                                <div
                                                    className="flex flex-col gap-2 border-t pt-3"
                                                >
                                                    <h2 className="section-title">
                                                        Checks
                                                    </h2>
                                                    {if len(issues) == 0 {
                                                        <p
                                                            key="ok"
                                                            className="text-[13px] text-muted-foreground"
                                                        >
                                                            Every step can be reached from a start step and can reach a done step.
                                                        </p>
                                                    } else {
                                                        <ul
                                                            key="issues"
                                                            className="flex flex-col gap-1.5"
                                                        >
                                                            {for msg in issues {
                                                                <li
                                                                    key={msg}
                                                                    className="flex items-start gap-2 text-[13px] text-warning"
                                                                >
                                                                    <WarnIcon
                                                                        size={14}
                                                                        className="mt-0.5 shrink-0"
                                                                    />
                                                                    <span>{msg}</span>
                                                                </li>
                                                            }}
                                                        </ul>
                                                    } }
                                                    <p className="text-xs text-subtle">
                                                        Checks are advice. Saving is never blocked.
                                                    </p>
                                                </div>
                                            </div>
                                        }  }
                                    </div>
                                }}
                            </div>
                        } }
                        {if not showList {
                            <div
                                key="legend"
                                aria-label="Key"
                                className="flex min-w-0 flex-wrap items-center gap-x-4 gap-y-1.5 border-t bg-card px-4 py-2 text-[12.5px] text-muted-foreground"
                            >
                                {for k in usedKinds {
                                    <span
                                        key={k}
                                        className="inline-flex items-center gap-1.5"
                                    >
                                        <KindGlyph
                                            kind={k}
                                            size={14}
                                            className={KIND_TONE[k]
                                                if k in KIND_TONE
                                                else "text-subtle"}
                                        />
                                        {KIND_LABEL[k]}
                                    </span>
                                }}
                                <span className="inline-flex items-center gap-1.5">
                                    <svg
                                        width={22}
                                        height={8}
                                        aria-hidden="true"
                                        className="text-wire"
                                    >
                                        <path
                                            d="M1 4 H21"
                                            stroke="currentColor"
                                            strokeWidth={1.6}
                                            strokeLinecap="round"
                                        />
                                    </svg>
                                    Moves forward
                                </span>
                                {if hasBack or editing {
                                    <span
                                        key="back"
                                        className="inline-flex items-center gap-1.5"
                                    >
                                        <svg
                                            width={22}
                                            height={8}
                                            aria-hidden="true"
                                            className="text-wire"
                                        >
                                            <path
                                                d="M1 4 H21"
                                                stroke="currentColor"
                                                strokeWidth={1.6}
                                                strokeDasharray="5 4"
                                            />
                                        </svg>
                                        Sends back, on purpose
                                    </span>
                                }}
                                {if len(issues) > 0 and not editing {
                                    <span
                                        key="issues"
                                        className="inline-flex min-w-0 items-center gap-1.5 text-warning"
                                        title={" ".join(issues)}
                                    >
                                        <WarnIcon size={14} className="shrink-0"/>
                                        <span className="truncate">
                                            {issues[0]
                                                + (
                                                    " (+"
                                                        + str(len(issues) - 1)
                                                        + " more)"
                                                        if len(issues) > 1
                                                        else ""
                                                )}
                                        </span>
                                    </span>
                                }}
                                <Popover>
                                    <PopoverTrigger
                                        className="ml-auto inline-flex h-6 items-center gap-1.5 rounded-sm px-1.5 text-[12.5px] text-muted-foreground transition-colors hover:bg-accent hover:text-foreground focus-visible:outline-2 focus-visible:outline-ring"
                                    >
                                        Roles
                                        <span className="num text-xs">
                                            {str(len(roleList))}
                                        </span>
                                    </PopoverTrigger>
                                    <PopoverContent
                                        align="end"
                                        collisionPadding={16}
                                        className="w-72 gap-2.5 p-3"
                                    >
                                        <div
                                            className="flex items-baseline justify-between gap-2"
                                        >
                                            <h2 className="text-sm font-semibold">
                                                Roles
                                            </h2>
                                            <a
                                                href="/workspace?tab=roles"
                                                className="text-xs text-muted-foreground underline-offset-2 hover:text-foreground hover:underline"
                                            >
                                                Manage roles
                                            </a>
                                        </div>
                                        {if len(roleList) == 0 {
                                            <p
                                                key="none"
                                                className="text-[13px] text-muted-foreground"
                                            >
                                                No roles yet. A role says who holds a step.
                                            </p>
                                        } else {
                                            <ul
                                                key="roles"
                                                className="flex flex-col gap-2"
                                            >
                                                {for rl in roleList {
                                                    <li
                                                        key={rl["id"]}
                                                        className="flex min-w-0 flex-col"
                                                    >
                                                        <span
                                                            className="flex min-w-0 items-center gap-1.5 text-[13px] font-medium"
                                                        >
                                                            <span
                                                                className={"step-swatch "
                                                                    + rl["dot"]}
                                                                aria-hidden="true"
                                                            />
                                                            <span className="truncate">
                                                                {rl["name"]}
                                                            </span>
                                                        </span>
                                                        <span
                                                            className={"pl-4 text-xs "
                                                                + (
                                                                    "text-warning"
                                                                        if rl["none"]
                                                                        else "text-muted-foreground"
                                                                )}
                                                        >
                                                            {rl["holders"]}
                                                        </span>
                                                    </li>
                                                }}
                                            </ul>
                                        } }
                                    </PopoverContent>
                                </Popover>
                                <span className="text-xs text-subtle">
                                    <span className="num">{str(len(steps))}</span>
                                    {" " + stepNoun + " · "}
                                    <span className="num">{str(linkCount)}</span>
                                    {" " + linkNoun + " · "}
                                    <span className="num">{str(taskTotal)}</span>
                                    {" task" if taskTotal == 1 else " tasks"}
                                </span>
                                <span
                                    className="hidden items-center gap-1 text-xs text-subtle md:inline-flex"
                                >
                                    Drag to pan ·
                                    <span className="kbd">F</span>
                                    fits
                                </span>
                            </div>
                        }}
                    </div>
                }  }
            </Reveal>
            <Sheet
                open={narrow and not editing and len(peeked) > 0}
                onOpenChange={lambda (o: bool) { if not o { closePeek(); }}}
            >
                <SheetContent side="bottom" className="max-h-[85dvh] gap-0 p-0">
                    <SheetTitle className="sr-only">
                        {peeked[0].name if len(peeked) > 0 else "Step"}
                    </SheetTitle>
                    <SheetDescription className="sr-only">
                        The tasks sitting on this step.
                    </SheetDescription>
                    {if len(peeked) > 0 {
                        <StepTasksPanel
                            key="sheetpanel"
                            className="max-h-[85dvh]"
                            step={peeked[0]}
                            tasks={peekTasks}
                            loading={peekLoading}
                            total={peekTotal}
                            hasMore={peekMore}
                            loadingMore={peekLoadingMore}
                            closable={False}
                            onMore={morePeek}
                            scope={peekScope}
                            onOpenTask={openTask}
                            onClose={closePeek}
                        />
                    }}
                </SheetContent>
            </Sheet>
            <Dialog
                open={confirmWipe}
                onOpenChange={lambda (o: bool) { if not o and not wiping {
                    confirmWipe = False;
                }}}
            >
                <DialogContent className="bg-card sm:max-w-md">
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
                            {"Deleting" if wiping else "Delete flow line"}
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
                steps={steps}
                roles={roleRows}
                taskId={editTaskId}
                onLoaded={absorbDetails}
                onChecklist={replacePeekRow}
                iterations={iterations}
            />
        </div>;
}
