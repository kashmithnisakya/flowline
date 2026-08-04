"""Implementations for the Roadmap page.

Every loader takes the project id as an argument rather than reading
`projectId` back: a `has` read after a walker call is the render-time
snapshot, so a freshly picked project would still load the previous one.
"""

impl RoadmapPage.boot -> None {
    # Onboarding gate: a workspace with no projects yet goes to the wizard,
    # exactly as the board does.
    picked = "";
    try {
        projResult = root spawn ListProjects();
        existing = projResult.reports[0] if projResult.reports else [];
        if len(existing) == 0 {
            window.location.href = "/setup";
            return;
        }
        projects = existing;
        for p in existing {
            if p.active and not picked {
                picked = jid(p);
            }
        }
        projectId = picked;
    } except Exception as e {
        toast("Failed to load your workspace");
    }
    await loadAll(picked);
}

impl RoadmapPage.loadAll(pid: str) -> None {
    if not pid {
        milestones = [];
        tasks = [];
        loading = False;
        return;
    }
    try {
        mResult = root spawn ListMilestones(project_id=pid);
        tResult = root spawn ListTasks();
        milestones = mResult.reports[0] if mResult.reports else [];
        tasks = tResult.reports[0] if tResult.reports else [];
    } except Exception as e {
        toast("Failed to load the roadmap");
    }
    loading = False;
}

impl RoadmapPage.selectProject(v: str) -> None {
    projectId = v;
    loading = True;
    selectedId = "";
    selectedEdge = "";
    connectFrom = "";
    manual = {};
    hasManual = False;
    await loadAll(v);
}

impl RoadmapPage.setField(key: str, value: str) -> None {
    # NOTE: `{**form, key: value}` compiles to a JS object literal with a
    # LITERAL "key" property, which freezes every bound input. Copy, then
    # subscript.
    updated = {**form};
    updated[key] = value;
    form = updated;
}

impl RoadmapPage.openCreate -> None {
    editingId = "";
    form = BLANK_MILESTONE;
    confirmDelete = False;
    dialogOpen = True;
}

impl RoadmapPage.openEdit(m: MilestoneView) -> None {
    editingId = m.id;
    form = {
        "title": m.title,
        "description": m.description,
        "start_date": m.start_date,
        "due_date": m.due_date,
        "status": m.status if m.status else "Planned",
        "color": m.color if m.color else "sky"
    };
    confirmDelete = False;
    dialogOpen = True;
}

impl RoadmapPage.saveMilestone -> None {
    title = form["title"].strip();
    if not title or not projectId {
        return;
    }
    if form["start_date"] and form["due_date"] and form["due_date"] < form["start_date"] {
        toast("The target date is before the start date");
        return;
    }
    saving = True;
    pid = projectId;
    creating = not editingId;
    try {
        root spawn SaveMilestone(
            milestone_id=editingId, project_id=pid, title=title,
            description=form["description"], start_date=form["start_date"],
            due_date=form["due_date"], status=form["status"], color=form["color"]
        );
        dialogOpen = False;
        confirmDelete = False;
        await loadAll(pid);
        if creating {
            toast(title + " is on the canvas; drag from its border to connect it");
        }
    } except Exception as e {
        toast("Failed to save the milestone");
    }
    saving = False;
}

impl RoadmapPage.deleteMilestone -> None {
    if not editingId {
        return;
    }
    # First click arms, the second one deletes. Nothing but the phase goes:
    # the tasks lose their InMilestone edge and stay on the board.
    if not confirmDelete {
        confirmDelete = True;
        return;
    }
    saving = True;
    pid = projectId;
    gone = editingId;
    try {
        root spawn DeleteMilestone(milestone_id=gone);
        dialogOpen = False;
        confirmDelete = False;
        if gone in manual {
            left = {k: v for (k, v) in manual.items() if k != gone};
            manual = left;
            hasManual = False;
            for k in left {
                hasManual = True;
            }
        }
        if selectedId == gone {
            selectedId = "";
        }
        if connectFrom == gone {
            connectFrom = "";
        }
        await loadAll(pid);
    } except Exception as e {
        toast("Failed to delete the milestone");
    }
    saving = False;
}

impl RoadmapPage.openAttach(milestoneId: str) -> None {
    attachStoneId = milestoneId;
    attachIds = [];
    attachOpen = True;
}

impl RoadmapPage.toggleAttach(taskId: str) -> None {
    if taskId in attachIds {
        attachIds = [a for a in attachIds if a != taskId];
    } else {
        attachIds = attachIds + [taskId];
    }
}

impl RoadmapPage.confirmAttach -> None {
    if not attachStoneId or len(attachIds) == 0 {
        attachOpen = False;
        return;
    }
    # Read the picks and the target into locals: both are render-time
    # snapshots once the loop starts calling walkers.
    picks = attachIds;
    stone = attachStoneId;
    pid = projectId;
    saving = True;
    try {
        for tid in picks {
            root spawn SetTaskMilestone(task_id=tid, milestone_id=stone);
        }
        attachOpen = False;
        attachStoneId = "";
        attachIds = [];
        await loadAll(pid);
    } except Exception as e {
        toast("Failed to add the tasks");
    }
    saving = False;
}

impl RoadmapPage.detachTask(taskId: str) -> None {
    pid = projectId;
    try {
        root spawn SetTaskMilestone(task_id=taskId, milestone_id="");
        await loadAll(pid);
    } except Exception as e {
        toast("Failed to take the task off the milestone");
    }
}

impl RoadmapPage.selectStep(stepId: str) -> None {
    # A drag ends with a click on the node it started from, so the drag marks
    # that one click to be ignored; without this, moving a step also selects
    # it and finishing a wire also re-fires the connect.
    if swallowRef.current {
        swallowRef.current = False;
        return;
    }
    # A click while armed means "connect to this one"; otherwise it selects.
    if connectFrom and connectFrom != stepId {
        source = connectFrom;
        connectFrom = "";
        linkSteps(source, stepId);
        return;
    }
    selectedId = stepId;
    selectedEdge = "";
}

impl RoadmapPage.armConnect -> None {
    if selectedId {
        connectFrom = selectedId;
        selectedEdge = "";
    }
}

impl RoadmapPage.clearCanvas -> None {
    connectFrom = "";
    selectedEdge = "";
    selectedId = "";
}

impl RoadmapPage.linkSteps(fromId: str, toId: str) -> None {
    pid = projectId;
    try {
        result = root spawn LinkSteps(from_id=fromId, to_id=toId);
        payload = result.reports[0] if result.reports else None;
        if payload and payload["ok"] {
            # Any new arrow re-shapes the whole picture, so refetch rather
            # than patching a layout the server owns.
            await loadAll(pid);
            if not payload["duplicate"] {
                toast("Connected", {
                    "action": {
                        "label": "Undo",
                        "onClick": lambda { deleteEdge(fromId, toId); }
                    }
                });
            }
        } elif payload {
            toast(payload["message"] or "That connection is not allowed.");
        }
    } except Exception as e {
        toast("Could not connect those steps");
    }
}

impl RoadmapPage.deleteEdge(fromId: str, toId: str) -> None {
    pid = projectId;
    selectedEdge = "";
    try {
        root spawn UnlinkSteps(from_id=fromId, to_id=toId);
        await loadAll(pid);
    } except Exception as e {
        toast("Could not remove that connection");
    }
}

# Flow's grid geometry, mirrored here so a pointer position maps back to a
# cell. These MUST match components/roadmap/Flow.jac; a change there without a
# change here silently misplaces every drag.
glob LANE_PX: float = 240.0;
glob ROW_PX: float = 140.0;
glob PAD: float = 40.0;
glob NODE_W: float = 208.0;
glob NODE_W_B: float = 184.0;
# How close to a node's edge counts as grabbing its border rather than its body.
glob EDGE_ZONE: float = 14.0;

# The cell a step is actually drawn in: its dragged override, else the one the
# walker computed from the arrows.
def cellFor(s: MilestoneView, cells: dict[str, list[int]]) -> list[int] {
    if s.id in cells {
        return cells[s.id];
    }
    return [s.depth, s.lane];
}

# Which step is under the pointer, and whether the pointer is in its border
# strip. Flow positions each node with an inline left/top, so matching those
# numbers against the cell arithmetic identifies the step without Flow having
# to expose anything.
impl RoadmapPage.hitNode(e: MouseEvent) -> dict[str, any] {
    miss: dict[str, any] = {};
    target: any = e.target;
    if not target or not target.closest {
        return miss;
    }
    btn: any = target.closest("button");
    if not btn or not btn.style or not btn.style.left or not btn.style.width {
        return miss;
    }
    # Only a real node carries an inline width this wide; the test also filters
    # the 20px chip that removes an arrow.
    if float(parseFloat(btn.style.width)) < 100.0 {
        return miss;
    }
    left = float(parseFloat(btn.style.left));
    top = float(parseFloat(btn.style.top));
    # The ref holds the same list Flow was handed; typing it here is what lets
    # the arithmetic below stay checked.
    # Same effective cell Flow drew with, or the hit test lands on the
    # pre-drag position of anything that has been moved.
    cells: dict[str, list[int]] = manualRef.current or {};
    grid: list[MilestoneView] = [];
    for raw in (stepsRef.current or []) {
        step = raw as MilestoneView;
        if cellFor(step, cells)[0] >= 0 {
            grid.append(step);
        }
    }
    minLane = 0;
    for s in grid {
        if cellFor(s, cells)[1] < minLane {
            minLane = cellFor(s, cells)[1];
        }
    }
    found: list[MilestoneView] = [];
    for s in grid {
        cell = cellFor(s, cells);
        width = NODE_W if cell[1] == 0 else NODE_W_B;
        centre = PAD + float(cell[1] - minLane) * LANE_PX + LANE_PX / 2.0;
        if abs(centre - width / 2.0 - left) < 2.0
            and abs(PAD + float(cell[0]) * ROW_PX - top) < 2.0 {
            found.append(s);
        }
    }
    if not found {
        return miss;
    }
    box: any = btn.getBoundingClientRect();
    dx = float(e.clientX) - float(box.left);
    dy = float(e.clientY) - float(box.top);
    onEdge = (
        dx < EDGE_ZONE or dy < EDGE_ZONE
        or (float(box.width) - dx) < EDGE_ZONE
        or (float(box.height) - dy) < EDGE_ZONE
    );
    return {"step": found[0], "onEdge": onEdge};
}

impl RoadmapPage.beginDrag(e: MouseEvent) -> None {
    if connectFrom {
        return;
    }
    hit = hitNode(e);
    if not hit {
        return;
    }
    e.preventDefault();
    step = hit["step"] as MilestoneView;
    if hit["onEdge"] {
        # The border is the port: dragging off it draws an arrow.
        wireRef.current = step.id;
        connectFrom = step.id;
        selectedId = step.id;
        selectedEdge = "";
        return;
    }
    start = cellFor(step, manualRef.current or {});
    dragRef.current = {
        "id": step.id, "x": float(e.clientX), "y": float(e.clientY),
        "depth": start[0], "lane": start[1], "moved": False
    };
}

impl RoadmapPage.moveDrag(e: MouseEvent) -> None {
    surface: any = e.currentTarget;
    drag = dragRef.current;
    if surface {
        if drag {
            surface.style.cursor = "grabbing";
        } elif wireRef.current or connectFrom {
            surface.style.cursor = "crosshair";
        } else {
            over = hitNode(e);
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
    row = int(drag["depth"]) + int(round((float(e.clientY) - float(drag["y"])) / ROW_PX));
    if row < 0 {
        row = 0;
    }
    col = int(drag["lane"]) + int(round((float(e.clientX) - float(drag["x"])) / LANE_PX));
    current = manual[drag["id"]] if drag["id"] in manual else [];
    atRow = current[0] if current else int(drag["depth"]);
    atCol = current[1] if current else int(drag["lane"]);
    if atRow == row and atCol == col {
        return;
    }
    if row != int(drag["depth"]) or col != int(drag["lane"]) {
        drag["moved"] = True;
    }
    updated = {**manual};
    updated[drag["id"]] = [row, col];
    manual = updated;
    hasManual = True;
}

impl RoadmapPage.endDrag(e: MouseEvent) -> None {
    wiring = wireRef.current;
    if wiring {
        wireRef.current = None;
        hit = hitNode(e);
        landed = (hit["step"] as MilestoneView).id if hit else "";
        if not landed or landed == wiring {
            # Released on empty canvas: stay armed so the click path can finish
            # the connection instead of silently losing the aim.
            return;
        }
        swallowRef.current = True;
        if landed in blockedTargets {
            connectFrom = "";
            toast("That arrow would loop back on itself");
            return;
        }
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
        return;
    }
    swallowRef.current = True;
    cell = manual[drag["id"]] if drag["id"] in manual else [];
    if not cell {
        return;
    }
    # Two steps in one cell would overlap, so the one already there takes the
    # dragged step's old cell.
    seen: dict[str, list[int]] = manualRef.current or {};
    clash: list[MilestoneView] = [];
    for raw in (stepsRef.current or []) {
        other = raw as MilestoneView;
        cellAt = cellFor(other, seen);
        if other.id != drag["id"] and cellAt[0] == cell[0] and cellAt[1] == cell[1] {
            clash.append(other);
        }
    }
    if clash {
        swapped = {**manual};
        swapped[clash[0].id] = [int(drag["depth"]), int(drag["lane"])];
        manual = swapped;
        hasManual = True;
        toast("Swapped with " + clash[0].title);
    }
}

impl RoadmapPage.resetLayout -> None {
    manual = {};
    hasManual = False;
    toast("Layout back to the arrows");
}
