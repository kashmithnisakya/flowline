"""Implementations for the Board page."""

impl BoardPage.loadAll -> None {
    # While a move is in flight, its optimistic state is newer than
    # anything a concurrent fetch started earlier could return — skip.
    if movesRef.current {
        return;
    }
    try {
        tResult = root spawn ListTasks();
        mResult = root spawn ListMembers();
        fetchedTasks = tResult.reports[0] if tResult.reports else [];
        fetchedMembers = mResult.reports[0] if mResult.reports else [];
        if not movesRef.current {
            tasks = fetchedTasks;
            members = fetchedMembers;
        }
    } except Exception as e {
        toast("Failed to load the board");
    }
    loading = False;
}

impl BoardPage.openCreate -> None {
    editingId = "";
    tTitle = "";
    tCategory = "";
    tTeam = fTeam if fTeam != "All" else "";
    tPriority = "Medium";
    tStatus = "Backlog";
    tDueDate = "";
    tNotes = "";
    tAssignee = "none";
    dialogOpen = True;
}

impl BoardPage.openEdit(t: TaskView) -> None {
    editingId = t.id;
    tTitle = t.title;
    tCategory = t.category;
    tTeam = t.team;
    tPriority = t.priority;
    tStatus = t.status;
    tDueDate = t.due_date;
    tNotes = t.notes;
    tAssignee = t.assignee_id if t.assignee_id else "none";
    dialogOpen = True;
}

impl BoardPage.saveTask -> None {
    if not tTitle.strip() or not tTeam {
        return;
    }
    saving = True;
    assignee = tAssignee if tAssignee != "none" else "";
    try {
        if editingId {
            root spawn UpdateTask(
                task_id=editingId, title=tTitle.strip(), category=tCategory,
                team=tTeam, priority=tPriority, status=tStatus,
                due_date=tDueDate, notes=tNotes, assignee_id=assignee
            );
        } else {
            root spawn CreateTask(
                title=tTitle.strip(), category=tCategory, team=tTeam,
                priority=tPriority, status=tStatus, due_date=tDueDate,
                notes=tNotes, assignee_id=assignee
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
    # stale fetch can't snap the card back mid-flight; on failure the board
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
        toast("Move failed — restoring the board");
        await loadAll();
    }
}

impl BoardPage.arrowMove(t: TaskView, status: str) -> None {
    if status {
        moveTo(t.id, status);
    }
}
