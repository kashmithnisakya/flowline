"""flowline - Flow line page (/flowlines): the project's header, the template
picker, then one framed diagram with a single toolbar, View or Edit, Flow or
Lanes. Drag pans, ctrl or cmd + wheel and pinch zoom, F fits. Phones open on an
ordered step list. Validation is advisory and never blocks saving."""

import from ...models { Project, StepView, TaskRow, TaskView, MemberView, RoleView }
import from ...constants { KIND_STATUS }
import from ...services.projects.projects { AssignToProject }
import from ...services.tasks.tasks { UpdateTask, DeleteTask }
import from ...services.flowlines.flowlines {
    GetFlowLine,
    ApplyTemplate,
    SaveStep,
    DeleteStep,
    DeleteFlowLine,
    LinkTransition,
    LabelTransition,
    UnlinkTransition,
    SetStepRules,
    RenameFlowLine,
    ListStepTasks
}
import from ...lib.workspace { loadWorkspace, forgetWorkspace, cachedProjects }
import from ...lib.flowMoves {
    flowMoveVersion,
    advanceFlowMove,
    pendingFlowMoves,
    flowMovesBusy,
    queueFlowMove,
    flushFlowMoves,
    acknowledgeFlowMoves
}
import from ...lib.filters { defaultProject }
import from ...lib.project { currentProject, pickProject }
import from ...components.common.ProjectHead { ProjectHead }
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
import from ...components.flowlines.FlowTitle { FlowTitle }
import from ...components.flowlines.FlowToolbar { FlowToolbar }
import from ...components.flowlines.FlowKey { FlowKey }
import from ...components.flowlines.FlowSkeleton { FlowSkeleton }
import from ...components.flowlines.NewStepForm { NewStepForm }
import from ...components.flowlines.EditGuide { EditGuide }
import from ...components.flowlines.WipeDialog { WipeDialog }
import from ...components.board.TaskDialog { TaskDialog }
import from ...components.flowlines.geometry {
    hitRect,
    nodeRects,
    stepXY,
    clampZoom,
    clampCoord,
    nextStop,
    detailOf,
    NODE_W,
    NODE_H
}
import from ...components.flowlines.kinds { DOT_FILL, colorKey, moveRefusal }
import from ...components.ui.button { Button }
import from ...components.common.Reveal { Reveal }
import from ...components.common.LoadFailed { LoadFailed }
import from ...components.ui.sheet { Sheet, SheetContent, SheetTitle, SheetDescription }
import from "sonner" { toast }
import from "react" { useEffect, useLayoutEffect }
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
         "notes": "",
         "issue": "",
         "pr": "",
         "reviewer": "none",
         "review_due": ""
     },
     # Step kinds whose task dialog offers the reviewer fields, as on the board.
     HANDOFF_KINDS: list[str] = ["handoff", "blocked"],
     KIND_ORDER: list[str] = ["start", "active", "handoff", "blocked", "done"],
     # The step sheet sits over the canvas's right side at this width (27.5rem).
     PANEL_W: float = 440.0,
     # How far past a frame edge a pan may carry the drawing's edge, in px.
     PAN_MARGIN: float = 24.0;


def:pub FlowLinePage -> JsxPage {
    has steps: list[StepView] = [],
        projects: list[Project] = cachedProjects(),
        # The org's roles and roster, for the Lane view's labels and the
        # task dialog's people.
        roleRows: list[RoleView] = [],
        roleMembers: list[MemberView] = [],
        # Viewer projection: "flow" renders the hand-drawn positions,
        # "lanes" a computed swimlane layout (lane = owner role, column =
        # flow depth). Persisted per browser; editing always uses flow.
        lineView: str = "flow",
        # The project on screen, one always: lib/project's pick, shared with
        # the sidebar and the other pages. "" until the default is known.
        projectId: str = currentProject(),
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
        # The selected transition's draft (label, carries, trigger,
        # github_label), re-seeded from the edge on every selection.
        edgeForm: dict[str, str] = {},
        form: dict[str, str] = BLANK_STEP,
        saving: bool = False,
        confirmDelete: bool = False,
        # Deleting the whole flow line confirms in a dialog that spells out
        # what goes and what stays.
        confirmWipe: bool = False,
        # The same dialog, asked by Templates: this line goes before a new one.
        wipeForTemplate: bool = False,
        wiping: bool = False,
        # Add step opens a naming panel first: the step only exists once the
        # user has called it something, never as a placeholder card.
        creatingStep: bool = False,
        # Canvas positions awaiting a save refresh, plus the active drag draft.
        live: dict[str, list[float]] = pendingFlowMoves(),
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
        # Writes are shared across mounts; these refs only guard this view.
        moveSavingRef: Ref[any] = Ref(),
        moveMountedRef: Ref[any] = Ref(),
        moveRefreshRef: Ref[any] = Ref(),
        wireRef: Ref[any] = Ref(),
        gestureRef: Ref[any] = Ref(),
        activePointerRef: Ref[any] = Ref(),
        # Only pressed touch contacts participate in a pinch.
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

    # A previous flow page may still be saving when this one mounts.
    useEffect(
        lambda {
            moveMountedRef.current = True;
            onSaved: any = lambda { saveMoves(); };
            window.addEventListener("flowline:moves-saved", onSaved);
            return lambda {
                moveMountedRef.current = False;
                window.removeEventListener("flowline:moves-saved", onSaved);
            };
        },
        []
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

    # A project picked anywhere else (the sidebar) redraws this page.
    useEffect(
        lambda {
            onPick: any = lambda (e: any) { adoptProject(str(e.detail or "")); };
            window.addEventListener("flowline:project", onPick);
            return lambda { window.removeEventListener("flowline:project", onPick); };
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
    async def reload(pid: str, moveVersion: int = -1) -> bool;
    async def retryLoad -> None;
    async def adoptProject(v: str) -> None;
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
    def selectEdge(key: str, fields: dict[str, str]) -> None;
    def editEdge(key: str, value: str) -> None;
    async def commitEdge(fromId: str, toId: str, fields: dict[str, str]) -> None;
    async def commitRule(key: str, on: bool) -> None;
    def selectStep(stepId: str) -> None;
    def editStep(stepId: str) -> None;
    def openTemplates -> None;
    def askWipe -> None;
    def armConnect -> None;
    def clearCanvas -> None;
    def setField(key: str, value: str) -> None;
    def zoomStep(dirn: int) -> None;
    def zoomActual -> None;
    def zoomTo(z: float, sx: float, sy: float) -> None;
    def applyPan(x: float, y: float) -> None;
    def panAxis(
        want: float, lo: float, hi: float, v0: float, v1: float, pinned: bool
    ) -> float;
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
    def discardDrag -> None;
    async def endDrag(e: any) -> None;
    async def cancelDrag(e: any) -> None;
    async def finishPointer(e: any, canceled: bool) -> None;
    async def saveMoves -> None;

    peekRef.current = peekId;
    if moveMountedRef.current is None {
        moveMountedRef.current = True;
    }
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
    # Roles the line names as owners, for the heading's summary.
    ownerNames: list[str] = [];
    for s in steps {
        owner = s.owner.strip() if s.owner else "";
        if owner and owner != "anyone" and owner not in ownerNames {
            ownerNames.append(owner);
        }
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

    projectName = "";
    for p in activeProjects {
        if jid(p) == projectId {
            projectName = p.name;
        }
    }
    peekScope = "in " + projectName if projectName else "in this project";
    # The task dialog offers exactly the steps the canvas shows, left to
    # right, which is the order the board builds its columns in too.
    stepOrder = [st for st in steps];
    stepOrder.sort(key=lambda (st: StepView) { st.sort_order; });
    stepOrder.sort(key=lambda (st: StepView) { st.x; });
    colKeys: list[str] = [];
    colLabels: list[str] = [];
    handoffKeys: list[str] = [];
    placeOf: dict[str, str] = {};
    for (stepAt, st) in enumerate(stepOrder) {
        placeOf[st.id] = "step " + str(stepAt + 1) + " of " + str(len(stepOrder));
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
    linkNoun = "arrow" if linkCount == 1 else "arrows";
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
    # The diagram fills the window below the head, toolbar and key.
    canvasH = "max(20rem, calc(100dvh - 17rem))"
        if narrow
        else "max(24rem, calc(100dvh - 12.75rem))";

    def toolbarRow(pending: bool) -> JsxElement {
        return
            <FlowToolbar
                editing={editing and not pending}
                narrow={narrow}
                showList={showList}
                phoneView={phoneView}
                lineView={lineView}
                zoom={zoom}
                pending={pending}
                busy={saving or creatingStep}
                onMode={switchMode}
                onPhoneView={lambda (v: str) { phoneView = v; }}
                onView={switchView}
                onZoom={zoomStep}
                onActual={zoomActual}
                onFit={lambda {
                    fittedRef.current = False;
                    fitZoom();
                }}
                onTemplates={openTemplates}
                onAdd={addStep}
                onRename={startRename}
                onWipe={askWipe}
            />;
    }

    def loadFrame -> JsxElement {
        return
            <div className="flex min-w-0 flex-col gap-3" aria-busy="true">
                {toolbarRow(True)}
                <FlowSkeleton canvasH={canvasH} showKey={not showList}/>
            </div>;
    }

    return
        <div className="flex w-full min-w-0 flex-col gap-3">
            <ProjectHead
                projects={activeProjects}
                project={projectId}
                view="flowline"
                actions={None
                    if showFailed or showPicker
                    else <FlowTitle
                        lineName={lineName}
                        steps={len(steps)}
                        transitions={linkCount}
                        roles={len(ownerNames)}
                        renaming={renaming}
                        nameDraft={nameDraft}
                        pending={loading}
                        onDraft={lambda (v: str) { nameDraft = v; }}
                        onRename={saveRename}
                    />}
            />
            <Reveal ready={not loading} frame={loadFrame()} className="min-w-0">
                {if showFailed {
                    <LoadFailed
                        key="failed"
                        title="Could not load the flow line"
                        onRetry={retryLoad}
                        retrying={retrying}
                    />
                } elif showPicker {
                    <TemplatePicker
                        key="picker"
                        applying={applying}
                        onPick={pickTemplate}
                        onScratch={startScratch}
                    />
                } else {
                    <div key="line" className="flex min-w-0 flex-col gap-3">
                        {toolbarRow(False)}
                        <div
                            className="surface flex min-w-0 flex-col overflow-hidden rounded-xl"
                        >
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
                                            onPointerCancel={cancelDrag}
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
                                                connectFrom={connectFrom
                                                    if editing
                                                    else ""}
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
                                                edgeForm={edgeForm}
                                                onSelectEdge={selectEdge}
                                                onEdgeField={editEdge}
                                                onSaveEdge={commitEdge}
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
                                                    <p
                                                        className="text-[13px] text-pretty"
                                                    >
                                                        <span className="font-semibold">
                                                            {"Connecting from "
                                                                + connectTitle
                                                                + "."}
                                                        </span>
                                                        <span
                                                            className="text-text-secondary"
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
                                                className="absolute inset-y-0 right-0 z-40 flex w-[27.5rem] max-w-full flex-col overflow-hidden border-l shadow-lg"
                                            >
                                                <StepTasksPanel
                                                    className="h-full"
                                                    step={peeked[0]}
                                                    place={placeOf[peeked[0].id]
                                                        if peeked[0].id in placeOf
                                                        else ""}
                                                    tasks={peekTasks}
                                                    loading={peekLoading}
                                                    total={peekTotal}
                                                    hasMore={peekMore}
                                                    loadingMore={peekLoadingMore}
                                                    onMore={morePeek}
                                                    scope={peekScope}
                                                    onOpenTask={openTask}
                                                    onEdit={lambda { editStep(
                                                        peeked[0].id
                                                    ); }}
                                                    onClose={closePeek}
                                                />
                                            </div>
                                        }}
                                    </div>
                                    {if editing {
                                        <div
                                            key="inspector"
                                            className="flex min-h-0 min-w-0 flex-col border-t bg-card sm:w-96 sm:shrink-0 sm:border-t-0 sm:border-l"
                                            style={{
                                                "maxHeight": "none"
                                                    if narrow
                                                    else canvasH
                                            }}
                                        >
                                            {if creatingStep {
                                                <NewStepForm
                                                    key="create"
                                                    name={form["name"] or ""}
                                                    saving={saving}
                                                    onName={lambda (v: str) { setField(
                                                        "name", v
                                                    ); }}
                                                    onCommit={commitName}
                                                    onCancel={lambda { creatingStep = False; }}
                                                />
                                            } elif len(picked) > 0 {
                                                <StepInspector
                                                    key={picked[0].id}
                                                    step={picked[0]}
                                                    place={placeOf[picked[0].id]
                                                        if picked[0].id in placeOf
                                                        else ""}
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
                                                    onRule={commitRule}
                                                    onClose={clearCanvas}
                                                />
                                            } else {
                                                <EditGuide key="howto" issues={issues}/>
                                            }  }
                                        </div>
                                    }}
                                </div>
                            } }
                            {if not showList {
                                <FlowKey
                                    key="legend"
                                    usedKinds={usedKinds}
                                    showBack={hasBack or editing}
                                    issues={[] if editing else issues}
                                    roles={roleList}
                                />
                            }}
                        </div>
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
                            place={placeOf[peeked[0].id]
                                if peeked[0].id in placeOf
                                else ""}
                            tasks={peekTasks}
                            loading={peekLoading}
                            total={peekTotal}
                            hasMore={peekMore}
                            loadingMore={peekLoadingMore}
                            closable={False}
                            onMore={morePeek}
                            scope={peekScope}
                            onOpenTask={openTask}
                            onEdit={lambda { editStep(peeked[0].id); }}
                            onClose={closePeek}
                        />
                    }}
                </SheetContent>
            </Sheet>
            <WipeDialog
                open={confirmWipe}
                summary={wipeSummary}
                wiping={wiping}
                forTemplate={wipeForTemplate}
                onCancel={lambda { confirmWipe = False; }}
                onConfirm={deleteFlowLine}
            />
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
            />
        </div>;
}
