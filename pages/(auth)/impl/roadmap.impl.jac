"""Implementations for the Roadmap page."""

impl RoadmapPage.loadWorkspace -> None {
    try {
        pResult = root spawn ListProjects();
        projects = pResult.reports[0] if pResult.reports else [];
        mResult = root spawn ListMembers();
        members = mResult.reports[0] if mResult.reports else [];
        sResult = root spawn GetFlowLine(with_counts=False);
        steps = sResult.reports[0] if sResult.reports else [];
        rResult = root spawn ListRoles();
        roleRows = rResult.reports[0] if rResult.reports else [];
        iResult = root spawn ListIterations();
        iterations = iResult.reports[0] if iResult.reports else [];
    } except Exception as e {
        # Non-fatal: the timeline still draws; the dialog offers fewer choices.
        members = [];
    }
}

impl RoadmapPage.loadRoadmap -> None {
    seq = (reqRef.current or 0) + 1;
    reqRef.current = seq;
    loading = True;
    try {
        result = root spawn RoadmapSnapshot(
            from_date=windowStart,
            to_date=shiftIso(windowStart, WEEKS * 7 - 1),
            project_id="" if fProject == "all" else fProject
        );
        if reqRef.current == seq {
            data = result.reports[0] if result.reports else None;
            failed = False;
        }
    } except Exception as e {
        if reqRef.current == seq {
            failed = True;
        }
    }
    if reqRef.current == seq {
        loading = False;
    }
}

impl RoadmapPage.reloadIterations -> None {
    try {
        iResult = root spawn ListIterations();
        iterations = iResult.reports[0] if iResult.reports else [];
    } except Exception as e {
        toast("Could not reload the iterations");
    }
    await loadRoadmap();
}

# ------------------------------------------------------------------ columns
# The board's column rules, so the dialog's Step select says what the board
# shows. Without a flow line the six statuses stand in.

impl RoadmapPage.columnKeys -> list[str] {
    keys: list[str] = [];
    if len(steps) > 0 {
        ordered = [st for st in steps];
        ordered.sort(key=lambda (st: StepView) { st.sort_order; });
        ordered.sort(key=lambda (st: StepView) { st.x; });
        for st in ordered {
            keys.append(st.id);
        }
        return keys;
    }
    for legacy in STATUSES {
        keys.append(legacy);
    }
    return keys;
}

impl RoadmapPage.columnKind(key: str) -> str {
    for st in steps {
        if st.id == key {
            return st.kind;
        }
    }
    return STATUS_KIND[key] if key in STATUS_KIND else "active";
}

impl RoadmapPage.columnKeyOf(t: TaskView, keys: list[str]) -> str {
    if t.step_id and t.step_id in keys {
        return t.step_id;
    }
    if t.status in keys {
        return t.status;
    }
    kind = STATUS_KIND[t.status] if t.status in STATUS_KIND else "active";
    for key in keys {
        if columnKind(key) == kind {
            return key;
        }
    }
    return keys[0] if len(keys) > 0 else "";
}

impl RoadmapPage.mappedStatus(key: str) -> str {
    if len(steps) == 0 {
        return key if key in STATUSES else "Backlog";
    }
    kind = columnKind(key);
    return KIND_STATUS[kind] if kind in KIND_STATUS else "In Progress";
}

# -------------------------------------------------------------- task dialog

impl RoadmapPage.openTask(tid: str) -> None {
    keys = columnKeys();
    shown: list[TaskView] = data["rows"] if data else [];
    for t in shown {
        if t.id == tid {
            editTaskId = t.id;
            taskForm = {
                "title": t.title,
                "category": t.category,
                "tags": ", ".join(t.tags),
                "estimate": fmtEstimate(t.estimate) if t.estimate > 0.0 else "",
                "project": t.project_id,
                "priority": t.priority,
                "status": columnKeyOf(t, keys),
                "due_date": t.due_date,
                "start_date": t.start_date,
                "iteration": t.iteration_id or "none",
                "notes": t.notes,
                "issue": t.issue_link,
                "pr": t.pr_link,
                "reviewer": t.reviewer_id or "none",
                "review_due": t.review_due
            };
            taskAssignees = t.assignee_ids;
            taskOpen = True;
        }
    }
}

# A checklist write reports the task's fresh view; the roadmap row takes it.
impl RoadmapPage.replaceRow(view: TaskView) -> None {
    if data {
        shown: list[TaskView] = data["rows"];
        data = {** data, "rows": [view if t.id == view.id else t for t in shown]};
    }
}

impl RoadmapPage.setTaskField(key: str, value: str) -> None {
    # A computed key does not survive a dict-literal spread.
    updated = {** taskForm};
    updated[key] = value;
    taskForm = updated;
}

impl RoadmapPage.toggleTaskAssignee(memberId: str) -> None {
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

impl RoadmapPage.saveTask -> None {
    title = taskForm["title"].strip();
    if not title or not editTaskId {
        return;
    }
    project = taskForm["project"];
    if not project {
        toast("Pick a project for this task");
        return;
    }
    taskSaving = True;
    reviewer = taskForm["reviewer"] if taskForm["reviewer"] != "none" else "";
    try {
        # Assigning people who are not on the task's project pulls them in.
        added = 0;
        for aid in taskAssignees {
            onProject = False;
            for m in members {
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
            mResult = root spawn ListMembers();
            members = mResult.reports[0] if mResult.reports else members;
        }
        root spawn UpdateTask(
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
            status=mappedStatus(taskForm["status"]),
            step_id=taskForm["status"] if len(steps) > 0 else "",
            due_date=taskForm["due_date"],
            start_date=taskForm["start_date"],
            iteration_id=taskForm["iteration"]
                if taskForm["iteration"] != "none"
                else "",
            notes=taskForm["notes"],
            issue_link=taskForm["issue"].strip(),
            pr_link=taskForm["pr"].strip(),
            reviewer_id=reviewer,
            review_due=taskForm["review_due"],
            assignee_ids=taskAssignees,
            project_id=project
        );
        taskOpen = False;
        await loadRoadmap();
    } except Exception as e {
        toast("Failed to save task");
    }
    taskSaving = False;
}

impl RoadmapPage.deleteTask -> None {
    if not editTaskId {
        return;
    }
    taskSaving = True;
    try {
        root spawn DeleteTask(task_id=editTaskId);
        taskOpen = False;
        await loadRoadmap();
    } except Exception as e {
        toast("Failed to delete task");
    }
    taskSaving = False;
}
