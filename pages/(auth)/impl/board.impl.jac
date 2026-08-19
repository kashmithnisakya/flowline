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
    # a concurrent fetch started earlier could return, skip.
    if movesRef.current {
        return;
    }
    try {
        # The working set comes in pages of 500 so a big board still paints
        # after the first. The loop is bounded; if the server still has more
        # at the bound the board says so rather than quietly showing part of
        # the workspace. Filters stay client-side (instant to flip), so
        # `older` here is the unfiltered count of what the cutoff left out.
        fetchedTasks: list[TaskView] = [];
        olderUnfiltered = 0;
        pageNo = 1;
        more = True;
        while more and pageNo <= 20 {
            tResult = root spawn ListTasks(scope="working", page=pageNo, page_size=500);
            tPage = tResult.reports[0] if tResult.reports else None;
            if not tPage {
                more = False;
            } else {
                fetchedTasks = fetchedTasks + tPage.rows;
                more = tPage.has_more;
                olderUnfiltered = tPage.older;
            }
            pageNo = pageNo + 1;
        }
        truncated = more;
        cResult = root spawn TaskCounts();
        mResult = root spawn ListMembers();
        pResult = root spawn ListProjects();
        # The board counts its own columns; skipping the server's per-step
        # count spares a walk over every task on each poll.
        sResult = root spawn GetFlowLine(with_counts=False);
        rResult = root spawn ListRepos();
        fetchedMembers = mResult.reports[0] if mResult.reports else [];
        fetchedProjects = pResult.reports[0] if pResult.reports else [];
        if not movesRef.current {
            tasks = fetchedTasks;
            members = fetchedMembers;
            projects = fetchedProjects;
            steps = sResult.reports[0] if sResult.reports else [];
            repos = rResult.reports[0] if rResult.reports else [];
            workingTruncated = truncated;
            cPayload = cResult.reports[0] if cResult.reports else None;
            if cPayload {
                knownCategories = cPayload.categories;
            }
            # A filtered fetch owns the count while filters are on; the poll
            # only refreshes the unfiltered one. The stamp, not the `has`
            # fields, says which filters are live: on the boot path the
            # entry ability set them in this same tick.
            if not filterRef.current or filterRef.current == "all|All|All" {
                olderTotal = olderUnfiltered;
            }
        }
        loadFailed = False;
        d = new(Date);
        hh = str(d.getHours());
        mm = str(d.getMinutes());
        loadedAt = ("0" + hh if len(hh) < 2 else hh) + ":" + (
            "0" + mm if len(mm) < 2 else mm
        );
        # A stale persisted filter (archived project) would show an empty
        # board with no hint, reset it to "all".
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
        # No toast: the page itself says so (full panel with nothing on
        # screen, a strip with data still showing), and a toast per failed
        # 60s poll would only nag.
        loadFailed = True;
    }
    loading = False;
    retrying = False;
}

impl BoardPage.retryLoad -> None {
    if movesRef.current {
        return;
    }
    retrying = True;
    await loadAll();
}

impl BoardPage.filtersOn(pid: str, who: str, cat: str) -> bool {
    return pid != "all" or who != "All" or cat != "All";
}

impl BoardPage.setProjectFilter(v: str) -> None {
    # The new value is handed to refreshOlder rather than read back: a
    # `has` assigned here is still the old value for the rest of this call.
    fProject = v;
    localStorage.setItem("standup_project", v);
    refreshOlder(v, fAssignee, fCategory);
}

impl BoardPage.setAssigneeFilter(v: str) -> None {
    fAssignee = v;
    refreshOlder(fProject, v, fCategory);
}

impl BoardPage.setCategoryFilter(v: str) -> None {
    fCategory = v;
    refreshOlder(fProject, fAssignee, v);
}

impl BoardPage.toggleOlder -> None {
    opening = not showAllDone;
    showAllDone = opening;
    if opening and len(olderDone) == 0 {
        loadOlder(1, fProject, fAssignee, fCategory);
    }
}

impl BoardPage.loadOlder(page: int, pid: str, who: str, cat: str) -> None {
    # Filters go to the server here (unlike the working set) because the
    # history is paged: a page filtered on the client would run short and
    # its total would lie.
    if olderRef.current {
        return;
    }
    olderRef.current = True;
    loadingOlder = True;
    # What this request is for. A filter change bumps the stamp, and a late
    # answer to the previous filters is dropped instead of mixed in.
    stamp = pid + "|" + who + "|" + cat;
    filterRef.current = stamp;
    # Rows already on screen come from the ref: `olderDone` read after the
    # await is the value from the render that started this call.
    have: list[TaskView] = rowsRef.current or [];
    try {
        result = root spawn ListTasks(
            scope="older",
            project_id=pid if pid != "all" else "",
            assignee_id=who if who != "All" else "",
            category=cat if cat != "All" else "",
            page=page,
            page_size=50
        );
        got = result.reports[0] if result.reports else None;
        if got and filterRef.current == stamp {
            merged = (have + got.rows) if page > 1 else got.rows;
            rowsRef.current = merged;
            olderDone = merged;
            olderPage = got.page;
            olderMore = got.has_more;
            olderTotal = got.total;
        }
    } except Exception as e {
        toast("Could not load older completed tasks");
    }
    olderRef.current = False;
    loadingOlder = False;
}

impl BoardPage.refreshOlder(pid: str, who: str, cat: str) -> None {
    # A filter change or a task write invalidates the loaded history. With
    # filters on the count is unknown until a page says so (-1 keeps the
    # toggle visible without a number); with them off the poll's count stands.
    wanted = olderPage;
    olderDone = [];
    rowsRef.current = [];
    olderPage = 0;
    olderMore = False;
    filterRef.current = pid + "|" + who + "|" + cat;
    if filtersOn(pid, who, cat) {
        olderTotal = -1;
    }
    if showAllDone {
        # Reload as many pages as were open, so a save does not collapse
        # history the user had already paged through.
        step = 1;
        while step == 1 or step <= wanted {
            await loadOlder(step, pid, who, cat);
            if step >= 20 {
                break;
            }
            step = step + 1;
        }
    }
}

impl BoardPage.openById(taskId: str) -> None {
    for t in tasks + olderDone {
        if t.id == taskId {
            openEdit(t);
            return;
        }
    }
    # A card outside the working set (older history, a palette hit): one
    # owner-checked fetch rather than loading everything to find it.
    try {
        result = root spawn GetTask(task_id=taskId);
        found = result.reports[0] if result.reports else None;
        if found {
            openEdit(found);
        }
    } except Exception as e {
        toast("Could not open that task");
    }
}

impl BoardPage.setField(key: str, value: str) -> None {
    # NOTE: `{**form, key: value}` compiles to a JS object literal with a
    # LITERAL "key" property, the variable is ignored and the real field
    # never updates (inputs appear frozen). Build a copy and subscript it.
    updated = {** form};
    updated[key] = value;
    form = updated;
}

impl BoardPage.openCreate(inKey: str = "") -> None {
    editingId = "";
    d = new(Date);
    shifted = new(Date, d.getTime() - d.getTimezoneOffset() * 60000);
    # A lane's add row names its own column; otherwise a new task lands in
    # the first column of the flow line (or the first legacy status), never a
    # hardcoded "Backlog" that may not exist.
    keys = columnKeys();
    landing = inKey if inKey and inKey in keys else (keys[0] if keys else "Backlog");
    form = {
        ** BLANK_TASK,
        "project": fProject if fProject != "all" else "none",
        "status": landing,
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
            root spawn CreateTask(
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
        await refreshOlder(fProject, fAssignee, fCategory);
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
        await refreshOlder(fProject, fAssignee, fCategory);
    } except Exception as e {
        toast("Failed to delete task");
    }
    saving = False;
}

# ------------------------------------------------------------------ columns
# The board's columns are the org's flow line steps. Until an org designs one,
# the classic six statuses stand in, so a brand-new workspace still has a
# board. Every helper works in both modes.

impl BoardPage.columnKeys -> list[str] {
    keys: list[str] = [];
    if len(steps) > 0 {
        # Left-to-right on the canvas, so the board reads in the order the
        # org DREW its flow line rather than the order the steps happened to
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

impl BoardPage.columnColor(key: str) -> str {
    for st in steps {
        if st.id == key {
            return st.color;
        }
    }
    return "";
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
    # Without a flow line the key already IS the status; routing it through
    # kind would collapse "Changes Requested" into "In Progress".
    if len(steps) == 0 {
        return key if key in STATUSES else "Backlog";
    }
    kind = columnKind(key);
    return KIND_STATUS[kind] if kind in KIND_STATUS else "In Progress";
}

# Which column a task is drawn in. A task written before flow lines existed
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
    # Optimistic: mutate the card in state and rebind; the server owns the
    # end-of-column order. movesRef fences the poll so a stale fetch cannot
    # snap the card back; on failure the board refetches server truth.
    # A column key is a step jid, or a legacy status when there is no flow line.
    onFlowLine = len(steps) > 0;
    label = columnLabel(columnKey);
    if not label {
        return;
    }
    # A card dragged out of the older history joins the working set here;
    # its old row is dropped so it cannot render twice.
    working = [t for t in tasks];
    cameFromHistory = False;
    for t in olderDone {
        if t.id == taskId {
            working.append(t);
            cameFromHistory = True;
        }
    }
    oldKey = "";
    oldLabel = "";
    peak = 0.0;
    for t in working {
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
    for t in working {
        if t.id == taskId {
            t.status = landing;
            t.step_id = columnKey if onFlowLine else "";
            t.sort_order = peak + 1024.0;
        }
    }
    tasks = working;
    olderDone = [
        t
        for t in olderDone
        if t.id != taskId
    ];
    movesRef.current = (movesRef.current or 0) + 1;
    failed = False;
    # The walker's view of the card after the move. A step change can hand
    # the task to the step's owner, so the optimistic patch above is not the
    # whole story: the reported row replaces it.
    landed: list[TaskView] = [];
    try {
        if onFlowLine {
            result = root spawn MoveTask(
                task_id=taskId, step_id=columnKey, step_name=label
            );
        } else {
            result = root spawn MoveTask(task_id=taskId, status=columnKey);
        }
        landed = result.reports or [];
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
        await refreshOlder(fProject, fAssignee, fCategory);
        return;
    }
    # Who the card went to, when the move handed it over. Read off the
    # reported row against the pre-move one; same names means no hand-off.
    handedTo = "";
    if len(landed) > 0 {
        before: list[str] = [];
        for t in tasks {
            if t.id == taskId {
                before = t.assignee_names;
            }
        }
        after = landed[0].assignee_names;
        if len(after) == 1 and (len(before) != 1 or before[0] != after[0]) {
            handedTo = after[0];
        }
        # `tasks` read after the await is the pre-call snapshot, which is
        # exactly the list the optimistic patch produced; swap the row in.
        swapped: list[TaskView] = [];
        for t in tasks {
            if t.id == taskId {
                swapped.append(landed[0]);
            } else {
                swapped.append(t);
            }
        }
        tasks = swapped;
    }
    # Every successful move confirms itself and offers the undo: a card can
    # land out of sight (Hide Done, or a column below the fold), and the
    # handoff dialog is skippable, so it cannot be the only feedback.
    toast(
        "Moved to " + label + (" · " + handedTo if handedTo else ""),
        {
            "description": title,
            "action": {"label": "Undo", "onClick": lambda { moveTo(taskId, oldKey); }}
        }
    );
    if cameFromHistory {
        await refreshOlder(fProject, fAssignee, fCategory);
    }
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
