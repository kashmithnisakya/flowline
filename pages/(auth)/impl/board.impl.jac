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
        vResult = root spawn ListVocab();
        sResult = root spawn ListMilestones();
        rResult = root spawn ListRepos();
        fetchedTasks = tResult.reports[0] if tResult.reports else [];
        fetchedMembers = mResult.reports[0] if mResult.reports else [];
        fetchedProjects = pResult.reports[0] if pResult.reports else [];
        if not movesRef.current {
            tasks = fetchedTasks;
            members = fetchedMembers;
            projects = fetchedProjects;
            vocab = vResult.reports[0] if vResult.reports else [];
            milestones = sResult.reports[0] if sResult.reports else [];
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
    updated = {**form};
    updated[key] = value;
    # A milestone lives on exactly one project, so the previous pick is
    # meaningless the moment the project changes. Both keys go into the
    # SAME copy: two assignments would make the second read a stale `form`.
    if key == "project" {
        updated["milestone"] = "none";
    }
    form = updated;
}

impl BoardPage.openCreate -> None {
    editingId = "";
    d = new(Date);
    shifted = new(Date, d.getTime() - d.getTimezoneOffset() * 60000);
    form = {
        **BLANK_TASK,
        "project": fProject if fProject != "all" else "none",
        "due_date": shifted.toISOString()[:10]
    };
    fAssignees = [];
    dialogOpen = True;
}

impl BoardPage.openEdit(t: TaskView) -> None {
    editingId = t.id;
    form = {
        "title": t.title, "category": t.category,
        "project": t.project_id if t.project_id else "none",
        "milestone": t.milestone_id if t.milestone_id else "none",
        "priority": t.priority, "status": t.status,
        "due_date": t.due_date, "notes": t.notes,
        "issue": t.issue_link, "pr": t.pr_link,
        "reviewer": t.reviewer_id if t.reviewer_id else "none",
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
    milestone = form["milestone"] if form["milestone"] != "none" else "";
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
                task_id=editingId, title=title, category=form["category"],
                priority=form["priority"], status=form["status"],
                due_date=form["due_date"], notes=form["notes"],
                issue_link=form["issue"].strip(), pr_link=form["pr"].strip(),
                reviewer_id=reviewer, review_due=form["review_due"],
                assignee_ids=fAssignees, project_id=project
            );
            # Always, including the empty case: that is how a task gets
            # detached from the milestone it used to sit on.
            root spawn SetTaskMilestone(
                task_id=editingId, milestone_id=milestone
            );
        } else {
            cResult = root spawn CreateTask(
                title=title, category=form["category"],
                priority=form["priority"], status=form["status"],
                due_date=form["due_date"], notes=form["notes"],
                issue_link=form["issue"].strip(),
                assignee_ids=fAssignees, project_id=project
            );
            created = cResult.reports[0] if cResult.reports else None;
            # A brand new task has nothing to detach, so the walker only
            # runs when there is an actual milestone to attach it to.
            if created and milestone {
                root spawn SetTaskMilestone(
                    task_id=created.id, milestone_id=milestone
                );
            }
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
        "Moved to " + status,
        {
            "description": title,
            "action": {
                "label": "Undo",
                "onClick": lambda { moveTo(taskId, oldStatus); }
            }
        }
    );
    if status in HANDOFF_STATUSES {
        # Review / Blocked / Changes Requested also ask for optional detail.
        mForm = BLANK_MOVE;
        moveStatus = status;
        moveTaskTitle = title;
        moveTaskId = taskId;
    }
}

impl BoardPage.setMoveField(key: str, value: str) -> None {
    updated = {**mForm};
    updated[key] = value;
    mForm = updated;
}

impl BoardPage.toggleAssignee(memberId: str) -> None {
    if memberId in fAssignees {
        fAssignees = [a for a in fAssignees if a != memberId];
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

impl BoardPage.arrowMove(t: TaskView, status: str) -> None {
    if status {
        moveTo(t.id, status);
    }
}

impl BoardPage.markDoneFromPr(taskId: str) -> None {
    # Routed through the normal move so the card still gets its log entry
    # and its undo toast. A merged PR suggests Done, it never forces it.
    moveTo(taskId, "Done");
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
        result = root spawn CreateIssueFromTask(
            task_id=editingId, repo_id=repoId
        );
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
