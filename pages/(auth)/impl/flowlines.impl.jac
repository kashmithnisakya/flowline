"""Implementations for the Flow line page. Loaders and mutations reload through
GetFlowLine rather than patching local state: the walker is the only place the
prev/next truth lives. Locals are read before any await (stale-snapshot rule).
"""

impl FlowLinePage.boot -> None {
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
        lineView = "lanes";
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

impl FlowLinePage.reload(pid: str) -> None {
    try {
        result = root spawn GetFlowLine(project_id=pid if pid and pid != "all" else "");
        steps = result.reports[0] if result.reports else [];
    } except Exception as e {
        toast("Failed to load your flow line");
    }
    loading = False;
    # Open showing the whole graph rather than a corner of it.
    fitZoom();
}

impl FlowLinePage.peekStep(stepId: str) -> None {
    # Clicking the open step again closes the panel, so one control both
    # opens and dismisses it.
    if peekId == stepId {
        closePeek();
        return;
    }
    peekId = stepId;
    peekTasks = [];
    peekLoading = True;
    await refreshPeek(stepId, projectId);
    peekLoading = False;
}

impl FlowLinePage.refreshPeek(stepId: str, pid: str) -> None {
    # Fetching per click rather than holding every task in page state: the
    # server already owns the placement rule, and a workspace can have far
    # more tasks than the panel will ever show, so it comes a page at a
    # time. Quiet on purpose: a save refetches through here without
    # flashing the skeletons again.
    if not stepId {
        return;
    }
    # Reload as many pages as were open, so a save does not collapse rows
    # the user had already paged through.
    wanted = peekPage if peekPage > 1 else 1;
    rows: list[TaskView] = [];
    try {
        step = 1;
        while step <= wanted and step <= 20 {
            result = root spawn ListStepTasks(
                step_id=stepId,
                project_id=pid if pid and pid != "all" else "",
                page=step,
                page_size=50
            );
            got = result.reports[0] if result.reports else None;
            if not got {
                break;
            }
            rows = rows + got.rows;
            peekTotal = got.total;
            peekMore = got.has_more;
            peekPage = step;
            if not got.has_more {
                break;
            }
            step = step + 1;
        }
        peekTasks = rows;
    } except Exception as e {
        toast("Could not load the work on that step");
    }
}

impl FlowLinePage.morePeek -> None {
    # The next page appends; the id and project are read before the await
    # so a step change mid-flight cannot mix two steps' rows.
    stepId = peekId;
    pid = projectId;
    wanted = peekPage + 1;
    if not stepId or peekLoadingMore {
        return;
    }
    peekLoadingMore = True;
    have = [t for t in peekTasks];
    try {
        result = root spawn ListStepTasks(
            step_id=stepId,
            project_id=pid if pid and pid != "all" else "",
            page=wanted,
            page_size=50
        );
        got = result.reports[0] if result.reports else None;
        if got and peekRef.current == stepId {
            peekTasks = have + got.rows;
            peekTotal = got.total;
            peekMore = got.has_more;
            peekPage = wanted;
        }
    } except Exception as e {
        toast("Could not load more of that step");
    }
    peekLoadingMore = False;
}

impl FlowLinePage.closePeek -> None {
    peekId = "";
    peekTasks = [];
    peekLoading = False;
    peekTotal = 0;
    peekMore = False;
    peekPage = 0;
}

impl FlowLinePage.stepName(key: str) -> str {
    for st in steps {
        if st.id == key {
            return st.name;
        }
    }
    return "";
}

impl FlowLinePage.mappedStatus(key: str) -> str {
    # Nothing here learns what a step is: the kind maps to the legacy status
    # every other surface still keys on.
    for st in steps {
        if st.id == key {
            return KIND_STATUS[st.kind] if st.kind in KIND_STATUS else "In Progress";
        }
    }
    return "In Progress";
}

impl FlowLinePage.openTask(tid: str) -> None {
    found = [
        t
        for t in peekTasks
        if t.id == tid
    ];
    if len(found) == 0 {
        return;
    }
    picked = found[0];
    # A task with no step of its own landed here by kind, so the panel's
    # step is the honest answer for the dialog's Step select.
    key = peekId;
    for st in steps {
        if st.id == picked.step_id {
            key = st.id;
        }
    }
    editTaskId = picked.id;
    taskForm = {
        "title": picked.title,
        "category": picked.category,
        "project": picked.project_id or "none",
        "priority": picked.priority,
        "status": key,
        "due_date": picked.due_date,
        "notes": picked.notes,
        "issue": picked.issue_link,
        "pr": picked.pr_link,
        "reviewer": picked.reviewer_id or "none",
        "review_due": picked.review_due
    };
    taskAssignees = picked.assignee_ids;
    taskOpen = True;
}

impl FlowLinePage.setTaskField(key: str, value: str) -> None {
    # A computed key does not survive a dict-literal spread: `{**taskForm,
    # key: value}` writes a literal "key" property and the input freezes.
    updated = {** taskForm};
    updated[key] = value;
    taskForm = updated;
}

impl FlowLinePage.toggleTaskAssignee(memberId: str) -> None {
    if memberId in taskAssignees {
        taskAssignees = [
            a
            for a in taskAssignees
            if a != memberId
        ];
    } else {
        taskAssignees = taskAssignees + [memberId];
    }
}

impl FlowLinePage.saveTask -> None {
    title = taskForm["title"].strip();
    if not title or not editTaskId {
        return;
    }
    taskSaving = True;
    project = taskForm["project"] if taskForm["project"] != "none" else "";
    reviewer = taskForm["reviewer"] if taskForm["reviewer"] != "none" else "";
    landing = taskForm["status"];
    # Read before any await: where the task was, and where it is going.
    fromStep = peekId;
    landedName = stepName(landing);
    pid = projectId;
    try {
        if project {
            added = 0;
            for aid in taskAssignees {
                onProject = False;
                for m in roleMembers {
                    if m.id == aid and project in m.project_ids {
                        onProject = True;
                    }
                }
                if not onProject {
                    root spawn AssignToProject(member_id=aid, project_id=project);
                    added = added + 1;
                }
            }
            if added > 0 {
                toast("Added " + str(added) + " assignee(s) to the project");
            }
        }
        root spawn UpdateTask(
            task_id=editTaskId,
            title=title,
            category=taskForm["category"],
            priority=taskForm["priority"],
            status=mappedStatus(landing),
            step_id=landing,
            due_date=taskForm["due_date"],
            notes=taskForm["notes"],
            issue_link=taskForm["issue"].strip(),
            pr_link=taskForm["pr"].strip(),
            reviewer_id=reviewer,
            review_due=taskForm["review_due"],
            assignee_ids=taskAssignees,
            project_id=project
        );
        taskOpen = False;
        # The counts on the cards come from GetFlowLine, the panel from
        # ListStepTasks, so a save has to refresh both.
        await reload(pid);
        await refreshPeek(fromStep, pid);
        if landing != fromStep and landedName {
            toast("Saved · moved to " + landedName);
        }
    } except Exception as e {
        toast("Failed to save task");
    }
    taskSaving = False;
}

impl FlowLinePage.deleteTask -> None {
    if not editTaskId {
        return;
    }
    taskSaving = True;
    fromStep = peekId;
    pid = projectId;
    try {
        root spawn DeleteTask(task_id=editTaskId);
        taskOpen = False;
        await reload(pid);
        await refreshPeek(fromStep, pid);
    } except Exception as e {
        toast("Failed to delete task");
    }
    taskSaving = False;
}

impl FlowLinePage.selectProject(v: str) -> None {
    openStep = peekId;
    projectId = v;
    localStorage.setItem("standup_project", v);
    await reload(v);
    # The panel obeys the filter too, so it reloads with the diagram.
    await refreshPeek(openStep, v);
}

impl FlowLinePage.loadMeta -> None {
    try {
        result = root spawn GetFlowLineMeta();
        payload = result.reports[0] if result.reports else None;
        if payload and payload["name"] {
            lineName = payload["name"];
        }
    } except Exception as e {
        lineName = lineName;
    }
}

impl FlowLinePage.switchView(v: str) -> None {
    chosen = "lanes" if v == "lanes" else "flow";
    lineView = chosen;
    localStorage.setItem("standup_wf_view", chosen);
}

impl FlowLinePage.lanePlan -> dict[str, any] {
    # The Lane view projection, recomputed on demand so the fit math and
    # the render can never disagree. Editing always measures the freeform
    # drawing, so the plan is empty there.
    if lineView != "lanes" or editing or len(steps) == 0 {
        return {"positions": {}, "lanes": []};
    }
    return laneLayout(steps, roleRows, roleMembers);
}

impl FlowLinePage.pickTemplate(key: str) -> None {
    applying = key;
    try {
        result = root spawn ApplyTemplate(template_key=key);
        fresh = result.reports[0] if result.reports else [];
        if len(fresh) > 0 {
            steps = fresh;
            editing = True;
            toast("Your flow line is in, drag anything to make it yours");
        } else {
            toast("That template could not be applied");
        }
    } except Exception as e {
        toast("Failed to set up the flow line");
    }
    applying = "";
}

impl FlowLinePage.startScratch -> None {
    scratch = True;
    editing = True;
}

impl FlowLinePage.startRename -> None {
    nameDraft = lineName;
    renaming = True;
}

impl FlowLinePage.saveRename -> None {
    value = nameDraft.strip();
    renaming = False;
    if not value or value == lineName {
        return;
    }
    try {
        result = root spawn RenameFlowLine(name=value);
        payload = result.reports[0] if result.reports else None;
        if payload and payload["name"] {
            lineName = payload["name"];
        }
    } except Exception as e {
        toast("Failed to rename the flow line");
    }
}

impl FlowLinePage.addStep -> None {
    # Open the naming panel; nothing is created until the user commits a
    # name of their own. No placeholder steps.
    creatingStep = True;
    selectedId = "";
    selectedEdge = "";
    confirmDelete = False;
    form = {"name": "", "kind": "active", "color": "indigo", "owner": "", "blurb": ""};
}

impl FlowLinePage.commitName -> None {
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
                blurb=form["blurb"] or "",
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
                    "owner": made.owner,
                    "blurb": made.blurb
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
    blurb = (form["blurb"] or "").strip();
    if (
        current
        and current[0].name == name
        and current[0].owner == owner
        and current[0].blurb == blurb
    ) {
        busyRef.current = False;
        return;
    }
    saving = True;
    try {
        # SaveStep reads empty as "keep", so a lone space clears the field.
        root spawn SaveStep(
            step_id=selectedId, name=name, owner=owner or " ", blurb=blurb or " "
        );
        await reload(projectId);
    } except Exception as e {
        toast("Failed to update the step");
    }
    saving = False;
    busyRef.current = False;
}

impl FlowLinePage.commitField(key: str, value: str) -> None {
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

impl FlowLinePage.deleteStep -> None {
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

impl FlowLinePage.deleteFlowLine -> None {
    wiping = True;
    try {
        result = root spawn DeleteFlowLine();
        payload = result.reports[0] if result.reports else None;
        if not payload or not payload["ok"] {
            toast("The flow line could not be deleted");
            wiping = False;
            return;
        }
        # Back to the empty state the picker guards: nothing selected or
        # half-drawn, not scratch, not editing.
        steps = [];
        scratch = False;
        editing = False;
        renaming = False;
        creatingStep = False;
        selectedId = "";
        selectedEdge = "";
        connectFrom = "";
        confirmDelete = False;
        peekId = "";
        confirmWipe = False;
        await reload(projectId);
        toast("Flow line deleted, pick a template or start from scratch");
    } except Exception as e {
        toast("Failed to delete the flow line");
    }
    wiping = False;
}

impl FlowLinePage.linkSteps(fromId: str, toId: str) -> None {
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

impl FlowLinePage.selectEdge(key: str, said: str, carried: str) -> None {
    # Seeding the draft from the edge itself is what makes the editor an
    # edit rather than a retype, and it is why nothing has to clear the
    # draft when the selection moves.
    selectedEdge = key;
    edgeDraft = said;
    edgeCarry = carried;
}

impl FlowLinePage.commitEdgeLabel(
    fromId: str, toId: str, said: str, carried: str
) -> None {
    # An empty `said` is a clear, not a no-op, which is why this goes
    # through LabelTransition rather than re-drawing the arrow. The tag
    # rides along: the editor saves both fields at once.
    try {
        result = root spawn LabelTransition(
            from_id=fromId, to_id=toId, label=said, carries=carried
        );
        payload = result.reports[0] if result.reports else None;
        if payload and payload["ok"] {
            edgeDraft = payload["label"];
            edgeCarry = payload["carries"];
            selectedEdge = "";
            await reload(projectId);
            toast(
                "Label removed"
                    if not payload["label"] and not payload["carries"]
                    else "Label saved"
            );
        } else {
            toast("Could not update that label");
        }
    } except Exception as e {
        toast("Could not update that label");
    }
}

impl FlowLinePage.deleteEdge(fromId: str, toId: str) -> None {
    selectedEdge = "";
    try {
        root spawn UnlinkTransition(from_id=fromId, to_id=toId);
        await reload(projectId);
    } except Exception as e {
        toast("Could not remove that transition");
    }
}

impl FlowLinePage.selectStep(stepId: str) -> None {
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
            "owner": picked[0].owner,
            "blurb": picked[0].blurb
        };
    }
}

impl FlowLinePage.armConnect -> None {
    if selectedId {
        connectFrom = selectedId;
        selectedEdge = "";
    }
}

impl FlowLinePage.clearCanvas -> None {
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

impl FlowLinePage.setField(key: str, value: str) -> None {
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

impl FlowLinePage.zoomBy(delta: float) -> None {
    current = float(zoomRef.current) if zoomRef.current else zoom;
    z = clampZoom(current + delta);
    zoomRef.current = z;
    zoom = z;
    recenterPan();
}

impl FlowLinePage.viewBounds -> list[float] {
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

impl FlowLinePage.fitZoom -> None {
    view: any = viewportRef.current;
    if not view {
        zoomRef.current = 1.0;
        zoom = 1.0;
        return;
    }
    bounds = viewBounds();
    spanW = bounds[2] - bounds[0];
    spanH = bounds[3] - bounds[1];
    boxW = float(view.clientWidth) - 48.0;
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

impl FlowLinePage.recenterPan -> None {
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
    availW = float(view.clientWidth);
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

impl FlowLinePage.pointerXY(e: MouseEvent) -> list[float] {
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

impl FlowLinePage.beginDrag(e: MouseEvent) -> None {
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
            "owner": step.owner,
            "blurb": step.blurb
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

impl FlowLinePage.moveDrag(e: MouseEvent) -> None {
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

impl FlowLinePage.endDrag(e: MouseEvent) -> None {
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
