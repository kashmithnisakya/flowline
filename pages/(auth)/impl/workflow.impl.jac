"""Implementations for the Workflow page. Loaders and mutations reload through
GetWorkflow rather than patching local state: the walker is the only place the
prev/next truth lives. Locals are read before any await (stale-snapshot rule).
"""

impl WorkflowPage.boot -> None {
    loadMeta();
    # The board persists its project filter under the same key, so the two
    # tabs stay on the same project rather than each keeping a private idea
    # of what you are looking at.
    stored = localStorage.getItem("standup_project") or "";
    picked = stored or "all";
    projectId = picked;
    # The viewer projection survives reloads the same way the project
    # filter does. Anything but the exact "lanes" token means flow.
    storedView = localStorage.getItem("standup_wf_view") or "";
    if storedView == "lanes" {
        wfView = "lanes";
    }
    try {
        result = root spawn ListProjects();
        projects = result.reports[0] if result.reports else [];
    } except Exception as e {
        projects = [];
    }
    # Roles and roster feed the who-does-what strip; the diagram loads
    # fine without them, so failure here stays quiet.
    try {
        roleResult = root spawn ListRoles();
        roleRows = roleResult.reports[0] if roleResult.reports else [];
        memResult = root spawn ListMembers();
        roleMembers = memResult.reports[0] if memResult.reports else [];
    } except Exception as e {
        roleRows = [];
    }
    await reload(picked);
}

impl WorkflowPage.reload(pid: str) -> None {
    try {
        result = root spawn GetWorkflow(project_id=pid if pid and pid != "all" else "");
        steps = result.reports[0] if result.reports else [];
    } except Exception as e {
        toast("Failed to load your workflow");
    }
    loading = False;
    # Open showing the whole graph rather than a corner of it.
    fitZoom();
}

impl WorkflowPage.peekStep(stepId: str) -> None {
    # Fetching per click rather than holding every task in page state: the
    # server already owns the placement rule, and a workspace can have far
    # more tasks than the panel will ever show.
    peekId = stepId;
    peekTasks = [];
    peekLoading = True;
    pid = projectId;
    try {
        result = root spawn ListStepTasks(
            step_id=stepId, project_id=pid if pid and pid != "all" else ""
        );
        peekTasks = result.reports[0] if result.reports else [];
    } except Exception as e {
        toast("Could not load the work on that step");
    }
    peekLoading = False;
}

impl WorkflowPage.selectProject(v: str) -> None {
    projectId = v;
    localStorage.setItem("standup_project", v);
    await reload(v);
}

impl WorkflowPage.loadMeta -> None {
    try {
        result = root spawn GetWorkflowMeta();
        payload = result.reports[0] if result.reports else None;
        if payload and payload["name"] {
            wfName = payload["name"];
        }
    } except Exception as e {
        wfName = wfName;
    }
}

impl WorkflowPage.switchView(v: str) -> None {
    chosen = "lanes" if v == "lanes" else "flow";
    wfView = chosen;
    localStorage.setItem("standup_wf_view", chosen);
}

impl WorkflowPage.lanePlan -> dict[str, any] {
    # The Lane view projection, recomputed on demand so the fit math and
    # the render can never disagree. Editing always measures the freeform
    # drawing, so the plan is empty there.
    if wfView != "lanes" or editing or len(steps) == 0 {
        return {"positions": {}, "lanes": []};
    }
    return laneLayout(steps, roleRows, roleMembers);
}

impl WorkflowPage.pickTemplate(key: str) -> None {
    applying = key;
    try {
        result = root spawn ApplyTemplate(template_key=key);
        fresh = result.reports[0] if result.reports else [];
        if len(fresh) > 0 {
            steps = fresh;
            editing = True;
            toast("Your workflow is in, drag anything to make it yours");
        } else {
            toast("That template could not be applied");
        }
    } except Exception as e {
        toast("Failed to set up the workflow");
    }
    applying = "";
}

impl WorkflowPage.startScratch -> None {
    scratch = True;
    editing = True;
}

impl WorkflowPage.startRename -> None {
    nameDraft = wfName;
    renaming = True;
}

impl WorkflowPage.saveRename -> None {
    value = nameDraft.strip();
    renaming = False;
    if not value or value == wfName {
        return;
    }
    try {
        result = root spawn RenameWorkflow(name=value);
        payload = result.reports[0] if result.reports else None;
        if payload and payload["name"] {
            wfName = payload["name"];
        }
    } except Exception as e {
        toast("Failed to rename the workflow");
    }
}

impl WorkflowPage.addStep -> None {
    # Open the naming panel; nothing is created until the user commits a
    # name of their own. No placeholder steps.
    creatingStep = True;
    selectedId = "";
    selectedEdge = "";
    confirmDelete = False;
    form = {"name": "", "kind": "active", "color": "indigo", "owner": ""};
}

impl WorkflowPage.commitName -> None {
    name = (form["name"] or "").strip();
    if not name {
        return;
    }
    # Enter auto-repeat fires this faster than the walker round-trips, and a
    # `saving` read here would be a stale render-time snapshot, so the
    # in-flight latch lives on a ref.
    if busyRef.current {
        return;
    }
    busyRef.current = True;
    if creatingStep {
        # Drop the new card at the left edge, under the lowest existing one
        # (104 = node height + a row of breathing room).
        ny = 40.0;
        for s in steps {
            if s.y + 104.0 > ny {
                ny = s.y + 104.0;
            }
        }
        saving = True;
        try {
            result = root spawn SaveStep(
                name=name,
                kind=form["kind"] or "active",
                color=form["color"] or "",
                owner=form["owner"] or "",
                x=40.0,
                y=ny
            );
            made = result.reports[0] if result.reports else None;
            await reload(projectId);
            creatingStep = False;
            if made {
                selectedId = made.id;
                form = {
                    "name": made.name,
                    "kind": made.kind,
                    "color": made.color,
                    "owner": made.owner
                };
            }
        } except Exception as e {
            toast("Failed to add the step");
        }
        saving = False;
        busyRef.current = False;
        return;
    }
    if not selectedId {
        busyRef.current = False;
        return;
    }
    # Skip the walker when the blur changed nothing.
    current = [
        s
        for s in steps
        if s.id == selectedId
    ];
    owner = (form["owner"] or "").strip();
    if current and current[0].name == name and current[0].owner == owner {
        busyRef.current = False;
        return;
    }
    saving = True;
    try {
        # SaveStep reads empty as "keep", so a lone space clears the owner.
        root spawn SaveStep(step_id=selectedId, name=name, owner=owner or " ");
        await reload(projectId);
    } except Exception as e {
        toast("Failed to update the step");
    }
    saving = False;
    busyRef.current = False;
}

impl WorkflowPage.commitField(key: str, value: str) -> None {
    if not selectedId {
        return;
    }
    try {
        if key == "kind" {
            root spawn SaveStep(step_id=selectedId, kind=value);
        } elif key == "color" {
            root spawn SaveStep(step_id=selectedId, color=value);
        } elif key == "owner" {
            # SaveStep reads empty as "keep", so a lone space clears.
            root spawn SaveStep(
                step_id=selectedId, owner=value if value.strip() else " "
            );
        }
        await reload(projectId);
    } except Exception as e {
        toast("Failed to update the step");
    }
}

impl WorkflowPage.deleteStep -> None {
    if not selectedId {
        return;
    }
    # First click arms, the second one deletes. The transitions touching the
    # step die with it.
    if not confirmDelete {
        confirmDelete = True;
        return;
    }
    saving = True;
    gone = selectedId;
    try {
        result = root spawn DeleteStep(step_id=gone);
        payload = result.reports[0] if result.reports else None;
        if payload and not payload["ok"] {
            confirmDelete = False;
            saving = False;
            toast(payload["message"] or "That step cannot be deleted.");
            return;
        }
        selectedId = "";
        selectedEdge = "";
        confirmDelete = False;
        if connectFrom == gone {
            connectFrom = "";
        }
        await reload(projectId);
        toast("Step deleted");
    } except Exception as e {
        toast("Failed to delete the step");
    }
    saving = False;
}

impl WorkflowPage.linkSteps(fromId: str, toId: str) -> None {
    try {
        result = root spawn LinkTransition(from_id=fromId, to_id=toId);
        payload = result.reports[0] if result.reports else None;
        if payload and payload["ok"] {
            await reload(projectId);
            if not payload["duplicate"] {
                toast(
                    "Connected",
                    {
                        "action": {
                            "label": "Undo",
                            "onClick": lambda { deleteEdge(fromId, toId); }
                        }
                    }
                );
            }
        } elif payload {
            toast(payload["message"] or "That transition is not allowed.");
        }
    } except Exception as e {
        toast("Could not connect those steps");
    }
}

impl WorkflowPage.selectEdge(key: str, said: str) -> None {
    # Seeding the draft from the edge itself is what makes the editor an
    # edit rather than a retype, and it is why nothing has to clear the
    # draft when the selection moves.
    selectedEdge = key;
    edgeDraft = said;
}

impl WorkflowPage.commitEdgeLabel(fromId: str, toId: str, said: str) -> None {
    # An empty `said` is a clear, not a no-op, which is why this goes
    # through LabelTransition rather than re-drawing the arrow.
    try {
        result = root spawn LabelTransition(from_id=fromId, to_id=toId, label=said);
        payload = result.reports[0] if result.reports else None;
        if payload and payload["ok"] {
            edgeDraft = payload["label"];
            selectedEdge = "";
            await reload(projectId);
            toast("Label removed" if not payload["label"] else "Label saved");
        } else {
            toast("Could not update that label");
        }
    } except Exception as e {
        toast("Could not update that label");
    }
}

impl WorkflowPage.deleteEdge(fromId: str, toId: str) -> None {
    selectedEdge = "";
    try {
        root spawn UnlinkTransition(from_id=fromId, to_id=toId);
        await reload(projectId);
    } except Exception as e {
        toast("Could not remove that transition");
    }
}

impl WorkflowPage.selectStep(stepId: str) -> None {
    # A drag ends with a click on the node it started from, so the drag marks
    # that one click to be ignored; without this, moving a step also selects
    # it and finishing a wire also re-fires the connect.
    if swallowRef.current {
        swallowRef.current = False;
        return;
    }
    # A click while armed means "flow into this one"; otherwise it selects.
    if connectFrom and connectFrom != stepId {
        source = connectFrom;
        connectFrom = "";
        linkSteps(source, stepId);
        return;
    }
    selectedId = stepId;
    selectedEdge = "";
    confirmDelete = False;
    creatingStep = False;
    picked = [
        s
        for s in steps
        if s.id == stepId
    ];
    if picked {
        form = {
            "name": picked[0].name,
            "kind": picked[0].kind,
            "color": picked[0].color,
            "owner": picked[0].owner
        };
    }
}

impl WorkflowPage.armConnect -> None {
    if selectedId {
        connectFrom = selectedId;
        selectedEdge = "";
    }
}

impl WorkflowPage.clearCanvas -> None {
    # A drag whose mousedown and mouseup land on different elements fires the
    # click on their common ancestor, the canvas, so the swallow flag must be
    # consumable here too or finishing a wire wipes the selection it just made.
    if swallowRef.current {
        swallowRef.current = False;
        return;
    }
    connectFrom = "";
    selectedEdge = "";
    selectedId = "";
    confirmDelete = False;
    creatingStep = False;
}

impl WorkflowPage.setField(key: str, value: str) -> None {
    # NOTE: `{**form, key: value}` compiles to a JS object literal with a
    # LITERAL "key" property, which freezes every bound input. Copy, then
    # subscript.
    updated = {** form};
    updated[key] = value;
    form = updated;
    # Kind, color and owner are pick-once fields: commit immediately. The
    # name keeps typing local and commits on blur or Enter instead.
    if key == "kind" or key == "color" or key == "owner" {
        commitField(key, value);
    }
}

# The diagram's true bounding box in canvas px: [minX, minY, maxX, maxY].
# canvasSize measures from the ORIGIN plus the drag margin, so fitting against
# it would shrink a diagram that starts away from the corner.
def contentBounds(steps: list[StepView], live: dict[str, list[float]]) -> list[float] {
    minX = 0.0;
    minY = 0.0;
    maxX = 0.0;
    maxY = 0.0;
    first = True;
    for s in steps {
        pos = stepXY(s, live);
        if first or pos[0] < minX {
            minX = pos[0];
        }
        if first or pos[1] < minY {
            minY = pos[1];
        }
        if first or pos[0] + NODE_W > maxX {
            maxX = pos[0] + NODE_W;
        }
        if first or pos[1] + NODE_H > maxY {
            maxY = pos[1] + NODE_H;
        }
        first = False;
    }
    return [minX, minY, maxX, maxY];
}


# Far enough out to see a sprawling flow, far enough in to read a card.
def clampZoom(v: float) -> float {
    if v < 0.3 {
        return 0.3;
    }
    if v > 2.0 {
        return 2.0;
    }
    return v;
}

impl WorkflowPage.zoomBy(delta: float) -> None {
    current = float(zoomRef.current) if zoomRef.current else zoom;
    z = clampZoom(current + delta);
    zoomRef.current = z;
    zoom = z;
    recenterPan();
}

impl WorkflowPage.viewBounds -> list[float] {
    # What the fit and the centering measure: the drawn diagram in Flow view,
    # the computed lane layout in Lane view. Lane mode includes the label
    # gutter and the last band, or the fit centers the labels off-screen.
    plan = lanePlan();
    laneBands: list[dict[str, any]] = plan["lanes"];
    laneFit = len(laneBands) > 0;
    lanePose: dict[str, list[float]] = plan["positions"];
    bounds = contentBounds(steps, lanePose if laneFit else live);
    if laneFit {
        bounds[0] = 0.0;
        bounds[1] = 0.0;
        deepest = 0.0;
        for b in laneBands {
            bandEdge = float(b["y"]) + float(b["h"]);
            if bandEdge > deepest {
                deepest = bandEdge;
            }
        }
        if deepest > bounds[3] {
            bounds[3] = deepest;
        }
    }
    return bounds;
}

impl WorkflowPage.fitZoom -> None {
    view: any = viewportRef.current;
    if not view {
        zoomRef.current = 1.0;
        zoom = 1.0;
        return;
    }
    bounds = viewBounds();
    spanW = bounds[2] - bounds[0];
    spanH = bounds[3] - bounds[1];
    # The editor floats over the canvas, so the space it covers is not space
    # a card can use: fit into what is actually visible.
    # Reserved for the whole of edit mode, not per selection: re-fitting
    # every time a card is clicked would make the zoom jump under the cursor.
    panel = 336.0 if editing else 0.0;
    boxW = float(view.clientWidth) - 48.0 - panel;
    boxH = float(view.clientHeight) - 48.0;
    if spanW <= 0.0 or spanH <= 0.0 or boxW <= 0.0 or boxH <= 0.0 {
        zoomRef.current = 1.0;
        zoom = 1.0;
        return;
    }
    byW = boxW / spanW;
    byH = boxH / spanH;
    best = byW if byW < byH else byH;
    # The viewer fills the box: a diagram drawn small should read large on a
    # large screen, within reason (1.25x, past that cards look inflated, not
    # close). The editor stays at 1:1 so drawing coordinates match what the
    # author placed.
    cap = 1.0 if editing else 1.25;
    if best > cap {
        best = cap;
    }
    zoomRef.current = clampZoom(best);
    zoom = clampZoom(best);
    recenterPan();
    # Arm transitions on the NEXT frame, so this fit's own transform change
    # can never animate: the first thing the user sees is the final position.
    if not placed and len(steps) > 0 {
        window.requestAnimationFrame(lambda { placed = True; });
    }
}

impl WorkflowPage.recenterPan -> None {
    # Center the diagram's bounding box in the visible part of the viewport.
    # Screen-px offsets applied before the scale, so pointerXY (which reads
    # the translated surface's own rect) needs no changes.
    view: any = viewportRef.current;
    if not view or len(steps) == 0 {
        panX = 0.0;
        panY = 0.0;
        return;
    }
    z = float(zoomRef.current) if zoomRef.current else 1.0;
    bounds = viewBounds();
    minX = bounds[0];
    minY = bounds[1];
    maxX = bounds[2];
    maxY = bounds[3];
    panel = 336.0 if editing else 0.0;
    availW = float(view.clientWidth) - panel;
    availH = float(view.clientHeight);
    # Clamp the content's visible EDGE, not the raw offset: the offset goes
    # negative for content whose coordinates start away from the origin. Only
    # a diagram larger than the box pins to the top-left padding.
    edgeX = (availW - (maxX - minX) * z) / 2.0;
    edgeY = (availH - (maxY - minY) * z) / 2.0;
    if edgeX < 16.0 {
        edgeX = 16.0;
    }
    if edgeY < 16.0 {
        edgeY = 16.0;
    }
    panX = edgeX - minX * z;
    panY = edgeY - minY * z;
}

impl WorkflowPage.pointerXY(e: MouseEvent) -> list[float] {
    surface: any = canvasRef.current;
    if not surface or not surface.getBoundingClientRect {
        return [-1.0, -1.0];
    }
    # The surface is CSS-scaled, so its rect is in screen px while every
    # position we compare against is in canvas px. Undo the scale here and
    # the whole hit-test/drag layer stays zoom-agnostic.
    box: any = surface.getBoundingClientRect();
    scale = float(zoomRef.current) if zoomRef.current else 1.0;
    return [
        (float(e.clientX) - float(box.left)) / scale,
        (float(e.clientY) - float(box.top)) / scale
    ];
}

impl WorkflowPage.beginDrag(e: MouseEvent) -> None {
    if connectFrom {
        return;
    }
    pos = pointerXY(e);
    hit = hitStep(stepsRef.current or [], liveRef.current or {}, pos[0], pos[1]);
    if not hit {
        return;
    }
    e.preventDefault();
    step = hit["step"] as StepView;
    if hit["onEdge"] {
        # The border is the port: dragging off it draws a transition.
        # Grabbing a port also cancels an open New step panel, the panel and
        # the inspector share `form`, so leaving it open would overwrite the
        # half-typed name and let Add to canvas create a duplicate.
        wireRef.current = step.id;
        connectFrom = step.id;
        selectedId = step.id;
        selectedEdge = "";
        confirmDelete = False;
        creatingStep = False;
        form = {
            "name": step.name,
            "kind": step.kind,
            "color": step.color,
            "owner": step.owner
        };
        return;
    }
    at = stepXY(step, liveRef.current or {});
    # lx/ly track the latest dragged position on the ref itself, seeded to
    # the start so endDrag can always read them without touching `live`.
    dragRef.current = {
        "id": step.id,
        "px": pos[0],
        "py": pos[1],
        "x": at[0],
        "y": at[1],
        "lx": at[0],
        "ly": at[1],
        "moved": False
    };
}

impl WorkflowPage.moveDrag(e: MouseEvent) -> None {
    surface: any = e.currentTarget;
    drag = dragRef.current;
    if surface {
        if drag {
            surface.style.cursor = "grabbing";
        } elif wireRef.current or connectFrom {
            surface.style.cursor = "crosshair";
        } else {
            probe = pointerXY(e);
            over = hitStep(
                stepsRef.current or [], liveRef.current or {}, probe[0], probe[1]
            );
            if over {
                surface.style.cursor = "crosshair" if over["onEdge"] else "grab";
            } else {
                surface.style.cursor = "";
            }
        }
    }
    if not drag {
        return;
    }
    pos = pointerXY(e);
    nx = drag["x"] + (pos[0] - drag["px"]);
    ny = drag["y"] + (pos[1] - drag["py"]);
    if nx < 0.0 {
        nx = 0.0;
    }
    if ny < 0.0 {
        ny = 0.0;
    }
    if abs(nx - drag["x"]) > 3.0 or abs(ny - drag["y"]) > 3.0 {
        drag["moved"] = True;
    }
    # The ref carries the authoritative position: `live` only drives the
    # render, and a release can beat React's state flush, leaving liveRef
    # without this id.
    drag["lx"] = nx;
    drag["ly"] = ny;
    updated = {** live};
    updated[drag["id"]] = [nx, ny];
    live = updated;
}

impl WorkflowPage.endDrag(e: MouseEvent) -> None {
    wiring = wireRef.current;
    if wiring {
        wireRef.current = None;
        pos = pointerXY(e);
        hit = hitStep(stepsRef.current or [], liveRef.current or {}, pos[0], pos[1]);
        landed = (hit["step"] as StepView).id if hit else "";
        if not landed or landed == wiring {
            # Released on empty canvas: stay armed so the click path can
            # finish the connection instead of silently losing the aim. The
            # gesture still generates one click on the canvas, so swallow it
            # or clearCanvas would disarm immediately.
            swallowRef.current = True;
            return;
        }
        swallowRef.current = True;
        connectFrom = "";
        await linkSteps(wiring, landed);
        return;
    }
    drag = dragRef.current;
    if not drag {
        return;
    }
    dragRef.current = None;
    if not drag["moved"] {
        # Below the move threshold: drop the override so a later render
        # cannot keep drawing the card at a position nothing persisted.
        live = {};
        return;
    }
    swallowRef.current = True;
    # Read the coordinates off the drag ref, not off `live`: a fast flick can
    # release before React commits the state update, and the old
    # `if not target` guard was dead anyway (an empty list is truthy in JS),
    # so a miss used to send undefined and snap the card to the origin.
    nx = float(drag["lx"]);
    ny = float(drag["ly"]);
    try {
        root spawn MoveStep(step_id=drag["id"], x=nx, y=ny);
        await reload(projectId);
    } except Exception as err {
        toast("Failed to save the position");
    }
    live = {};
}
