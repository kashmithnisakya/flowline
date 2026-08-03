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
        "color": m.color if m.color else "violet"
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
    try {
        root spawn SaveMilestone(
            milestone_id=editingId, project_id=pid, title=title,
            description=form["description"], start_date=form["start_date"],
            due_date=form["due_date"], status=form["status"], color=form["color"]
        );
        dialogOpen = False;
        confirmDelete = False;
        await loadAll(pid);
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
    try {
        root spawn DeleteMilestone(milestone_id=editingId);
        dialogOpen = False;
        confirmDelete = False;
        await loadAll(pid);
    } except Exception as e {
        toast("Failed to delete the milestone");
    }
    saving = False;
}

impl RoadmapPage.moveMilestone(milestoneId: str, delta: int) -> None {
    at = indexOf(milestones, milestoneId);
    target = at + delta;
    if at < 0 or target < 0 or target >= len(milestones) {
        return;
    }
    # ReorderMilestone names the sibling to land AFTER, so moving up means
    # naming the one two slots back, or the empty id for the front.
    afterId = "";
    if delta < 0 {
        afterId = milestones[at - 2].id if at >= 2 else "";
    } else {
        afterId = milestones[at + 1].id;
    }
    pid = projectId;
    try {
        root spawn ReorderMilestone(milestone_id=milestoneId, after_id=afterId);
        await loadAll(pid);
    } except Exception as e {
        toast("Failed to reorder the milestones");
    }
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
