"""Implementations for the Board page."""

impl BoardPage.boot -> None {
    # Onboarding gate: a workspace with no projects yet goes to the wizard.
    # (The organization itself is created at signup.)
    try {
        projResult = root spawn ListProjects();
        existing = projResult.reports[0] if projResult.reports else [];
        if len(existing) == 0 {
            window.location.href = "/setup";
            return;
        }
    } except Exception as e {
        toast("Failed to load your workspace");
    }
    # Cheap and never fails on its own: it only decides whether the board
    # offers the GitHub affordances at all.
    try {
        gResult = root spawn GithubStatus();
        if gResult.reports {
            ghConnected = gResult.reports[0].connected;
        }
    } except Exception as e {
        ghConnected = False;
    }
    await loadAll();
}

impl BoardPage.loadAll -> None {
    # While a move is in flight its optimistic state is newer than anything
    # a concurrent fetch started earlier could return — skip.
    if movesRef.current {
        return;
    }
    try {
        tResult = root spawn ListTasks();
        mResult = root spawn ListMembers();
        pResult = root spawn ListProjects();
        sResult = root spawn GetWorkflow();
        rResult = root spawn ListRepos();
        fetchedTasks = tResult.reports[0] if tResult.reports else [];
        fetchedMembers = mResult.reports[0] if mResult.reports else [];
        fetchedProjects = pResult.reports[0] if pResult.reports else [];
        if not movesRef.current {
            tasks = fetchedTasks;
            members = fetchedMembers;
            projects = fetchedProjects;
            steps = sResult.reports[0] if sResult.reports else [];
            repos = rResult.reports[0] if rResult.reports else [];
        }
        # A stale persisted filter (archived project) would show an empty
        # board with no hint — reset it to "all".
        stored = localStorage.getItem("standup_project") or "";
        if stored and stored != "all" {
            found = False;
            for p in fetchedProjects {
                if jid(p) == stored and p.active {
                    found = True;
                }
            }
            if not found {
                localStorage.setItem("standup_project", "all");
                fProject = "all";
            }
        }
    } except Exception as e {
        toast("Failed to load the board");
    }
    loading = False;
}

impl BoardPage.setProjectFilter(v: str) -> None {
    fProject = v;
    localStorage.setItem("standup_project", v);
}

impl BoardPage.setField(key: str, value: str) -> None {
    # NOTE: `{**form, key: value}` compiles to a JS object literal with a
    # LITERAL "key" property — the variable is ignored and the real field
    # never updates (inputs appear frozen). Build a copy and subscript it.
    updated = {** form};
    updated[key] = value;
    form = updated;
}

impl BoardPage.openCreate -> None {
    editingId = "";
    d = new(Date);
    shifted = new(Date, d.getTime() - d.getTimezoneOffset() * 60000);
    # A new task lands in the first column of the workflow (or the first
    # legacy status), never a hardcoded "Backlog" that may not exist.
    keys = columnKeys();
    form = {
        ** BLANK_TASK,
        "project": fProject if fProject != "all" else "none",
        "status": keys[0] if keys else "Backlog",
        "due_date": shifted.toISOString()[:10]
    };
    fAssignees = [];
    dialogOpen = True;
}

impl BoardPage.openEdit(t: TaskView) -> None {
    editingId = t.id;
    form = {
        "title": t.title,
        "category": t.category,
        "project": t.project_id or "none",
        "priority": t.priority,
        "status": columnKeyOf(t),
        "due_date": t.due_date,
        "notes": t.notes,
        "issue": t.issue_link,
        "pr": t.pr_link,
        "reviewer": t.reviewer_id or "none",
        "review_due": t.review_due
    };
    fAssignees = t.assignee_ids;
    dialogOpen = True;
}

impl BoardPage.saveTask -> None {
    title = form["title"].strip();
    if not title {
        return;
    }
    saving = True;
    project = form["project"] if form["project"] != "none" else "";
    reviewer = form["reviewer"] if form["reviewer"] != "none" else "";
    try {
        # Assigning people who are not on the task's project pulls them in.
        if project {
            added = 0;
            for aid in fAssignees {
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
            }
        }
        if editingId {
            root spawn UpdateTask(
                task_id=editingId,
                title=title,
                category=form["category"],
                priority=form["priority"],
                status=mappedStatus(form["status"]),
                step_id=form["status"] if len(steps) > 0 else "",
                due_date=form["due_date"],
                notes=form["notes"],
                issue_link=form["issue"].strip(),
                pr_link=form["pr"].strip(),
                reviewer_id=reviewer,
                review_due=form["review_due"],
                assignee_ids=fAssignees,
                project_id=project
            );
        } else {
            cResult = root spawn CreateTask(
                title=title,
                category=form["category"],
                priority=form["priority"],
                status=mappedStatus(form["status"]),
                step_id=form["status"] if len(steps) > 0 else "",
                due_date=form["due_date"],
                notes=form["notes"],
                issue_link=form["issue"].strip(),
                assignee_ids=fAssignees,
                project_id=project
            );
        }
        dialogOpen = False;
        await loadAll();
    } except Exception as e {
        toast("Failed to save task");
    }
    saving = False;
}

impl BoardPage.deleteTask -> None {
    if not editingId {
        return;
    }
    saving = True;
    try {
        root spawn DeleteTask(task_id=editingId);
        dialogOpen = False;
        await loadAll();
    } except Exception as e {
        toast("Failed to delete task");
    }
    saving = False;
}

# ------------------------------------------------------------------ columns
# The board's columns are the org's workflow steps. Until an org designs one,
# the classic six statuses stand in, so a brand-new workspace still has a
# board. Every helper works in both modes.

impl BoardPage.columnKeys -> list[str] {
    keys: list[str] = [];
    if len(steps) > 0 {
        # Left-to-right on the canvas, so the board reads in the order the
        # org DREW its workflow rather than the order the steps happened to
        # be created in. Ties (a vertical branch) fall back to sort_order,
        # which keeps the result stable.
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

impl BoardPage.columnLabel(key: str) -> str {
    for st in steps {
        if st.id == key {
            return st.name;
        }
    }
    return key if key in STATUSES else "";
}

impl BoardPage.columnKind(key: str) -> str {
    for st in steps {
        if st.id == key {
            return st.kind;
        }
    }
    return STATUS_KIND[key] if key in STATUS_KIND else "active";
}

impl BoardPage.doneColumnKey -> str {
    for key in columnKeys() {
        if columnKind(key) == "done" {
            return key;
        }
    }
    return "";
}

# The legacy status a column stands for. Written alongside step_id on every
# move so insights, GitHub sync and the assistant keep reading `status`.
impl BoardPage.mappedStatus(key: str) -> str {
    # Without a workflow the key already IS the status; routing it through
    # kind would collapse "Changes Requested" into "In Progress".
    if len(steps) == 0 {
        return key if key in STATUSES else "Backlog";
    }
    kind = columnKind(key);
    return KIND_STATUS[kind] if kind in KIND_STATUS else "In Progress";
}

# Which column a task is drawn in. A task written before workflows existed
# (or whose step was deleted) has no step_id, so its status decides: it lands
# in the first column of the matching kind.
impl BoardPage.columnKeyOf(t: TaskView) -> str {
    keys = columnKeys();
    if t.step_id {
        for key in keys {
            if key == t.step_id {
                return key;
            }
        }
    }
    # Legacy mode: the column key IS the status, so match it exactly first.
    # STATUS_KIND collapses "Changes Requested" onto "In Progress"'s kind, so
    # the fallback below would swallow that whole column.
    for key in keys {
        if key == t.status {
            return key;
        }
    }
    kind = STATUS_KIND[t.status] if t.status in STATUS_KIND else "active";
    for key in keys {
        if columnKind(key) == kind {
            return key;
        }
    }
    return keys[0] if keys else "";
}

impl BoardPage.moveTo(taskId: str, columnKey: str) -> None {
    # Optimistic: mutate the card in state and rebind; the server computes
    # the authoritative end-of-column order. movesRef fences the poll so a
    # stale fetch cannot snap the card back mid-flight; on failure the board
    # refetches server truth instead of rebinding a stale local snapshot.
    # A column key is a workflow step jid, or a legacy status string when the
    # org has not designed a workflow yet. Both land in the same walker.
    onWorkflow = len(steps) > 0;
    label = columnLabel(columnKey);
    if not label {
        return;
    }
    oldKey = "";
    oldLabel = "";
    peak = 0.0;
    for t in tasks {
        if t.id == taskId {
            oldKey = columnKeyOf(t);
            oldLabel = columnLabel(oldKey);
        }
        if columnKeyOf(t) == columnKey and t.sort_order > peak {
            peak = t.sort_order;
        }
    }
    if not oldKey or oldKey == columnKey {
        return;
    }
    landing = mappedStatus(columnKey);
    for t in tasks {
        if t.id == taskId {
            t.status = landing;
            t.step_id = columnKey if onWorkflow else "";
            t.sort_order = peak + 1024.0;
        }
    }
    tasks = [t for t in tasks];
    movesRef.current = (movesRef.current or 0) + 1;
    failed = False;
    try {
        if onWorkflow {
            root spawn MoveTask(task_id=taskId, step_id=columnKey, step_name=label);
        } else {
            root spawn MoveTask(task_id=taskId, status=columnKey);
        }
    } except Exception as e {
        failed = True;
    }
    movesRef.current = movesRef.current - 1;
    title = "";
    for t in tasks {
        if t.id == taskId {
            title = t.title;
        }
    }
    if failed {
        toast("Move failed. Restoring the board.");
        await loadAll();
        return;
    }
    # Every successful move confirms itself and offers the undo: a card can
    # land out of sight (Hide Done, or a column below the fold), and the
    # handoff dialog is skippable, so it cannot be the only feedback.
    toast(
        "Moved to " + label,
        {
            "description": title,
            "action": {"label": "Undo", "onClick": lambda { moveTo(taskId, oldKey); }}
        }
    );
    if columnKind(columnKey) in HANDOFF_KINDS {
        # A handoff or a stop also asks for the optional detail.
        mForm = BLANK_MOVE;
        moveStatus = label;
        moveKind = columnKind(columnKey);
        moveTaskTitle = title;
        moveTaskId = taskId;
    }
}

impl BoardPage.setMoveField(key: str, value: str) -> None {
    updated = {** mForm};
    updated[key] = value;
    mForm = updated;
}

impl BoardPage.toggleAssignee(memberId: str) -> None {
    if memberId in fAssignees {
        fAssignees = [
            a
            for a in fAssignees
            if a != memberId
        ];
    } else {
        fAssignees = fAssignees + [memberId];
    }
}

impl BoardPage.saveMoveInfo -> None {
    saving = True;
    try {
        root spawn SetMoveInfo(
            task_id=moveTaskId,
            reviewer_id=mForm["reviewer"] if mForm["reviewer"] != "none" else "",
            review_due=mForm["review_due"],
            pr_link=mForm["pr"].strip(),
            note=mForm["note"].strip()
        );
        moveTaskId = "";
        await loadAll();
    } except Exception as e {
        toast("Failed to save the handoff details");
    }
    saving = False;
}

impl BoardPage.arrowMove(t: TaskView, columnKey: str) -> None {
    if columnKey {
        moveTo(t.id, columnKey);
    }
}

impl BoardPage.markDoneFromPr(taskId: str) -> None {
    # Routed through the normal move so the card still gets its log entry
    # and its undo toast. A merged PR suggests done, it never forces it.
    for key in columnKeys() {
        if columnKind(key) == "done" {
            moveTo(taskId, key);
            return;
        }
    }
}

impl BoardPage.syncGithub -> None {
    if syncing {
        return;
    }
    syncing = True;
    try {
        result = root spawn SyncGithub();
        payload = result.reports[0] if result.reports else None;
        if payload and payload["ok"] {
            # loadAll owns the refresh, including the movesRef fence: an
            # in-flight drag keeps its optimistic state and the next poll
            # picks the synced values up.
            await loadAll();
            toast("Synced " + str(payload["synced"]) + " tasks");
        } else {
            toast(str(payload["message"]) if payload else "Sync failed");
        }
    } except Exception as e {
        toast("Failed to sync with GitHub");
    }
    syncing = False;
}

impl BoardPage.createIssue(repoId: str) -> None {
    if not editingId or not repoId {
        return;
    }
    saving = True;
    try {
        result = root spawn CreateIssueFromTask(task_id=editingId, repo_id=repoId);
        payload = result.reports[0] if result.reports else None;
        if payload and payload["ok"] {
            opened = payload["task"];
            toast("Opened issue #" + str(opened["gh_issue_number"]));
            await loadAll();
        } else {
            toast(str(payload["message"]) if payload else "Could not open the issue");
        }
    } except Exception as e {
        toast("Failed to open a GitHub issue");
    }
    saving = False;
}
