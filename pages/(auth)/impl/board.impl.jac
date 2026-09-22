"""Implementations for the Board page."""

impl BoardPage.boot -> None {
    # One load carries the onboarding gate too: the wizard opens when the
    # snapshot comes back with no projects.
    # No GitHub call rides on a board open: the server's schedule polls and
    # the DRAIN_MS timer applies deliveries while they are live.
    # A 401 answers an empty snapshot and clears the token: that is a signed
    # out visitor, not an empty workspace, and the route guard takes it.
    info = await loadBoard(True);
    if info["ok"] and int(info["projects"]) == 0 and jacIsLoggedIn() {
        window.location.href = "/setup";
        return;
    }
}


impl BoardPage.loadAll -> None {
    await loadBoard(True);
}

impl BoardPage.reloadAll -> None {
    # After a write: the working set and the loaded history, together.
    w: any = window;
    await w.Promise.all([loadAll(), refreshOlder(fProject, fAssignee, fCategory)]);
}


impl BoardPage.drainDeliveries(refresh: bool) -> None {
    # A hidden tab and a running sync both skip the tick but keep the
    # timer going; the sync drains on its own and would race this one.
    d: any = document;
    if not d.hidden and not syncing {
        try {
            result = root spawn DrainGithubEvents();
            payload = result.reports[0] if result.reports else None;
            if payload and payload["ok"] and int(payload["drained"] or 0) > 0 {
                # Rows landed, so deliveries are flowing: back to the short tick.
                webhookLive = True;
            }
            if refresh
                and payload
                and payload["ok"]
                and int(payload["applied"] or 0) > 0 {
                await refreshTasks();
            }
        } except Exception as e {
            # Quiet: nothing was asked for, and the queue keeps the row for
            # the next tick.
            payload = None;
        }
    }
    drainTick = drainTick + 1;
}


impl BoardPage.pollTick -> None {
    # A quiet connection (no delivery inside the live window) drains its
    # queue here, ahead of the refresh, so what landed is in the snapshot.
    if ghConnected and not webhookLive {
        await drainDeliveries(False);
    }
    await refreshTasks();
}


impl BoardPage.refreshTasks -> None {
    await loadBoard(False);
}


impl BoardPage.loadBoard(withWorkspace: bool) -> dict[str, any] {
    # While a move is in flight its optimistic state is newer than anything
    # a concurrent fetch started earlier could return, skip.
    if movesRef.current {
        return {"ok": False, "projects": 0, "connected": ghConnected};
    }
    seq = (loadReqRef.current or 0) + 1;
    loadReqRef.current = seq;
    projectCount = 0;
    connected = ghConnected;
    live = webhookLive;
    # A first load paints page 1 and lets the rest join behind it; a refetch
    # keeps the rows on screen until its whole set is in.
    paintPages = loading or len(tasks) == 0;
    try {
        # Pages of 500; the loop is bounded and says so rather than showing
        # part of the workspace. Only page 1 carries the workspace lists.
        fetchedTasks: list[TaskRow] = [];
        olderUnfiltered = 0;
        cats: list[str] = [];
        pageNo = 1;
        more = True;
        gotPage = False;
        while more and pageNo <= 20 and loadReqRef.current == seq {
            bResult = root spawn BoardSnapshot(
                page=pageNo, page_size=500, with_workspace=withWorkspace and pageNo == 1
            );
            data = bResult.reports[0] if bResult.reports else None;
            if not data {
                more = False;
            } else {
                gotPage = True;
                fetchedTasks = fetchedTasks + data.rows;
                more = data.has_more;
                olderUnfiltered = data.older;
                cats = data.categories;
                if withWorkspace and pageNo == 1 {
                    connected = data.github_connected;
                    live = data.webhook_live;
                    projectCount = len(data.projects);
                    # The next page mounts on this view without a request.
                    rememberWorkspace(data);
                    if loadReqRef.current == seq {
                        absorbWorkspace(data);
                        if not filtersReady {
                            takeAccountFilters(data);
                        }
                        dropStaleFilters();
                    }
                }
                # The working set is one sort_order run, so a later page
                # lands under the cards already in its lanes: nothing moves.
                if paintPages and loadReqRef.current == seq and not movesRef.current {
                    tasks = fetchedTasks;
                    knownCategories = cats;
                    loading = False;
                    retrying = False;
                }
            }
            pageNo = pageNo + 1;
        }
        truncated = more;
        if not movesRef.current and loadReqRef.current == seq {
            tasks = fetchedTasks;
            workingTruncated = truncated;
            # An empty answer must not wipe the category list the filter bar
            # is built from: an empty page keeps the list it already had.
            if gotPage {
                knownCategories = cats;
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
        snapshotRef.current = d.getTime();
        hh = str(d.getHours());
        mm = str(d.getMinutes());
        loadedAt = ("0" + hh if len(hh) < 2 else hh)
            + ":"
            + ("0" + mm if len(mm) < 2 else mm);
    } except Exception as e {
        # No toast: the page itself says so (full panel with nothing on
        # screen, a strip with data still showing), and a toast per failed
        # poll would only nag.
        loadFailed = True;
        loading = False;
        retrying = False;
        return {"ok": False, "projects": 0, "connected": connected};
    }
    loading = False;
    retrying = False;
    return {"ok": True, "projects": projectCount, "connected": connected};
}


# The workspace lists a page 1 carries, and the lane count the next
# first-load skeleton draws.
impl BoardPage.absorbWorkspace(data: any) -> None {
    members = data.members;
    projects = data.projects;
    steps = data.steps;
    repos = data.repos;
    roleRows = data.roles;
    iterations = data.iterations;
    filterSets = data.filter_sets;
    ghConnected = data.github_connected;
    webhookLive = data.webhook_live;
    try {
        localStorage.setItem(
            LANES_KEY, str(len(data.steps) if len(data.steps) > 0 else len(STATUSES))
        );
    } except Exception as e {
        members = members;
    }
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

# Back to everything: no filter, no saved set, the Done window shown.
impl BoardPage.clearFilters -> None {
    boardQuery = "";
    adoptFilters({}, "");
}

impl BoardPage.setProjectFilter(v: str) -> None {
    fProject = v;
    # A person who is not on the newly picked project cannot stay the
    # filter: the assignee menu no longer lists them.
    if v != "all" and fAssignee != "All" {
        onProject = False;
        for m in members {
            if m.id == fAssignee and v in m.project_ids {
                onProject = True;
            }
        }
        if not onProject {
            fAssignee = "All";
        }
    }
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

impl BoardPage.boardFilters -> dict[str, str] {
    return trimFilters(
        {
            "project": fProject,
            "assignee": fAssignee,
            "priority": fPriority,
            "category": fCategory,
            "tag": fTag,
            "estimate": fEstimate,
            "iteration": fIteration,
            "done": "hide" if hideDone else "show"
        }
    );
}

# Every filter from a stored dict (a key it lacks is off) and the set they
# came from. The title search is left alone: it is never stored.
impl BoardPage.adoptFilters(filters: dict[str, str], setId: str) -> None {
    pid = filterValue(filters, "project");
    who = filterValue(filters, "assignee");
    cat = filterValue(filters, "category");
    fProject = pid;
    fAssignee = who;
    fCategory = cat;
    fPriority = filterValue(filters, "priority");
    fTag = filterValue(filters, "tag");
    fEstimate = filterValue(filters, "estimate");
    fIteration = filterValue(filters, "iteration");
    hideDone = filterValue(filters, "done") == "hide";
    activeSet = setId;
    refreshOlder(pid, who, cat);
}

# The first page with the workspace: the account's filters replace this
# browser's copy, and from here on every change is saved. An account that
# never saved any keeps what the entry applied, and saves it.
impl BoardPage.takeAccountFilters(data: any) -> None {
    if data.board_saved {
        adoptFilters(data.board_filters, data.board_set);
        savedRef.current = filterKey(data.board_filters) + "|" + data.board_set;
        name = "";
        for s in data.filter_sets {
            if s.id == data.board_set {
                name = s.name;
            }
        }
        keepBoardFilters(data.board_filters, data.board_set, name);
    } else {
        savedRef.current = "|";
    }
    filtersReady = True;
}

# A filter naming a project that is archived, a person no longer on the
# roster (or not on the filtered project) or a deleted iteration would show
# an empty board, or an id in its menu: it is dropped instead.
impl BoardPage.dropStaleFilters -> None {
    pid = fProject;
    who = fAssignee;
    if pid != "all" {
        known = False;
        for p in projects {
            if jid(p) == pid and p.active {
                known = True;
            }
        }
        if not known {
            pid = "all";
        }
    }
    if who != "All" {
        known = False;
        for m in members {
            if m.id == who and m.active and (pid == "all" or pid in m.project_ids) {
                known = True;
            }
        }
        if not known {
            who = "All";
        }
    }
    if fIteration not in ["All", "current", "none"] {
        known = False;
        for it in iterations {
            if it.id == fIteration {
                known = True;
            }
        }
        if not known {
            fIteration = "All";
        }
    }
    if pid != fProject or who != fAssignee {
        fProject = pid;
        fAssignee = who;
        refreshOlder(pid, who, fCategory);
    }
}

# Save the filters on screen to the account, unless they are what it
# already holds. This browser keeps a copy for its next first frame.
impl BoardPage.persistFilters -> None {
    if not filtersReady {
        return;
    }
    now = boardFilters();
    stamp = filterKey(now) + "|" + activeSet;
    if stamp == (savedRef.current or "") {
        return;
    }
    savedRef.current = stamp;
    name = "";
    for s in filterSets {
        if s.id == activeSet {
            name = s.name;
        }
    }
    keepBoardFilters(now, activeSet, name);
    try {
        root spawn SetBoardFilters(filters=now, set_id=activeSet);
    } except Exception as e {
        # Quiet: the next change saves the whole set again.
        savedRef.current = "";
    }
}

impl BoardPage.applySet(view: FilterSetView) -> None {
    adoptFilters(view.filters, view.id);
    dropStaleFilters();
}

impl BoardPage.showAllTasks -> None {
    adoptFilters({}, "");
}

# A saved or renamed set: into the list in name order, and the one the
# filters now come from.
impl BoardPage.absorbSet(view: FilterSetView) -> None {
    rows: list[FilterSetView] = [
        s
        for s in filterSets
        if s.id != view.id
    ];
    rows.append(view);
    rows.sort(key=lambda (s: FilterSetView) { s.name.lower(); });
    filterSets = rows;
    activeSet = view.id;
}

impl BoardPage.dropSet(setId: str) -> None {
    filterSets = [
        s
        for s in filterSets
        if s.id != setId
    ];
    if activeSet == setId {
        activeSet = "";
    }
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
    have: list[TaskRow] = rowsRef.current or [];
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
        toast.error("Could not load older completed tasks");
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
        toast.error("Could not open that task");
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
    # A new-task sheet already open keeps its draft and takes the lane asked
    # for; over an edited task the sheet asks first.
    if dialogOpen and not editingId {
        if inKey and inKey in columnKeys() {
            setField("status", inKey);
        }
        field: any = document.querySelector("[data-task-title]");
        if field {
            field.focus();
        }
        switchTo = NO_SWITCH;
        return;
    }
    if formDirty() {
        switchTo = {"kind": "new", "id": "", "key": inKey, "title": ""};
        return;
    }
    showCreate(inKey);
}

impl BoardPage.showCreate(inKey: str = "") -> None {
    editingId = "";
    d = new(Date);
    shifted = new(Date, d.getTime() - d.getTimezoneOffset() * 60000);
    # A lane's add row names its own column; otherwise a new task lands in
    # the first column of the flow line (or the first legacy status), never a
    # hardcoded "Backlog" that may not exist.
    keys = columnKeys();
    landing = inKey if inKey and inKey in keys else (keys[0] if keys else "Backlog");
    # A task always has a project: the filtered one, else the first active.
    firstProject = "";
    for pr in projects {
        if pr.active and not firstProject {
            firstProject = jid(pr);
        }
    }
    # A board filtered to an iteration plans the new task into it.
    planned = "none";
    for it in iterations {
        if fIteration == it.id
            or (
                fIteration == "current"
                and planned == "none"
                and it.start_date <= shifted.toISOString()[:10]
                and it.end_date >= shifted.toISOString()[:10]
            ) {
            planned = it.id;
        }
    }
    # No due date: a quick capture must not be born due today.
    fresh = {
        ** BLANK_TASK,
        "project": fProject if fProject != "all" else firstProject,
        "status": landing,
        "iteration": planned
    };
    form = fresh;
    baseForm = fresh;
    fAssignees = [];
    baseAssignees = [];
    switchTo = NO_SWITCH;
    dialogOpen = True;
}

impl BoardPage.openEdit(t: TaskRow) -> None {
    # The open card again keeps its edits; another card waits for them.
    if dialogOpen and editingId == t.id {
        switchTo = NO_SWITCH;
        return;
    }
    if formDirty() {
        switchRow.current = t;
        switchTo = {"kind": "task", "id": t.id, "key": "", "title": t.title};
        return;
    }
    showTask(t);
}

impl BoardPage.showTask(t: TaskRow) -> None {
    editingId = t.id;
    fresh = {
        "title": t.title,
        "category": t.category,
        "tags": ", ".join(t.tags),
        "estimate": fmtEstimate(t.estimate) if t.estimate > 0.0 else "",
        "project": t.project_id,
        "priority": t.priority,
        "status": columnKeyOf(t),
        "due_date": t.due_date,
        "start_date": t.start_date,
        "iteration": t.iteration_id or "none",
        "notes": "",
        "issue": t.issue_link,
        "pr": t.pr_link,
        "reviewer": t.reviewer_id or "none",
        "review_due": t.review_due
    };
    form = fresh;
    baseForm = fresh;
    fAssignees = t.assignee_ids;
    baseAssignees = t.assignee_ids;
    switchTo = NO_SWITCH;
    dialogOpen = True;
}

impl BoardPage.formDirty -> bool {
    if not dialogOpen {
        return False;
    }
    for k in FORM_KEYS {
        if str(form[k] or "") != str(baseForm[k] or "") {
            return True;
        }
    }
    now: list[str] = [a for a in fAssignees];
    was: list[str] = [a for a in baseAssignees];
    now.sort();
    was.sort();
    return ",".join(now) != ",".join(was);
}

impl BoardPage.resolveSwitch(save: bool) -> None {
    if save {
        await saveTask(True);
    } else {
        openSwitchTarget();
    }
}

impl BoardPage.openSwitchTarget -> None {
    target = switchTo;
    switchTo = NO_SWITCH;
    if target["kind"] == "new" {
        showCreate(target["key"]);
    } elif target["kind"] == "task" {
        # The loaded row when there is one (a save may have refreshed it),
        # else the row the click handed over (older history, a deep link).
        row: any = switchRow.current;
        for t in tasks + olderDone {
            if t.id == target["id"] {
                row = t;
            }
        }
        if row {
            showTask(row);
        }
    }
}

impl BoardPage.sheetOpenChange(o: bool) -> None {
    dialogOpen = o;
    if not o {
        switchTo = NO_SWITCH;
    }
}

# A write from inside the dialog (the checklist) reports the task's fresh
# view; swap it into whichever list holds the card so the card updates.
impl BoardPage.replaceRow(view: TaskView) -> None {
    tasks = [view if t.id == view.id else t for t in tasks];
    olderDone = [view if t.id == view.id else t for t in olderDone];
}

# The sheet's GetTask hands the open task's notes here: into the form and
# its opened copy alike, so loading them never reads as an unsaved edit.
impl BoardPage.absorbDetails(view: TaskView) -> None {
    if view.id != editingId {
        return;
    }
    updated = {** form};
    updated["notes"] = view.notes;
    form = updated;
    rebased = {** baseForm};
    rebased["notes"] = view.notes;
    baseForm = rebased;
}

impl BoardPage.openTaskById(tid: str) -> None {
    # Jump the open dialog to another card of the same family. A row not in
    # the loaded working set (deep history) is simply a no-op.
    for t in tasks + olderDone {
        if t.id == tid {
            openEdit(t);
        }
    }
}

impl BoardPage.saveTask(keepOpen: bool = False) -> None {
    title = form["title"].strip();
    if not title {
        return;
    }
    project = form["project"];
    if not project {
        toast.error("Pick a project for this task");
        return;
    }
    saving = True;
    reviewer = form["reviewer"] if form["reviewer"] != "none" else "";
    tagList = [
        s.strip()
        for s in form["tags"].split(",")
        if s.strip()
    ];
    est = parseEstimate(form["estimate"]);
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
                    forgetWorkspace();
                }
            }
            if added > 0 {
                toast.success("Added " + str(added) + " assignee(s) to the project");
            }
        }
        if editingId {
            root spawn UpdateTask(
                task_id=editingId,
                title=title,
                category=form["category"],
                tags=tagList,
                estimate=est,
                priority=form["priority"],
                status=mappedStatus(form["status"]),
                step_id=form["status"] if len(steps) > 0 else "",
                due_date=form["due_date"],
                start_date=form["start_date"],
                iteration_id=form["iteration"] if form["iteration"] != "none" else "",
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
                tags=tagList,
                estimate=est,
                priority=form["priority"],
                status=mappedStatus(form["status"]),
                step_id=form["status"] if len(steps) > 0 else "",
                due_date=form["due_date"],
                start_date=form["start_date"],
                iteration_id=form["iteration"] if form["iteration"] != "none" else "",
                notes=form["notes"],
                issue_link=form["issue"].strip(),
                assignee_ids=fAssignees,
                project_id=project
            );
        }
        if keepOpen and switchTo["kind"] {
            openSwitchTarget();
        } else {
            dialogOpen = False;
            switchTo = NO_SWITCH;
        }
        await reloadAll();
    } except Exception as e {
        toast.error("Failed to save task");
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
        switchTo = NO_SWITCH;
        await reloadAll();
    } except Exception as e {
        toast.error("Failed to delete task");
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
impl BoardPage.columnKeyOf(t: TaskRow) -> str {
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

impl BoardPage.moveTo(
    taskId: str,
    columnKey: str,
    anchorId: str = "",
    ahead: bool = False,
    askDetails: bool = True
) -> None {
    # Optimistic: mutate the card in state and rebind; the server owns the
    # order. movesRef fences the poll so a stale fetch cannot snap the card
    # back; on failure the board refetches server truth. An anchorId asks
    # for the spot beside that card; in the card's own column that is a
    # pure reorder (no toast, no handoff dialog, no log on the server).
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
    positioned = False;
    for t in working {
        if t.id == taskId {
            oldKey = columnKeyOf(t);
            oldLabel = columnLabel(oldKey);
        }
        if anchorId and t.id == anchorId and columnKeyOf(t) == columnKey {
            positioned = True;
        }
        if columnKeyOf(t) == columnKey and t.sort_order > peak {
            peak = t.sort_order;
        }
    }
    if not oldKey or (oldKey == columnKey and not positioned) {
        return;
    }
    reorder = positioned and oldKey == columnKey;
    landing = mappedStatus(columnKey);
    # An open sheet on this task follows the move, or its Save (which sends
    # every field) would put the card back. The move is saved, not an edit.
    if dialogOpen and editingId == taskId and not reorder {
        setField("status", columnKey);
        rebased = {** baseForm};
        rebased["status"] = columnKey;
        baseForm = rebased;
    }
    # The rendered order is the array order, so a positioned drop splices
    # the row beside its anchor; an append keeps the sort_order patch.
    row: list[TaskRow] = [];
    rest: list[TaskRow] = [];
    for t in working {
        if t.id == taskId {
            t.status = landing;
            t.step_id = columnKey if onFlowLine else "";
            if not positioned {
                t.sort_order = peak + 1024.0;
            }
            row.append(t);
        } else {
            rest.append(t);
        }
    }
    if positioned and len(row) > 0 {
        spliced: list[TaskRow] = [];
        for t in rest {
            if ahead and t.id == anchorId {
                spliced.append(row[0]);
            }
            spliced.append(t);
            if not ahead and t.id == anchorId {
                spliced.append(row[0]);
            }
        }
        working = spliced;
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
        beforeId = anchorId if positioned and ahead else "";
        afterId = anchorId if positioned and not ahead else "";
        if onFlowLine {
            result = root spawn MoveTask(
                task_id=taskId,
                step_id=columnKey,
                step_name=label,
                before_id=beforeId,
                after_id=afterId
            );
        } else {
            result = root spawn MoveTask(
                task_id=taskId, status=columnKey, before_id=beforeId, after_id=afterId
            );
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
        toast.error("Move failed. Restoring the board.");
        await reloadAll();
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
        if dialogOpen and editingId == taskId {
            fAssignees = landed[0].assignee_ids;
            baseAssignees = landed[0].assignee_ids;
        }
        # `tasks` read after the await is the pre-call snapshot, which is
        # exactly the list the optimistic patch produced; swap the row in.
        swapped: list[TaskRow] = [];
        for t in tasks {
            if t.id == taskId {
                swapped.append(landed[0]);
            } else {
                swapped.append(t);
            }
        }
        tasks = swapped;
    }
    # A reorder is its own feedback: the card visibly sits where it was
    # dropped, and dragging it back is the undo.
    if reorder {
        return;
    }
    # A board move confirms itself with an undo: the card can land out of
    # sight and the handoff dialog is skippable. A sheet move does not: its
    # breadcrumb shows the step, and a toast would cover the sheet's Save.
    if askDetails {
        toast.success(
            "Moved to " + label + (" · " + handedTo if handedTo else ""),
            {
                "description": title,
                "action": {
                    "label": "Undo",
                    "onClick": lambda { moveTo(taskId, oldKey); }
                }
            }
        );
    }
    if cameFromHistory {
        await refreshOlder(fProject, fAssignee, fCategory);
    }
    if askDetails and columnKind(columnKey) in HANDOFF_KINDS {
        # A handoff or a stop also asks for the optional detail.
        mForm = BLANK_MOVE;
        moveStatus = label;
        moveKind = columnKind(columnKey);
        moveTaskTitle = title;
        moveTaskId = taskId;
    }
}

impl BoardPage.moveBeside(draggedId: str, targetId: str, ahead: bool) -> None {
    # The target names the landing column; a target outside the working set
    # (older history rows) keeps today's append-to-column behavior.
    if draggedId == targetId {
        return;
    }
    key = "";
    for t in tasks {
        if t.id == targetId {
            key = columnKeyOf(t);
        }
    }
    if key {
        moveTo(draggedId, key, targetId, ahead);
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
        toast.error("Failed to save the handoff details");
    }
    saving = False;
}

impl BoardPage.sheetMove(columnKey: str) -> None {
    if editingId {
        moveTo(editingId, columnKey, "", False, False);
    }
}

impl BoardPage.arrowMove(t: TaskRow, columnKey: str) -> None {
    if columnKey {
        moveTo(t.id, columnKey);
    }
}

impl BoardPage.syncGithub -> None {
    if syncing {
        return;
    }
    syncing = True;
    syncNote = "";
    linked = 0;
    added = 0;
    moved = 0;
    scanned = 0;
    failure = "";
    painted = False;
    try {
        rounds = 0;
        more = True;
        while more and rounds < SYNC_ROUNDS {
            rounds = rounds + 1;
            result = root spawn SyncGithub();
            forgetWorkspace();
            payload = result.reports[0] if result.reports else None;
            if not payload or not payload["ok"] {
                failure = str(payload["message"]) if payload else "Sync failed";
                break;
            }
            linked = int(payload["linked"] or 0);
            added = added + int(payload["auto_added"] or 0);
            moved = moved + int(payload["auto_done"] or 0);
            scanned = scanned + int(payload["scanned"] or 0);
            failure = str(payload["failure"] or "");
            more = bool(payload["has_more"]) and not failure;
            syncNote = "Syncing… " + str(scanned) + " checked";
            # Paint the first batch of new cards while the rest streams in.
            if added > 0 and not painted {
                painted = True;
                await loadAll();
            }
        }
        # loadAll owns the refresh, including the movesRef fence: an
        # in-flight drag keeps its optimistic state and the next poll
        # picks the synced values up.
        await loadAll();
        if failure {
            toast.error(failure);
        } else {
            msg: str = "Synced " + str(linked) + " tasks";
            if added > 0 {
                msg = msg + " · " + str(added) + " issues added";
            }
            if moved > 0 {
                msg = msg + " · " + str(moved) + " moved to done";
            }
            toast.success(msg);
        }
    } except Exception as e {
        toast.error("Failed to sync with GitHub");
    }
    syncing = False;
    syncNote = "";
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
            toast.success("Opened issue #" + str(opened["gh_issue_number"]));
            await loadAll();
        } else {
            toast.error(
                str(payload["message"]) if payload else "Could not open the issue"
            );
        }
    } except Exception as e {
        toast.error("Failed to open a GitHub issue");
    }
    saving = False;
}


# ------------------------------------------------------------------- lanes

impl BoardPage.scheduleMeasure -> None {
    if frameRef.current {
        return;
    }
    frameRef.current = window.requestAnimationFrame(
        lambda {
            frameRef.current = 0;
            measureLanes();
        }
    );
}

impl BoardPage.measureLanes -> None {
    el: any = lanesRef.current;
    if not el {
        return;
    }
    w: any = window;
    wide = bool(w.innerWidth >= 768);
    box = el.getBoundingClientRect();
    boxRight = float(box.right);
    sheetX = sheetEdge();
    if wide and sheetX > 0 and sheetX < boxRight {
        boxRight = sheetX;
    }
    lanes: any = el.querySelectorAll("[data-lane]");
    shown: list[str] = [];
    best = "";
    bestWidth = 0.0;
    after = 0;
    for i in range(int(lanes.length)) {
        lane: any = lanes[i];
        r = lane.getBoundingClientRect();
        key = str(lane.getAttribute("data-lane"));
        left = r.left if r.left > box.left else box.left;
        right = r.right if r.right < boxRight else boxRight;
        seen = right - left;
        if r.width > 0 and seen >= r.width * 0.6 {
            shown.append(key);
        } elif r.left >= box.left {
            after = after + 1;
        }
        if seen > bestWidth {
            bestWidth = seen;
            best = key;
        }
    }
    joined = ",".join(shown);
    if joined != viewKeys {
        viewKeys = joined;
    }
    if after != hiddenAfter {
        hiddenAfter = after;
    }
    if wide != wideView {
        wideView = wide;
    }
    if best and best != activeLane {
        activeLane = best;
        if not wide {
            # Keep the phone's current tab in sight inside its own row.
            tab: any = document.querySelector('[data-step-tab="' + best + '"]');
            row: any = tab.parentElement if tab else None;
            if row {
                at = tab.getBoundingClientRect().left - row.getBoundingClientRect().left
                    + row.scrollLeft;
                row.scrollTo({"left": at - 24, "behavior": "smooth"});
            }
        }
    }
    # On md+ the lanes fill the window below them, less the page's own
    # bottom padding, so the page itself does not scroll.
    height = 0;
    if wide {
        main: any = el.closest("main");
        pad = 0.0;
        if main {
            pad = float(w.parseFloat(w.getComputedStyle(main).paddingBottom) or 0);
        }
        height = int(w.innerHeight - (box.top + w.scrollY) - pad);
        if height < 320 {
            height = 320;
        }
    }
    if height != laneH {
        laneH = height;
    }
}

impl BoardPage.scrollToLane(key: str) -> None {
    el: any = lanesRef.current;
    if not el {
        return;
    }
    lane: any = el.querySelector('[data-lane="' + key + '"]');
    if not lane {
        return;
    }
    w: any = window;
    still = bool(w.matchMedia("(prefers-reduced-motion: reduce)").matches);
    el.scrollTo({"left": lane.offsetLeft, "behavior": "auto" if still else "smooth"});
}

impl BoardPage.scrollToHidden -> None {
    el: any = lanesRef.current;
    if not el {
        return;
    }
    box = el.getBoundingClientRect();
    boxRight = float(box.right);
    sheetX = sheetEdge();
    if sheetX > 0 and sheetX < boxRight {
        boxRight = sheetX;
    }
    lanes: any = el.querySelectorAll("[data-lane]");
    for i in range(int(lanes.length)) {
        lane: any = lanes[i];
        r = lane.getBoundingClientRect();
        if r.right > boxRight + 1 {
            scrollToLane(str(lane.getAttribute("data-lane")));
            return;
        }
    }
}

impl BoardPage.revealCard(tid: str) -> None {
    el: any = lanesRef.current;
    card: any = document.querySelector('[data-task-card="' + tid + '"]');
    sheetX = sheetEdge();
    if not el or not card or sheetX < 0 {
        return;
    }
    w: any = window;
    limit = sheetX - 16.0;
    r = card.getBoundingClientRect();
    if r.right > limit {
        still = bool(w.matchMedia("(prefers-reduced-motion: reduce)").matches);
        el.scrollBy(
            {"left": r.right - limit, "behavior": "auto" if still else "smooth"}
        );
    }
}

impl BoardPage.sheetEdge -> float {
    sheet: any = document.querySelector("[data-task-sheet][data-state=open]");
    w: any = window;
    if not sheet or w.innerWidth < 768 {
        return -1.0;
    }
    # offsetWidth and the inline right, not the rect: the sheet may still be
    # sliding in.
    right = float(w.parseFloat(sheet.style.right) or 0);
    return float(document.documentElement.clientWidth)
        - right
        - float(sheet.offsetWidth);
}

impl BoardPage.stepCard(delta: int) -> None {
    el: any = lanesRef.current;
    if not el or not editingId {
        return;
    }
    cards: any = el.querySelectorAll("[data-task-card]");
    at = -1;
    for i in range(int(cards.length)) {
        if str(cards[i].getAttribute("data-task-card")) == editingId {
            at = i;
        }
    }
    to = at + delta;
    if at < 0 or to < 0 or to >= int(cards.length) {
        return;
    }
    card: any = cards[to];
    nextId = str(card.getAttribute("data-task-card"));
    # Over unsaved edits the sheet asks first and nothing moves yet.
    if formDirty() {
        openTaskById(nextId);
        return;
    }
    active: any = document.activeElement;
    # Focus follows only when it was on a card; typing focus stays in the sheet.
    if active and active.hasAttribute("data-task-card") {
        card.focus({"preventScroll": True});
    }
    card.scrollIntoView({"block": "nearest", "inline": "nearest"});
    openTaskById(nextId);
}

impl BoardPage.dragEdgeScroll(e: DragEvent) -> None {
    el: any = lanesRef.current;
    if not el or not wideView {
        return;
    }
    box = el.getBoundingClientRect();
    x = float(e.clientX);
    if x > float(box.right) - 64.0 {
        el.scrollLeft = el.scrollLeft + 14;
    } elif x < float(box.left) + 64.0 {
        el.scrollLeft = el.scrollLeft - 14;
    }
}
