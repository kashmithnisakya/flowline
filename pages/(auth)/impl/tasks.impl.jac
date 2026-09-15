"""Implementations for the Tasks page."""

impl TasksPage.loadWorkspace -> None {
    try {
        mResult = root spawn ListMembers();
        pResult = root spawn ListProjects();
        members = mResult.reports[0] if mResult.reports else [];
        allProjects: list[Project] = pResult.reports[0] if pResult.reports else [];
        projects = [
            p
            for p in allProjects
            if p.active
        ];
        # A project or assignee id from the URL that is not in the menus
        # (archived, or another workspace's) would show a blank filter.
        knownProject = fProject == "all";
        for p in projects {
            if jid(p) == fProject {
                knownProject = True;
            }
        }
        if not knownProject {
            fProject = "all";
        }
        knownMember = fAssignee == "All";
        for m in members {
            if m.id == fAssignee and (fProject == "all" or fProject in m.project_ids) {
                knownMember = True;
            }
        }
        if not knownMember {
            fAssignee = "All";
        }
        sResult = root spawn GetFlowLine(with_counts=False);
        steps = sResult.reports[0] if sResult.reports else [];
        if fStep != "All" and fStep not in columnKeys() {
            fStep = "All";
        }
        rResult = root spawn ListRoles();
        roleRows = rResult.reports[0] if rResult.reports else [];
        iResult = root spawn ListIterations();
        iterations = iResult.reports[0] if iResult.reports else [];
    } except Exception as e {
        # Non-fatal: the filters just show fewer options; loadTasks owns the
        # failure panel for the table itself.
        members = [];
    }
    # Only a step filter waits for the flow line; every other view is already
    # loading from the view effect.
    readyRef.current = True;
    if fStep != "All" {
        await loadTasks();
    }
}

impl TasksPage.loadTasks -> None {
    # A step filter places rows by the flow line, so it waits for the steps.
    if fStep != "All" and not readyRef.current {
        return;
    }
    seq = (reqRef.current or 0) + 1;
    reqRef.current = seq;
    if not loading {
        refreshing = True;
    }
    try {
        fetched: list[TaskView] = [];
        matched = 0;
        more = False;
        if fStep != "All" or fPriority != "All" {
            pool = await gatherPool(seq);
            start = (page - 1) * PAGE_SIZE;
            fetched = pool[start:start + PAGE_SIZE];
            matched = len(pool);
            more = len(pool) > start + PAGE_SIZE;
        } else {
            result = root spawn ListTasks(
                scope=scope,
                q=query,
                project_id="" if fProject == "all" else fProject,
                assignee_id="" if fAssignee == "All" else fAssignee,
                category="" if fCategory == "All" else fCategory,
                tag="" if fTag == "All" else fTag,
                estimated="" if fEstimate == "All" else fEstimate,
                sort=sort,
                sort_dir=sortDir,
                page=page,
                page_size=PAGE_SIZE
            );
            data = result.reports[0] if result.reports else None;
            fetched = data.rows if data else [];
            matched = data.total if data else 0;
            more = data.has_more if data else False;
        }
        # The scope's unfiltered count, read once per scope while a filter is
        # on; any write forgets them.
        totals: any = totalsRef.current or {};
        if not filtered() {
            totals[scope] = matched;
        } elif reqRef.current == seq and scope not in totals {
            whole = root spawn ListTasks(scope=scope, page=1, page_size=1);
            wholePage = whole.reports[0] if whole.reports else None;
            totals[scope] = wholePage.total if wholePage else -1;
        }
        totalsRef.current = totals;
        # A page past the end (an old link, or the last row deleted elsewhere)
        # steps back to the last page; the view effect reloads it.
        if reqRef.current == seq and len(fetched) == 0 and page > 1 and matched > 0 {
            page = (matched + PAGE_SIZE - 1) // PAGE_SIZE;
            return;
        }
        if reqRef.current == seq {
            rows = fetched;
            total = matched;
            hasMore = more;
            scopeTotal = totals[scope] if scope in totals else -1;
            if cursor >= len(fetched) {
                cursor = len(fetched) - 1;
            }
            # Distinct categories and tags present, for the filter menus. The
            # active filters count as seen, so a view from the URL that
            # matches nothing still shows what it filtered on.
            seenCats: list[str] = [fCategory] if fCategory != "All" else [];
            seenTags: list[str] = [fTag] if fTag != "All" else [];
            for t in fetched {
                if t.category and t.category not in seenCats {
                    seenCats.append(t.category);
                }
                for tg in t.tags {
                    if tg not in seenTags {
                        seenTags.append(tg);
                    }
                }
            }
            categories = mergeSorted(categories, seenCats);
            tags = mergeSorted(tags, seenTags);
            failed = False;
        }
    } except Exception as e {
        if reqRef.current == seq {
            failed = True;
        }
    }
    if reqRef.current == seq {
        loading = False;
        refreshing = False;
    }
}

# Every task the view matches once step and priority apply, read page by page
# at the walker's largest size and kept for paging until the view or the data
# changes. `steps` is part of the key: placement depends on the flow line.
impl TasksPage.gatherPool(seq: int) -> list[TaskView] {
    keys = columnKeys();
    sig = "|".join(
        [
            scope,
            query,
            fProject,
            fAssignee,
            fCategory,
            fTag,
            fEstimate,
            fStep,
            fPriority,
            sort,
            sortDir,
            str(len(steps))
        ]
    );
    cached: any = poolRef.current;
    if cached and cached["sig"] == sig {
        return cached["rows"];
    }
    pool: list[TaskView] = [];
    pg = 1;
    more = True;
    while more and pg <= GATHER_PAGES and reqRef.current == seq {
        result = root spawn ListTasks(
            scope=scope,
            q=query,
            project_id="" if fProject == "all" else fProject,
            assignee_id="" if fAssignee == "All" else fAssignee,
            category="" if fCategory == "All" else fCategory,
            tag="" if fTag == "All" else fTag,
            estimated="" if fEstimate == "All" else fEstimate,
            sort=sort,
            sort_dir=sortDir,
            page=pg,
            page_size=GATHER_SIZE
        );
        data = result.reports[0] if result.reports else None;
        got: list[TaskView] = data.rows if data else [];
        for t in got {
            if (fPriority == "All" or t.priority == fPriority)
                and (fStep == "All" or columnKeyOf(t, keys) == fStep) {
                pool.append(t);
            }
        }
        more = data.has_more if data else False;
        pg = pg + 1;
    }
    if reqRef.current == seq {
        poolRef.current = {"sig": sig, "rows": pool};
    }
    return pool;
}

impl TasksPage.filtered -> bool {
    return bool(query)
        or fProject != "all"
        or fAssignee != "All"
        or fStep != "All"
        or fPriority != "All"
        or fCategory != "All"
        or fTag != "All"
        or fEstimate != "All";
}

# A write can change what any view matches: drop the kept pool and totals.
impl TasksPage.forget -> None {
    poolRef.current = None;
    totalsRef.current = {};
}

impl TasksPage.sortBy(field: str) -> None {
    # Same column flips direction; a new column starts ascending. Reset to
    # page 1 so the new order is read from the top.
    if sort == field {
        sortDir = "asc" if sortDir == "desc" else "desc";
    } else {
        sort = field;
        sortDir = "asc";
    }
    page = 1;
    cursor = -1;
}

impl TasksPage.chooseScope(value: str) -> None {
    scope = value;
    page = 1;
    cursor = -1;
}

impl TasksPage.pickProject(value: str) -> None {
    fProject = value;
    # A member outside the newly picked project must not stay the filter.
    if value != "all" and fAssignee != "All" {
        stillThere = False;
        for m in members {
            if m.id == fAssignee and value in m.project_ids {
                stillThere = True;
            }
        }
        if not stillThere {
            fAssignee = "All";
        }
    }
    page = 1;
    cursor = -1;
}

impl TasksPage.pickAssignee(value: str) -> None {
    fAssignee = value;
    page = 1;
    cursor = -1;
}

impl TasksPage.pickStep(value: str) -> None {
    fStep = value;
    page = 1;
    cursor = -1;
}

impl TasksPage.pickPriority(value: str) -> None {
    fPriority = value;
    page = 1;
    cursor = -1;
}

impl TasksPage.pickCategory(value: str) -> None {
    fCategory = value;
    page = 1;
    cursor = -1;
}

impl TasksPage.pickTag(value: str) -> None {
    fTag = value;
    page = 1;
    cursor = -1;
}

impl TasksPage.pickEstimate(value: str) -> None {
    fEstimate = value;
    page = 1;
    cursor = -1;
}

impl TasksPage.typeSearch(value: str) -> None {
    queryDraft = value;
    # Clearing the box applies at once; typing waits for the pause.
    if not value.strip() {
        commitSearch();
    }
}

impl TasksPage.commitSearch -> None {
    q = queryDraft.strip();
    if q != query {
        query = q;
        page = 1;
        cursor = -1;
    }
}

impl TasksPage.clearFilters -> None {
    fProject = "all";
    fAssignee = "All";
    fStep = "All";
    fPriority = "All";
    fCategory = "All";
    fTag = "All";
    fEstimate = "All";
    queryDraft = "";
    query = "";
    page = 1;
    cursor = -1;
}

impl TasksPage.goPage(delta: int) -> None {
    next = page + delta;
    if next < 1 {
        return;
    }
    page = next;
    cursor = -1;
    top: any = document.querySelector("[data-tasks-top]");
    if top and top.getBoundingClientRect().top < 0 {
        top.scrollIntoView({"block": "start"});
    }
}

impl TasksPage.writeUrl -> None {
    # Defaults stay out of the URL. replaceState, not push: a filter change
    # is not a page the back button should step through.
    w: any = window;
    params: any = new(w.URLSearchParams);
    if scope != "working" {
        params.set("scope", scope);
    }
    if fProject != "all" {
        params.set("project", fProject);
    }
    if fAssignee != "All" {
        params.set("assignee", fAssignee);
    }
    if fStep != "All" {
        params.set("step", fStep);
    }
    if fPriority != "All" {
        params.set("priority", fPriority);
    }
    if fCategory != "All" {
        params.set("category", fCategory);
    }
    if fTag != "All" {
        params.set("tag", fTag);
    }
    if fEstimate != "All" {
        params.set("estimate", fEstimate);
    }
    if query {
        params.set("q", query);
    }
    if sort != "updated" or sortDir != "desc" {
        params.set("sort", sort);
        params.set("dir", sortDir);
    }
    if page > 1 {
        params.set("page", str(page));
    }
    qs = str(params);
    target = str(w.location.pathname) + ("?" + qs if qs else "");
    if target != str(w.location.pathname) + str(w.location.search) {
        # Keep the router's own history state, only the address changes.
        w.history.replaceState(w.history.state, "", target);
    }
}

# ----------------------------------------------------------------- keyboard

impl TasksPage.handleKey(e: any) -> None {
    t: any = e.target;
    tag = str(t.tagName or "").lower() if t else "";
    typing = tag == "input"
        or tag == "textarea"
        or tag == "select"
        or bool(t and t.isContentEditable);
    if typing or e.metaKey or e.ctrlKey or e.altKey or e.defaultPrevented {
        return;
    }
    if document.querySelector(
        "[role=dialog][data-state=open], [role=menu], [role=listbox]"
    ) {
        return;
    }
    key = str(e.key);
    if key == "/" {
        boxes: any = document.querySelectorAll("[data-tasks-search]");
        for i in range(int(boxes.length)) {
            box: any = boxes[i];
            if box.offsetParent {
                e.preventDefault();
                box.focus();
            }
        }
    } elif key == "j" or key == "J" or key == "k" or key == "K" {
        e.preventDefault();
        moveCursor(1 if key == "j" or key == "J" else -1);
    } elif key == "Enter" and cursor >= 0 and cursor < len(rows) {
        # A focused title button opens on its own click; this is the path for
        # a cursor whose focus has gone back to the page.
        active: any = document.activeElement;
        activeTag = str(active.tagName or "").lower() if active else "body";
        if activeTag == "body" {
            e.preventDefault();
            openTask(rows[cursor].id);
        }
    }
}

impl TasksPage.moveCursor(delta: int) -> None {
    n = len(rows);
    if n == 0 {
        return;
    }
    next = (0 if delta > 0 else n - 1) if cursor < 0 else cursor + delta;
    if next < 0 {
        next = 0;
    }
    if next > n - 1 {
        next = n - 1;
    }
    cursor = next;
    targets: any = document.querySelectorAll("[data-task-row='" + str(next) + "']");
    for i in range(int(targets.length)) {
        el: any = targets[i];
        if el.offsetParent {
            el.focus({"preventScroll": True});
            el.scrollIntoView({"block": "nearest"});
        }
    }
}

impl TasksPage.pointAt(i: int) -> None {
    if cursor != i {
        cursor = i;
    }
}

# The table header sticks under the app bar, whatever height the bar has.
impl TasksPage.measureHeader -> None {
    bar: any = document.querySelector("header");
    height = 0;
    if bar {
        w: any = window;
        style: any = w.getComputedStyle(bar);
        position = str(style.position);
        if position == "sticky" or position == "fixed" {
            height = int(Math.round(bar.getBoundingClientRect().height));
        }
    }
    if height != stickyTop {
        stickyTop = height;
    }
}

# ------------------------------------------------------------------ columns
# The board's column rules, so a row's step and the dialog's Step select say
# what the board shows. Without a flow line the six statuses stand in.

impl TasksPage.columnKeys -> list[str] {
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

impl TasksPage.columnKind(key: str) -> str {
    for st in steps {
        if st.id == key {
            return st.kind;
        }
    }
    return STATUS_KIND[key] if key in STATUS_KIND else "active";
}

# A task with no step of its own (or whose step was deleted) sits in the first
# column of its status's kind; without a flow line the status is the column.
impl TasksPage.columnKeyOf(t: TaskView, keys: list[str]) -> str {
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

impl TasksPage.mappedStatus(key: str) -> str {
    if len(steps) == 0 {
        return key if key in STATUSES else "Backlog";
    }
    kind = columnKind(key);
    return KIND_STATUS[kind] if kind in KIND_STATUS else "In Progress";
}

# -------------------------------------------------------------- task dialog

impl TasksPage.openTask(tid: str) -> None {
    keys = columnKeys();
    for (i, t) in enumerate(rows) {
        if t.id == tid {
            cursor = i;
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

# A checklist write reports the task's fresh view; the table row takes it.
impl TasksPage.replaceRow(view: TaskView) -> None {
    rows = [view if t.id == view.id else t for t in rows];
    poolRef.current = None;
}

impl TasksPage.setTaskField(key: str, value: str) -> None {
    # A computed key does not survive a dict-literal spread.
    updated = {** taskForm};
    updated[key] = value;
    taskForm = updated;
}

impl TasksPage.toggleTaskAssignee(memberId: str) -> None {
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

impl TasksPage.saveTask -> None {
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
        forget();
        await loadTasks();
        # The saved row may have moved in the order; the cursor follows it.
        for (i, t) in enumerate(rows) {
            if t.id == editTaskId {
                cursor = i;
            }
        }
    } except Exception as e {
        toast("Failed to save task");
    }
    taskSaving = False;
}

impl TasksPage.deleteTask -> None {
    if not editTaskId {
        return;
    }
    taskSaving = True;
    try {
        root spawn DeleteTask(task_id=editTaskId);
        taskOpen = False;
        forget();
        # The last row of a later page: step back, and the effect reloads.
        if len(rows) == 1 and page > 1 {
            page = page - 1;
        } else {
            await loadTasks();
        }
    } except Exception as e {
        toast("Failed to delete task");
    }
    taskSaving = False;
}
