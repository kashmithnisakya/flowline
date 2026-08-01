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
        vResult = root spawn ListVocab();
        fetchedTasks = tResult.reports[0] if tResult.reports else [];
        fetchedMembers = mResult.reports[0] if mResult.reports else [];
        fetchedProjects = pResult.reports[0] if pResult.reports else [];
        if not movesRef.current {
            tasks = fetchedTasks;
            members = fetchedMembers;
            projects = fetchedProjects;
            vocab = vResult.reports[0] if vResult.reports else [];
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
    updated = {**form};
    updated[key] = value;
    form = updated;
}

impl BoardPage.openCreate -> None {
    editingId = "";
    form = {**BLANK_TASK, "project": fProject if fProject != "all" else "none"};
    dialogOpen = True;
}

impl BoardPage.openEdit(t: TaskView) -> None {
    editingId = t.id;
    form = {
        "title": t.title, "category": t.category,
        "project": t.project_id if t.project_id else "none",
        "priority": t.priority, "status": t.status,
        "due_date": t.due_date, "notes": t.notes,
        "assignee": t.assignee_id if t.assignee_id else "none"
    };
    dialogOpen = True;
}

impl BoardPage.saveTask -> None {
    title = form["title"].strip();
    if not title {
        return;
    }
    saving = True;
    assignee = form["assignee"] if form["assignee"] != "none" else "";
    project = form["project"] if form["project"] != "none" else "";
    try {
        if editingId {
            root spawn UpdateTask(
                task_id=editingId, title=title, category=form["category"],
                priority=form["priority"], status=form["status"],
                due_date=form["due_date"], notes=form["notes"],
                assignee_id=assignee, project_id=project
            );
        } else {
            root spawn CreateTask(
                title=title, category=form["category"],
                priority=form["priority"], status=form["status"],
                due_date=form["due_date"], notes=form["notes"],
                assignee_id=assignee, project_id=project
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

impl BoardPage.moveTo(taskId: str, status: str) -> None {
    # Optimistic: mutate the card in state and rebind; the server computes
    # the authoritative end-of-column order. movesRef fences the poll so a
    # stale fetch cannot snap the card back mid-flight; on failure the board
    # refetches server truth instead of rebinding a stale local snapshot.
    oldStatus = "";
    peak = 0.0;
    for t in tasks {
        if t.id == taskId {
            oldStatus = t.status;
        }
        if t.status == status and t.sort_order > peak {
            peak = t.sort_order;
        }
    }
    if not oldStatus or oldStatus == status {
        return;
    }
    for t in tasks {
        if t.id == taskId {
            t.status = status;
            t.sort_order = peak + 1024.0;
        }
    }
    tasks = [t for t in tasks];
    movesRef.current = (movesRef.current or 0) + 1;
    failed = False;
    try {
        root spawn MoveTask(task_id=taskId, status=status);
    } except Exception as e {
        failed = True;
    }
    movesRef.current = movesRef.current - 1;
    if failed {
        toast("Move failed. Restoring the board.");
        await loadAll();
    }
}

impl BoardPage.arrowMove(t: TaskView, status: str) -> None {
    if status {
        moveTo(t.id, status);
    }
}
