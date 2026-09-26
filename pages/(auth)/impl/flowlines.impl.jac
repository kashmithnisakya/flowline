"""Implementations for the Flow line page. Loaders and mutations reload through
GetFlowLine rather than patching local state: the walker is the only place the
prev/next truth lives. Zoom and pan go through zoomTo/applyPan, which keep a
piece of the drawing in view whatever the gesture."""

impl FlowLinePage.boot -> None {
    picked = currentProject();
    projectId = picked;
    storedView = localStorage.getItem("flowline_wf_view") or "";
    if storedView == "lanes" {
        lineView = "lanes";
    }
    # The workspace lists and the flow line go out together; neither waits.
    w: any = window;
    await w.Promise.all([loadShared(), reload(picked)]);
    # No stored pick: the server opened on the default project, so name it
    # (the pick's event then finds it on screen). A pick that is no longer
    # active is replaced, and its event reloads the line.
    known = False;
    for p in projects {
        if jid(p) == projectId and p.active {
            known = True;
        }
    }
    if not known {
        fallback = defaultProject(projects);
        if not projectId {
            projectId = fallback;
        }
        pickProject(fallback);
    }
}

impl FlowLinePage.loadShared -> None {
    # Projects, roles and roster feed the filter, the lane
    # labels and the task dialog; the diagram loads fine without them, so a
    # failed read stays quiet. The flow line's name rides in the same view.
    ws = await loadWorkspace();
    projects = ws["projects"];
    roleRows = ws["roles"];
    roleMembers = ws["members"];
    if ws["ok"] and ws["flow_name"] {
        lineName = ws["flow_name"];
    }
}

impl FlowLinePage.reload(pid: str) -> None {
    try {
        result = root spawn GetFlowLine(project_id=pid);
        fresh: list[StepView] = result.reports[0] if result.reports else [];
        steps = fresh;
        loadTitles(fresh);
        failed = False;
    } except Exception as e {
        # With a line on screen a toast is enough; with nothing, the page
        # shows its own failed card and retry.
        failed = True;
        if len(steps) > 0 {
            toast.error("Failed to load your flow line");
        }
    }
    loading = False;
}

# Everything again, projects and roster included: the first read failed
# with them, and the card stays up (Reveal keeps its content) meanwhile.
impl FlowLinePage.retryLoad -> None {
    if retrying {
        return;
    }
    retrying = True;
    await boot();
    retrying = False;
}

impl FlowLinePage.peekStep(stepId: str) -> None {
    if swallowed() {
        return;
    }
    # Clicking the open step again closes the panel.
    if peekId == stepId {
        closePeek();
        return;
    }
    peekId = stepId;
    peekTasks = [];
    peekLoading = True;
    revealStep(stepId);
    await refreshPeek(stepId, projectId);
    peekLoading = False;
}

impl FlowLinePage.refreshPeek(stepId: str, pid: str) -> None {
    # A page at a time from the server, which owns the placement rule. Quiet
    # on purpose: a save refetches through here without flashing skeletons.
    if not stepId {
        return;
    }
    wanted = peekPage if peekPage > 1 else 1;
    rows: list[TaskRow] = [];
    try {
        step = 1;
        while step <= wanted and step <= 20 {
            result = root spawn ListStepTasks(
                step_id=stepId, project_id=pid, page=step, page_size=50
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
        toast.error("Could not load the work on that step");
    }
}

impl FlowLinePage.morePeek -> None {
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
            step_id=stepId, project_id=pid, page=wanted, page_size=50
        );
        got = result.reports[0] if result.reports else None;
        if got and peekRef.current == stepId {
            peekTasks = have + got.rows;
            peekTotal = got.total;
            peekMore = got.has_more;
            peekPage = wanted;
        }
    } except Exception as e {
        toast.error("Could not load more of that step");
    }
    peekLoadingMore = False;
}

impl FlowLinePage.loadTitles(fresh: list[StepView]) -> None {
    # The titles a close zoom shows ride on the flow line itself, two per
    # step with work on it, so reaching that zoom makes no request; the
    # count on the node says the rest.
    got: dict[str, list[str]] = {};
    for s in fresh {
        if s.task_count > 0 {
            got[s.id] = s.task_titles;
        }
    }
    stepTitles = got;
}

impl FlowLinePage.closePeek -> None {
    if swallowed() {
        return;
    }
    peekId = "";
    peekTasks = [];
    peekLoading = False;
    peekTotal = 0;
    peekMore = False;
    peekPage = 0;
}

impl FlowLinePage.revealStep(stepId: str) -> None {
    # The panel floats over the right of the canvas; slide the diagram just
    # enough that the step it describes stays in view beside it.
    view: any = viewportRef.current;
    if not view or narrow {
        return;
    }
    rects = drawnRects();
    if stepId not in rects {
        return;
    }
    r = rects[stepId];
    lanes = lineView == "lanes" and not editing;
    pan: list[float] = panRef.current or [panX, panY];
    nx = pan[0];
    right = float(view.clientWidth) - PANEL_W - 28.0;
    left = (laneLabelW() + 16.0) if lanes else 16.0;
    if nx + r[0] + r[2] > right {
        nx = right - r[0] - r[2];
    }
    if nx + r[0] < left {
        nx = left - r[0];
    }
    if nx != pan[0] {
        applyPan(nx, pan[1]);
    }
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
        "tags": ", ".join(picked.tags),
        "estimate": fmtEstimate(picked.estimate) if picked.estimate > 0.0 else "",
        "project": picked.project_id,
        "priority": picked.priority,
        "status": key,
        "due_date": picked.due_date,
        "start_date": picked.start_date,
        "notes": "",
        "issue": picked.issue_link,
        "pr": picked.pr_link,
        "reviewer": picked.reviewer_id or "none",
        "review_due": picked.review_due
    };
    taskAssignees = picked.assignee_ids;
    taskOpen = True;
}

# A checklist write reports the task's fresh view; the panel row takes it.
impl FlowLinePage.replacePeekRow(view: TaskView) -> None {
    peekTasks = [view if t.id == view.id else t for t in peekTasks];
}

# The sheet's GetTask hands the open task's notes to the form.
impl FlowLinePage.absorbDetails(view: TaskView) -> None {
    if view.id != editTaskId {
        return;
    }
    updated = {** taskForm};
    updated["notes"] = view.notes;
    taskForm = updated;
}

impl FlowLinePage.setTaskField(key: str, value: str) -> None {
    # A computed key does not survive a dict-literal spread.
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
    project = taskForm["project"];
    if not project {
        toast.error("Pick a project for this task");
        return;
    }
    taskSaving = True;
    reviewer = taskForm["reviewer"] if taskForm["reviewer"] != "none" else "";
    landing = taskForm["status"];
    fromStep = peekId;
    landedName = stepName(landing);
    pid = projectId;
    refusal = moveRefusal(
        steps, landing, fromStep, taskForm["due_date"], taskForm["pr"]
    );
    if refusal {
        toast.error(refusal);
        taskSaving = False;
        return;
    }
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
                    forgetWorkspace();
                }
            }
            if added > 0 {
                toast.success("Added " + str(added) + " assignee(s) to the project");
            }
        }
        saved = root spawn UpdateTask(
            task_id=editTaskId,
            title=title,
            category=taskForm["category"],
            tags=[
                s.strip()
                for s in taskForm["tags"].split(",")
                if s.strip()
            ],
            estimate=parseEstimate(taskForm["estimate"]),
            priority=taskForm["priority"],
            status=mappedStatus(landing),
            step_id=landing,
            due_date=taskForm["due_date"],
            start_date=taskForm["start_date"],
            notes=taskForm["notes"],
            issue_link=taskForm["issue"].strip(),
            pr_link=taskForm["pr"].strip(),
            reviewer_id=reviewer,
            review_due=taskForm["review_due"],
            assignee_ids=taskAssignees,
            project_id=project
        );
        taskOpen = False;
        # The counts on the nodes come from GetFlowLine, the panel from
        # ListStepTasks, so a save has to refresh both.
        await reload(pid);
        await refreshPeek(fromStep, pid);
        if len(saved.reports or []) > 0 and saved.reports[0].refused {
            toast.error(saved.reports[0].refused);
        } elif landing != fromStep and landedName {
            toast.success("Saved · moved to " + landedName);
        }
    } except Exception as e {
        toast.error("Failed to save task");
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
        toast.error("Failed to delete task");
    }
    taskSaving = False;
}

impl FlowLinePage.adoptProject(v: str) -> None {
    if v == projectId {
        return;
    }
    openStep = peekId;
    projectId = v;
    await reload(v);
    await refreshPeek(openStep, v);
}

impl FlowLinePage.switchView(v: str) -> None {
    chosen = "lanes" if v == "lanes" else "flow";
    lineView = chosen;
    localStorage.setItem("flowline_wf_view", chosen);
}

impl FlowLinePage.switchMode(v: str) -> None {
    if v == "edit" {
        if not editing {
            peekId = "";
            peekTasks = [];
            editing = True;
        }
        return;
    }
    finishEditing();
}

impl FlowLinePage.finishEditing -> None {
    editing = False;
    renaming = False;
    connectFrom = "";
    selectedId = "";
    selectedEdge = "";
    confirmDelete = False;
    creatingStep = False;
}

impl FlowLinePage.lanePlan -> dict[str, any] {
    # The Lane view projection, recomputed on demand so the fit math and the
    # render can never disagree. Editing and the phone list draw no lanes.
    if (
        lineView != "lanes"
        or editing
        or len(steps) == 0
        or (narrow and phoneView == "list")
    ) {
        return {"positions": {}, "lanes": [], "laneOf": {}, "colOf": {}};
    }
    hint = float(laneFitRef.current) if laneFitRef.current else 0.0;
    return laneLayout(
        steps, roleRows, roleMembers, boxW, boxH, laneLabelW() + 40.0, hint
    );
}

impl FlowLinePage.laneLabelW -> float {
    return LANE_LABEL_NARROW if narrow else LANE_LABEL_W;
}

impl FlowLinePage.pickTemplate(key: str) -> None {
    applying = key;
    try {
        result = root spawn ApplyTemplate(template_key=key);
        fresh = result.reports[0] if result.reports else [];
        if len(fresh) > 0 {
            forgetWorkspace();
            steps = fresh;
            editing = True;
            toast.success("Your flow line is in. Drag anything to make it yours.");
        } else {
            toast.error("That template could not be applied");
        }
    } except Exception as e {
        toast.error("Failed to set up the flow line");
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
            forgetWorkspace();
            lineName = payload["name"];
        }
    } except Exception as e {
        toast.error("Failed to rename the flow line");
    }
}

impl FlowLinePage.addStep -> None {
    # Open the naming panel; nothing is created until the user commits a
    # name of their own.
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
    # Enter auto-repeat fires faster than the walker round-trips, so the
    # in-flight latch lives on a ref.
    if busyRef.current {
        return;
    }
    busyRef.current = True;
    if creatingStep {
        # Drop the new card at the left edge, under the lowest existing one.
        ny = 40.0;
        for s in steps {
            if s.y + 124.0 > ny {
                ny = s.y + 124.0;
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
            forgetWorkspace();
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
            toast.error("Failed to add the step");
        }
        saving = False;
        busyRef.current = False;
        return;
    }
    if not selectedId {
        busyRef.current = False;
        return;
    }
    current = [
        s
        for s in steps
        if s.id == selectedId
    ];
    owner = (form["owner"] or "").strip();
    blurb = (form["blurb"] or "").strip();
    if (
        len(current) > 0
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
        forgetWorkspace();
        await reload(projectId);
    } except Exception as e {
        toast.error("Failed to update the step");
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
            root spawn SaveStep(
                step_id=selectedId, owner=value if value.strip() else " "
            );
        }
        forgetWorkspace();
        await reload(projectId);
    } except Exception as e {
        toast.error("Failed to update the step");
    }
}

impl FlowLinePage.deleteStep -> None {
    if not selectedId {
        return;
    }
    # First click arms, the second one deletes.
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
            toast.error(payload["message"] or "That step cannot be deleted.");
            return;
        }
        forgetWorkspace();
        selectedId = "";
        selectedEdge = "";
        confirmDelete = False;
        if connectFrom == gone {
            connectFrom = "";
        }
        await reload(projectId);
        toast.success("Step deleted");
    } except Exception as e {
        toast.error("Failed to delete the step");
    }
    saving = False;
}

impl FlowLinePage.deleteFlowLine -> None {
    wiping = True;
    try {
        result = root spawn DeleteFlowLine();
        payload = result.reports[0] if result.reports else None;
        if not payload or not payload["ok"] {
            toast.error("The flow line could not be deleted");
            wiping = False;
            return;
        }
        forgetWorkspace();
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
        toast.success("Flow line deleted. Pick a template or start from scratch.");
    } except Exception as e {
        toast.error("Failed to delete the flow line");
    }
    wiping = False;
}

impl FlowLinePage.linkSteps(fromId: str, toId: str) -> None {
    try {
        result = root spawn LinkTransition(from_id=fromId, to_id=toId);
        payload = result.reports[0] if result.reports else None;
        if payload and payload["ok"] {
            forgetWorkspace();
            await reload(projectId);
            if not payload["duplicate"] {
                toast.success(
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
            toast.error(payload["message"] or "That transition is not allowed.");
        }
    } except Exception as e {
        toast.error("Could not connect those steps");
    }
}

impl FlowLinePage.selectEdge(key: str, fields: dict[str, str]) -> None {
    # Seeding the draft from the edge is what makes the editor an edit
    # rather than a retype.
    selectedEdge = key;
    edgeForm = fields;
}

impl FlowLinePage.editEdge(key: str, value: str) -> None {
    drafted = {** edgeForm};
    drafted[key] = value;
    edgeForm = drafted;
}

impl FlowLinePage.commitEdge(fromId: str, toId: str, fields: dict[str, str]) -> None {
    # Every field goes together and an empty one clears, which is why this
    # goes through LabelTransition rather than re-drawing the arrow.
    try {
        result = root spawn LabelTransition(
            from_id=fromId,
            to_id=toId,
            label=fields["label"] or "",
            carries=fields["carries"] or "",
            trigger=fields["trigger"] or "",
            trigger_label=fields["trigger_label"] or ""
        );
        payload = result.reports[0] if result.reports else None;
        if payload and payload["ok"] {
            forgetWorkspace();
            selectedEdge = "";
            edgeForm = {};
            await reload(projectId);
            toast.success(
                "Transition cleared"
                    if not payload["label"]
                        and not payload["carries"]
                        and not payload["trigger"]
                    else "Transition saved"
            );
        } elif payload and payload["message"] {
            toast.error(payload["message"]);
        } else {
            toast.error("Could not update that transition");
        }
    } except Exception as e {
        toast.error("Could not update that transition");
    }
}

impl FlowLinePage.commitRule(key: str, on: bool) -> None {
    current = [
        s
        for s in steps
        if s.id == selectedId
    ];
    if len(current) == 0 {
        return;
    }
    due = on if key == "needs_due_date" else current[0].needs_due_date;
    pr = on if key == "needs_pr" else current[0].needs_pr;
    try {
        root spawn SetStepRules(step_id=selectedId, needs_due_date=due, needs_pr=pr);
        forgetWorkspace();
        await reload(projectId);
    } except Exception as e {
        toast.error("Failed to update the step");
    }
}

impl FlowLinePage.deleteEdge(fromId: str, toId: str) -> None {
    selectedEdge = "";
    try {
        root spawn UnlinkTransition(from_id=fromId, to_id=toId);
        forgetWorkspace();
        await reload(projectId);
    } except Exception as e {
        toast.error("Could not remove that transition");
    }
}

impl FlowLinePage.selectStep(stepId: str) -> None {
    # A drag ends with a click on the node it started from; the drag stamps
    # that click to be ignored.
    if swallowed() {
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
    if len(picked) > 0 {
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
    # A drag whose press and release land on different elements clicks
    # their common ancestor, the canvas, so the stamp is honoured here too.
    if swallowed() {
        return;
    }
    connectFrom = "";
    selectedEdge = "";
    selectedId = "";
    confirmDelete = False;
    creatingStep = False;
}

impl FlowLinePage.setField(key: str, value: str) -> None {
    # Copy, then subscript: a dict-literal spread freezes bound inputs.
    updated = {** form};
    updated[key] = value;
    form = updated;
    # Kind, color and owner commit on pick; the name commits on blur.
    if key == "kind" or key == "color" or key == "owner" {
        commitField(key, value);
    }
}

# The diagram's footprint in canvas px: [minX, minY, maxX, maxY].
def contentBounds(steps: list[StepView], live: dict[str, list[float]]) -> list[float] {
    minX = 0.0;
    minY = 0.0;
    maxX = 0.0;
    maxY = 0.0;
    first = True;
    for s in steps {
        pos: list[float] = stepXY(s, live);
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

# Width of the lane columns at zoom z, with the text widths for its detail.
def laneTotal(
    steps: list[StepView],
    pose: dict[str, list[float]],
    colOf: dict[str, int],
    z: float,
    stepTitles: dict[str, list[str]],
    low: dict[str, float],
    mid: dict[str, float]
) -> float {
    need = low if detailOf(z) == "low" else mid;
    return float(laneRects(steps, pose, colOf, z, stepTitles, need, 0.0)["total"]);
}

# The largest lane zoom whose columns fit `availW`. Column width only grows
# with the zoom, so a bisection finds it.
def laneWidthZoom(
    steps: list[StepView],
    pose: dict[str, list[float]],
    colOf: dict[str, int],
    stepTitles: dict[str, list[str]],
    low: dict[str, float],
    mid: dict[str, float],
    availW: float
) -> float {
    if laneTotal(steps, pose, colOf, LANE_ZOOM_CAP, stepTitles, low, mid) <= availW {
        return LANE_ZOOM_CAP;
    }
    lo = LANE_ZOOM_MIN;
    hi = LANE_ZOOM_CAP;
    k = 0;
    while k < 16 {
        m = (lo + hi) / 2.0;
        if laneTotal(steps, pose, colOf, m, stepTitles, low, mid) <= availW {
            lo = m;
        } else {
            hi = m;
        }
        k = k + 1;
    }
    return lo;
}

impl FlowLinePage.drawnRects -> dict[str, list[float]] {
    # What the canvas drew last render; before the first one, the plain layout.
    laid: any = layoutRef.current;
    if laid {
        return laid["rects"];
    }
    z = float(zoomRef.current) if zoomRef.current else zoom;
    return nodeRects(
        stepsRef.current or [], liveRef.current or {}, z, stepTitles, 0.0, NODE_H
    );
}

impl FlowLinePage.panRects(z: float) -> dict[str, list[float]] {
    # The node rects the canvas draws at zoom z, in pan-origin screen px, with
    # the text widths it measured last.
    laid: any = layoutRef.current;
    need: dict[str, float] = {};
    if laid {
        need = laid["needLow"] if detailOf(z) == "low" else laid["needMid"];
    }
    if lineView == "lanes" and not editing {
        if laid and detailOf(z) != "low" {
            need = laid["needLane"];
        }
        plan = lanePlan();
        return laneRects(
            steps,
            plan["positions"],
            plan["colOf"],
            z,
            stepTitles,
            need,
            laneLabelW() + 16.0
        )["rects"];
    }
    return nodeRects(steps, live, z, stepTitles, 0.0, NODE_H, need);
}

impl FlowLinePage.contentBox(z: float) -> list[float] {
    # The drawn nodes at zoom z, in pan-origin screen px: [x0, y0, x1, y1].
    lanes = lineView == "lanes" and not editing;
    bands: list[dict[str, any]] = lanePlan()["lanes"] if lanes else [];
    rects = panRects(z);
    x0 = 0.0;
    y0 = 0.0;
    x1 = 0.0;
    y1 = 0.0;
    first = True;
    for s in steps {
        if s.id not in rects {
            continue;
        }
        r = rects[s.id];
        if first or r[0] < x0 {
            x0 = r[0];
        }
        if first or r[1] < y0 {
            y0 = r[1];
        }
        if first or r[0] + r[2] > x1 {
            x1 = r[0] + r[2];
        }
        if first or r[1] + r[3] > y1 {
            y1 = r[1] + r[3];
        }
        first = False;
    }
    if lanes and len(bands) > 0 {
        y0 = 0.0;
        for b in bands {
            bandEnd = (float(b["y"]) + float(b["h"])) * z;
            if bandEnd > y1 {
                y1 = bandEnd;
            }
        }
    }
    return [x0, y0, x1, y1];
}

impl FlowLinePage.applyPan(x: float, y: float) -> None {
    # Pan only as far as there is drawing to see. On an axis where the whole
    # drawing fits, it stays where the fit puts it (centred, or the lanes at
    # their origin); where it overflows, its far edges stop at the frame.
    view: any = viewportRef.current;
    nx = x;
    ny = y;
    if view {
        z = float(zoomRef.current) if zoomRef.current else zoom;
        lanes = lineView == "lanes" and not editing;
        box = contentBox(z);
        # Label chips hang past the outer nodes; the last render measured by
        # how much, as the fit does.
        laid: any = layoutRef.current;
        mL = 0.0;
        mT = 0.0;
        mR = 0.0;
        mB = 0.0;
        if laid {
            nb: list[float] = laid["nodes"];
            eb: list[float] = laid["extent"];
            mL = nb[0] - eb[0];
            mT = nb[1] - eb[1];
            mR = eb[2] - nb[2];
            mB = eb[3] - nb[3];
        }
        vx0 = laneLabelW() if lanes else 0.0;
        # The lanes start at the label gutter, where the fit leaves them.
        left = box[0] - mL;
        if lanes and left > vx0 {
            left = vx0;
        }
        nx = panAxis(nx, left, box[2] + mR, vx0, float(view.clientWidth), lanes);
        ny = panAxis(
            ny,
            box[1] if lanes else box[1] - mT,
            box[3] if lanes else box[3] + mB,
            0.0,
            float(view.clientHeight),
            lanes
        );
    }
    panRef.current = [nx, ny];
    panX = nx;
    panY = ny;
}

impl FlowLinePage.panAxis(
    want: float, lo: float, hi: float, v0: float, v1: float, pinned: bool
) -> float {
    # One axis of applyPan: the drawing spans lo..hi before panning and the
    # frame v0..v1. A drawing that fits is centred, or held at the origin
    # when `pinned` (lanes, whose bands are their own edge, so no margin);
    # a larger one keeps both of its edges at or past the frame's.
    gap = 0.0 if pinned else PAN_MARGIN;
    span = hi - lo;
    room = v1 - v0;
    if span + 2.0 * gap <= room + 0.5 {
        return 0.0 if pinned else v0 + (room - span) / 2.0 - lo;
    }
    least = v1 - gap - hi;
    most = v0 + gap - lo;
    if want < least {
        return least;
    }
    if want > most {
        return most;
    }
    return want;
}

impl FlowLinePage.zoomTo(z: float, sx: float, sy: float) -> None {
    lanes = lineView == "lanes" and not editing;
    target = clampZoom(z);
    # Below this the lane bands get shorter than a card.
    if lanes and target < LANE_ZOOM_MIN {
        target = LANE_ZOOM_MIN;
    }
    z1 = float(zoomRef.current) if zoomRef.current else zoom;
    if z1 <= 0.0 {
        z1 = 1.0;
    }
    pan: list[float] = panRef.current or [panX, panY];
    # The canvas point under (sx, sy) stays put. The lane label gutter is
    # fixed px, so it stays out of the scaling.
    g = (laneLabelW() + 16.0) if lanes else 0.0;
    nx = sx - g - (sx - pan[0] - g) * target / z1;
    ny = sy - (sy - pan[1]) * target / z1;
    if lanes {
        # Lane columns widen to fit their names, so they do not scale evenly:
        # anchor on the step nearest the pointer instead of the origin.
        before = panRects(z1);
        after = panRects(target);
        px = sx - pan[0];
        py = sy - pan[1];
        best = "";
        bestD = -1.0;
        for s in steps {
            if s.id in before and s.id in after {
                r = before[s.id];
                ddx = px - (r[0] + r[2] / 2.0);
                ddy = py - (r[1] + r[3] / 2.0);
                d = ddx * ddx + ddy * ddy;
                if bestD < 0.0 or d < bestD {
                    bestD = d;
                    best = s.id;
                }
            }
        }
        if best {
            o = before[best];
            n = after[best];
            nx = sx - (n[0] + n[2] / 2.0) - (px - o[0] - o[2] / 2.0) * target / z1;
            ny = sy - (n[1] + n[3] / 2.0) - (py - o[1] - o[3] / 2.0) * target / z1;
        }
    }
    zoomRef.current = target;
    zoom = target;
    applyPan(nx, ny);
}

impl FlowLinePage.zoomStep(dirn: int) -> None {
    view: any = viewportRef.current;
    if not view {
        return;
    }
    z1 = float(zoomRef.current) if zoomRef.current else zoom;
    zoomTo(
        nextStop(z1, dirn),
        float(view.clientWidth) / 2.0,
        float(view.clientHeight) / 2.0
    );
}

impl FlowLinePage.zoomActual -> None {
    view: any = viewportRef.current;
    if not view {
        return;
    }
    zoomTo(1.0, float(view.clientWidth) / 2.0, float(view.clientHeight) / 2.0);
}

impl FlowLinePage.measureBox -> None {
    view: any = viewportRef.current;
    if not view {
        return;
    }
    # Assigned only on a real change: the fit's layout effect is keyed on
    # these two, so an unconditional write would never settle.
    w = float(view.clientWidth);
    h = float(view.clientHeight);
    resized = w != boxW or h != boxH;
    if w != boxW {
        boxW = w;
    }
    if h != boxH {
        boxH = h;
    }
    # A new frame size moves the bounds: keep the pan inside them.
    if resized and fittedRef.current {
        panNow: list[float] = panRef.current or [panX, panY];
        applyPan(panNow[0], panNow[1]);
    }
}

impl FlowLinePage.fitZoom -> None {
    view: any = viewportRef.current;
    if not view or len(steps) == 0 {
        zoomRef.current = 1.0;
        zoom = 1.0;
        panRef.current = [0.0, 0.0];
        panX = 0.0;
        panY = 0.0;
        return;
    }
    lanes = lineView == "lanes" and not editing;
    w = float(view.clientWidth);
    h = float(view.clientHeight);
    laid: any = layoutRef.current;
    if lanes {
        # Lanes: the widest zoom whose columns fit beside the label gutter,
        # no taller than the bands at their natural height. The bands then
        # grow to fill the box at exactly this zoom (lanePlan's hint).
        natural = laneLayout(steps, roleRows, roleMembers);
        low: dict[str, float] = laid["needLow"] if laid else {};
        mid: dict[str, float] = laid["needLane"] if laid else {};
        zw = laneWidthZoom(
            steps,
            natural["positions"],
            natural["colOf"],
            stepTitles,
            low,
            mid,
            w - laneLabelW() - 40.0
        );
        naturalH = float(natural["naturalH"]);
        zh = h / naturalH if naturalH > 0.0 else LANE_ZOOM_CAP;
        best = zw if zw < zh else zh;
        cap = laneFitCap(h, naturalH);
        if best > cap {
            best = cap;
        }
        if best < LANE_ZOOM_MIN {
            best = LANE_ZOOM_MIN;
        }
        laneFitRef.current = best;
        zoomRef.current = best;
        zoom = best;
        panRef.current = [0.0, 0.0];
        panX = 0.0;
        panY = 0.0;
        lastFitRef.current = [best, 0.0, 0.0];
    } else {
        bounds = contentBounds(steps, live);
        spanW = bounds[2] - bounds[0];
        spanH = bounds[3] - bounds[1];
        # Label chips hang past the outer nodes by roughly the same screen px
        # at any zoom, so the last render's overhang is reserved around it.
        mL = 0.0;
        mT = 0.0;
        mR = 0.0;
        mB = 0.0;
        if laid {
            nb: list[float] = laid["nodes"];
            eb: list[float] = laid["extent"];
            mL = nb[0] - eb[0];
            mT = nb[1] - eb[1];
            mR = eb[2] - nb[2];
            mB = eb[3] - nb[3];
        }
        availW = w - 48.0 - mL - mR;
        availH = h - 48.0 - mT - mB;
        if spanW <= 0.0 or spanH <= 0.0 or availW <= 0.0 or availH <= 0.0 {
            return;
        }
        byW = availW / spanW;
        byH = availH / spanH;
        # The hand-drawn line stops at 100%, past which its nodes only grow
        # emptier.
        best = clampZoom(byW if byW < byH else byH);
        if best > 1.0 {
            best = 1.0;
        }
        # A card grows past its base width to fit its badge and owner, which
        # the span above cannot see, so shrink until the drawn box fits.
        for _ in range(3) {
            drawn = contentBox(best);
            overW = (drawn[2] - drawn[0]) / (w - 48.0 - mL - mR);
            overH = (drawn[3] - drawn[1]) / (h - 48.0 - mT - mB);
            over = overW if overW > overH else overH;
            if over > 1.0 {
                best = clampZoom(best / over);
            }
        }
        zoomRef.current = best;
        zoom = best;
        box = contentBox(best);
        cw = box[2] - box[0] + mL + mR;
        ch = box[3] - box[1] + mT + mB;
        # Centre what fits; a drawing wider or taller than the box starts at
        # its first step instead of its middle.
        px = (w - cw) / 2.0 - box[0] + mL if cw <= w - 24.0 else 12.0 - box[0] + mL;
        py = (h - ch) / 2.0 - box[1] + mT if ch <= h - 24.0 else 12.0 - box[1] + mT;
        panRef.current = [px, py];
        panX = px;
        panY = py;
        lastFitRef.current = [best, px, py];
    }
    fittedRef.current = True;
    # The overhang at the new zoom is only known once it is drawn: fit once
    # more on the next frame with those margins.
    if not refitRef.current {
        refitRef.current = True;
        window.requestAnimationFrame(
            lambda {
                fitZoom();
                refitRef.current = False;
            }
        );
    }
}

impl FlowLinePage.refitIfUntouched -> None {
    last: any = lastFitRef.current;
    pan: list[float] = panRef.current or [panX, panY];
    z = float(zoomRef.current) if zoomRef.current else zoom;
    if last and last[0] == z and last[1] == pan[0] and last[2] == pan[1] {
        fitZoom();
    }
}

impl FlowLinePage.onWheel(e: any) -> None {
    view: any = viewportRef.current;
    if not view {
        return;
    }
    e.preventDefault();
    box: any = view.getBoundingClientRect();
    sx = float(e.clientX) - float(box.left);
    sy = float(e.clientY) - float(box.top);
    unit = 16.0 if e.deltaMode == 1 else 1.0;
    dx = float(e.deltaX) * unit;
    dy = float(e.deltaY) * unit;
    if e.ctrlKey or e.metaKey {
        # Trackpad pinch arrives as ctrl + small deltas; a mouse wheel notch
        # is about 100, so both land on a sensible step.
        step = 0.0 - dy * 0.01;
        if step > 0.5 {
            step = 0.5;
        }
        if step < -0.5 {
            step = -0.5;
        }
        z1 = float(zoomRef.current) if zoomRef.current else zoom;
        zoomTo(z1 * (2.0 ** step), sx, sy);
        return;
    }
    if e.shiftKey and dx == 0.0 {
        dx = dy;
        dy = 0.0;
    }
    pan: list[float] = panRef.current or [panX, panY];
    applyPan(pan[0] - dx, pan[1] - dy);
}

impl FlowLinePage.onKeyDown(e: any) -> None {
    w: any = window;
    dialogOpen = bool(
        w.document.querySelector("[role=dialog][data-state=open], [role=menu]")
    );
    if e.key == "Escape" {
        if peekRef.current and not dialogOpen {
            closePeek();
        }
        return;
    }
    target: any = e.target;
    tag = str(target.tagName if target and target.tagName else "").lower();
    typing = tag == "input"
        or tag == "textarea"
        or tag == "select"
        or bool(target and target.isContentEditable);
    if typing or dialogOpen or e.ctrlKey or e.metaKey or e.altKey {
        return;
    }
    if not viewportRef.current {
        return;
    }
    k = str(e.key);
    if k == "f" or k == "F" or k == "0" {
        e.preventDefault();
        fitZoom();
    } elif k == "+" or k == "=" {
        e.preventDefault();
        zoomStep(1);
    } elif k == "-" or k == "_" {
        e.preventDefault();
        zoomStep(-1);
    } elif k == " " and tag != "button" and tag != "a" {
        # Held Space turns any drag into a pan, even one that starts on a step.
        e.preventDefault();
        spaceRef.current = True;
    }
}

impl FlowLinePage.swallowed -> bool {
    stamp: any = swallowRef.current;
    if not stamp {
        return False;
    }
    swallowRef.current = 0;
    return float(new(Date).getTime()) - float(stamp) < 500.0;
}

impl FlowLinePage.pointerXY(e: any) -> list[float] {
    # Canvas px under the pointer: the surface sits at the pan offset and
    # positions scale by the zoom.
    surface: any = canvasRef.current;
    if not surface or not surface.getBoundingClientRect {
        return [-1.0, -1.0];
    }
    box: any = surface.getBoundingClientRect();
    scale = float(zoomRef.current) if zoomRef.current else 1.0;
    return [
        (float(e.clientX) - float(box.left)) / scale,
        (float(e.clientY) - float(box.top)) / scale
    ];
}

impl FlowLinePage.surfaceXY(e: any) -> list[float] {
    surface: any = canvasRef.current;
    if not surface or not surface.getBoundingClientRect {
        return [-99999.0, -99999.0];
    }
    box: any = surface.getBoundingClientRect();
    return [float(e.clientX) - float(box.left), float(e.clientY) - float(box.top)];
}

def trackPointer(
    pts: list[list[float]], pid: float, x: float, y: float
) -> list[list[float]] {
    out: list[list[float]] = [];
    found = False;
    for p in pts {
        if p[0] == pid {
            out.append([pid, x, y]);
            found = True;
        } else {
            out.append(p);
        }
    }
    if not found {
        out.append([pid, x, y]);
    }
    return out;
}

impl FlowLinePage.beginDrag(e: any) -> None {
    target: any = e.target;
    # Floating controls over the canvas keep their own pointer.
    if target
        and target.closest
        and target.closest("[data-panel], input, textarea, a") {
        return;
    }
    if e.pointerType == "mouse" and e.button != 0 and e.button != 1 {
        return;
    }
    pts: list[list[float]] = trackPointer(
        pointersRef.current or [],
        float(e.pointerId),
        float(e.clientX),
        float(e.clientY)
    );
    pointersRef.current = pts;
    pan: list[float] = panRef.current or [panX, panY];
    if len(pts) >= 2 {
        # A second finger: whatever the first one started becomes a pinch.
        a = pts[0];
        b = pts[1];
        d = ((a[1] - b[1]) * (a[1] - b[1]) + (a[2] - b[2]) * (a[2] - b[2])) ** 0.5;
        dragRef.current = None;
        wireRef.current = None;
        live = {};
        dragId = "";
        gestureRef.current = {
            "kind": "pinch",
            "d0": d if d > 1.0 else 1.0,
            "z0": float(zoomRef.current) if zoomRef.current else zoom
        };
        return;
    }
    panStart: dict[str, any] = {
        "kind": "pan",
        "x0": float(e.clientX),
        "y0": float(e.clientY),
        "px": pan[0],
        "py": pan[1],
        "moved": False
    };
    if e.button == 1 or spaceRef.current {
        e.preventDefault();
        gestureRef.current = panStart;
        return;
    }
    if editing {
        if connectFrom {
            return;
        }
        pos = surfaceXY(e);
        hit = hitRect(stepsRef.current or [], drawnRects(), pos[0], pos[1]);
        if "id" in hit {
            e.preventDefault();
            found = [
                s
                for s in (stepsRef.current or [])
                if s.id == hit["id"]
            ];
            if len(found) == 0 {
                return;
            }
            step = found[0];
            if hit["onEdge"] {
                # The border is the port: dragging off it draws a transition.
                # It also closes an open New step panel, which shares `form`.
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
            world = pointerXY(e);
            atPos = stepXY(step, liveRef.current or {});
            dragRef.current = {
                "id": step.id,
                "px": world[0],
                "py": world[1],
                "x": atPos[0],
                "y": atPos[1],
                "lx": atPos[0],
                "ly": atPos[1],
                "moved": False
            };
            return;
        }
    }
    # Empty canvas, or any press in view mode: it becomes a pan once it moves,
    # and stays a click (open a step, clear a selection) if it does not.
    gestureRef.current = panStart;
}

impl FlowLinePage.moveDrag(e: any) -> None {
    pts: list[list[float]] = trackPointer(
        pointersRef.current or [],
        float(e.pointerId),
        float(e.clientX),
        float(e.clientY)
    );
    pointersRef.current = pts;
    surface: any = e.currentTarget;
    g: any = gestureRef.current;
    if g and g["kind"] == "pinch" and len(pts) >= 2 {
        a = pts[0];
        b = pts[1];
        d = ((a[1] - b[1]) * (a[1] - b[1]) + (a[2] - b[2]) * (a[2] - b[2])) ** 0.5;
        box: any = surface.getBoundingClientRect();
        zoomTo(
            float(g["z0"]) * d / float(g["d0"]),
            (a[1] + b[1]) / 2.0 - float(box.left),
            (a[2] + b[2]) / 2.0 - float(box.top)
        );
        return;
    }
    if g and g["kind"] == "pan" {
        dx = float(e.clientX) - float(g["x0"]);
        dy = float(e.clientY) - float(g["y0"]);
        if not g["moved"] {
            if dx * dx + dy * dy < 16.0 {
                return;
            }
            g["moved"] = True;
            # Capture only once it is really a drag, so a plain click still
            # reaches the step under it.
            try {
                surface.setPointerCapture(e.pointerId);
            } except Exception as err {
                g["moved"] = True;
            }
            surface.style.cursor = "grabbing";
        }
        applyPan(float(g["px"]) + dx, float(g["py"]) + dy);
        return;
    }
    drag: any = dragRef.current;
    if editing and surface {
        if drag {
            surface.style.cursor = "grabbing";
        } elif wireRef.current or connectFrom {
            surface.style.cursor = "crosshair";
        } else {
            probe = surfaceXY(e);
            over = hitRect(stepsRef.current or [], drawnRects(), probe[0], probe[1]);
            if "id" in over {
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
    if not drag["moved"] and (abs(nx - drag["x"]) > 3.0 or abs(ny - drag["y"]) > 3.0) {
        drag["moved"] = True;
        dragId = drag["id"];
        try {
            surface.setPointerCapture(e.pointerId);
        } except Exception as err {
            drag["moved"] = True;
        }
    }
    # The ref carries the authoritative position: a release can beat React's
    # state flush.
    drag["lx"] = nx;
    drag["ly"] = ny;
    updated = {** live};
    updated[drag["id"]] = [nx, ny];
    live = updated;
}

impl FlowLinePage.endDrag(e: any) -> None {
    remaining: list[list[float]] = [];
    for p in (pointersRef.current or []) {
        if p[0] != float(e.pointerId) {
            remaining.append(p);
        }
    }
    pointersRef.current = remaining;
    surface: any = e.currentTarget;
    g: any = gestureRef.current;
    if g and g["kind"] == "pinch" {
        if len(remaining) < 2 {
            gestureRef.current = None;
            swallowRef.current = new(Date).getTime();
        }
        return;
    }
    if g and g["kind"] == "pan" {
        gestureRef.current = None;
        if surface {
            surface.style.cursor = "";
        }
        if g["moved"] {
            swallowRef.current = new(Date).getTime();
        }
        return;
    }
    wiring: any = wireRef.current;
    if wiring {
        wireRef.current = None;
        pos = surfaceXY(e);
        hit = hitRect(stepsRef.current or [], drawnRects(), pos[0], pos[1]);
        landed = str(hit["id"]) if "id" in hit else "";
        swallowRef.current = new(Date).getTime();
        if not landed or landed == wiring {
            # Released on empty canvas: stay armed so a click can finish it.
            return;
        }
        connectFrom = "";
        await linkSteps(wiring, landed);
        return;
    }
    drag: any = dragRef.current;
    if not drag {
        return;
    }
    dragRef.current = None;
    dragId = "";
    if not drag["moved"] {
        live = {};
        return;
    }
    swallowRef.current = new(Date).getTime();
    nx = float(drag["lx"]);
    ny = float(drag["ly"]);
    try {
        root spawn MoveStep(step_id=drag["id"], x=nx, y=ny);
        forgetWorkspace();
        await reload(projectId);
    } except Exception as err {
        toast.error("Failed to save the position");
    }
    live = {};
}
