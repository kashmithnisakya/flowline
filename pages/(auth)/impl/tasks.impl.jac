"""Implementations for the Tasks page."""

impl TasksPage.loadShared -> None {
    # One read for the flow line, roster, projects, roles and iterations,
    # fired beside the first ListTasks. The table waits for the flow line,
    # and a step filter places rows by it. A failed read is non-fatal: the
    # filters show fewer options; loadTasks owns the table's failure panel.
    ws = await loadWorkspace();
    steps = ws["steps"];
    if fStep != "All" and fStep not in columnKeys() {
        fStep = "All";
    }
    stepsLoaded = True;
    readyRef.current = True;
    if fStep != "All" {
        loadTasks();
    }
    members = ws["members"];
    allProjects: list[Project] = ws["projects"];
    projects = [
        p
        for p in allProjects
        if p.active
    ];
    if ws["ok"] {
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
    }
    roleRows = ws["roles"];
    iterations = ws["iterations"];
    workspaceReady = True;
    # The app bar may have mounted after the first measure (a full load).
    measureHeader();
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
        fetched: list[TaskRow] = [];
        matched = 0;
        more = False;
        # The scope's unfiltered count rides on every page (scope_total), so
        # "12 of 210" costs no second call.
        whole = -1;
        if fStep != "All" or fPriority != "All" {
            pool = await gatherPool(seq);
            start = (page - 1) * PAGE_SIZE;
            fetched = pool[start:start + PAGE_SIZE];
            matched = len(pool);
            more = len(pool) > start + PAGE_SIZE;
            kept: any = poolRef.current;
            whole = int(kept["scope_total"]) if kept else -1;
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
            whole = data.scope_total if data else -1;
        }
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
            scopeTotal = whole;
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
# at the walker's largest size and kept until the filters or the data change.
# A new sort re-sorts the kept rows. A step filter keys on the flow line too,
# since placement depends on it.
impl TasksPage.gatherPool(seq: int) -> list[TaskRow] {
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
            str(len(steps)) if fStep != "All" else ""
        ]
    );
    order = sort + "|" + sortDir;
    cached: any = poolRef.current;
    if cached and cached["sig"] == sig {
        kept: list[TaskRow] = cached["rows"];
        if cached["order"] != order {
            kept = sortPool(kept);
            poolRef.current = {
                "sig": sig,
                "order": order,
                "rows": kept,
                "scope_total": cached["scope_total"]
            };
        }
        return kept;
    }
    pool: list[TaskRow] = [];
    whole = -1;
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
        got: list[TaskRow] = data.rows if data else [];
        if pg == 1 and data {
            whole = data.scope_total;
        }
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
        poolRef.current = {
            "sig": sig,
            "order": order,
            "rows": pool,
            "scope_total": whole
        };
    }
    return pool;
}

# The walker's column sort (sort_tasks) over rows already in hand: a jid pass,
# then the key. A descending pass runs on the reversed list and reverses back,
# which keeps ties in jid order as Python's reverse=True does.
impl TasksPage.sortPool(pool: list[TaskRow]) -> list[TaskRow] {
    rows = [t for t in pool];
    rows.sort(key=lambda (t: TaskRow) { t.id; });
    desc = sortDir == "desc";
    keys = columnKeys();
    if sort == "step" {
        rows.sort(key=lambda (t: TaskRow) { t.sort_order; });
    }
    if desc {
        rows.reverse();
    }
    if sort == "step" {
        rows.sort(key=lambda (t: TaskRow) { keys.index(columnKeyOf(t, keys)); });
    } elif sort == "title" {
        rows.sort(key=lambda (t: TaskRow) { t.title.lower(); });
    } elif sort == "priority" {
        rows.sort(
            key=lambda (t: TaskRow) { PRIORITY_RANK[t.priority]
                if t.priority in PRIORITY_RANK
                else 1; }
        );
    } elif sort == "due" {
        rows.sort(key=lambda (t: TaskRow) { t.due_date or "9999-12-31"; });
    } else {
        rows.sort(key=lambda (t: TaskRow) { t.updated_at; });
    }
    if desc {
        rows.reverse();
    }
    return rows;
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

# A write can change what any view matches: drop the kept pool.
impl TasksPage.forget -> None {
    poolRef.current = None;
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
    focusRow(next, True);
}

# Focus row `i` in whichever of the table and the list is showing.
impl TasksPage.focusRow(i: int, scroll: bool) -> None {
    targets: any = document.querySelectorAll("[data-task-row='" + str(i) + "']");
    for k in range(int(targets.length)) {
        el: any = targets[k];
        if el.offsetParent {
            el.focus({"preventScroll": True});
            if scroll {
                el.scrollIntoView({"block": "nearest"});
            }
        }
    }
}

# The task dialog has no trigger to hand focus back to, so the cursor row
# takes it once the dialog's focus trap has let go.
impl TasksPage.refocusRow -> None {
    window.setTimeout(lambda { focusRow(cursor, False); }, 60);
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
impl TasksPage.columnKeyOf(t: TaskRow, keys: list[str]) -> str {
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
            creating = False;
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
                "notes": "",
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

# New task from the table: the board's defaults, narrowed by the view's own
# filters, so the task lands where the table is looking when it can.
impl TasksPage.openCreate -> None {
    d = new(Date);
    shifted = new(Date, d.getTime() - d.getTimezoneOffset() * 60000);
    keys = columnKeys();
    landing = fStep
        if fStep != "All" and fStep in keys
        else (keys[0] if len(keys) > 0 else "Backlog");
    firstProject = "";
    for pr in projects {
        if pr.active and not firstProject {
            firstProject = jid(pr);
        }
    }
    fresh = {** BLANK_TASK};
    fresh["project"] = fProject if fProject != "all" else firstProject;
    fresh["status"] = landing;
    fresh["priority"] = fPriority if fPriority != "All" else "Medium";
    fresh["due_date"] = shifted.toISOString()[:10];
    taskForm = fresh;
    taskAssignees = [fAssignee] if fAssignee != "All" else [];
    editTaskId = "";
    creating = True;
    taskOpen = True;
}

impl TasksPage.dialogOpenChange(o: bool) -> None {
    taskOpen = o;
    if not o {
        refocusRow();
    }
}

# A checklist write reports the task's fresh view; the table row takes it.
impl TasksPage.replaceRow(view: TaskView) -> None {
    rows = [view if t.id == view.id else t for t in rows];
    poolRef.current = None;
}

# The sheet's GetTask hands the open task's notes to the form.
impl TasksPage.absorbDetails(view: TaskView) -> None {
    if creating or view.id != editTaskId {
        return;
    }
    updated = {** taskForm};
    updated["notes"] = view.notes;
    taskForm = updated;
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
    if not title or (not creating and not editTaskId) {
        return;
    }
    project = taskForm["project"];
    if not project {
        toast.error("Pick a project for this task");
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
                forgetWorkspace();
            }
        }
        if added > 0 {
            toast.success("Added " + str(added) + " assignee(s) to the project");
            mResult = root spawn ListMembers();
            members = mResult.reports[0] if mResult.reports else members;
        }
        tagList = [
            s.strip()
            for s in taskForm["tags"].split(",")
            if s.strip()
        ];
        if creating {
            made = root spawn CreateTask(
                title=title,
                category=taskForm["category"],
                tags=tagList,
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
                assignee_ids=taskAssignees,
                project_id=project
            );
            if not made.reports {
                toast.error("Could not create the task");
                taskSaving = False;
                return;
            }
            editTaskId = made.reports[0].id;
            creating = False;
            taskOpen = False;
            forget();
            await loadTasks();
            for (i, t) in enumerate(rows) {
                if t.id == editTaskId {
                    cursor = i;
                }
            }
            refocusRow();
            toast.success("Task created");
            taskSaving = False;
            return;
        }
        root spawn UpdateTask(
            task_id=editTaskId,
            title=title,
            category=taskForm["category"],
            tags=tagList,
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
        refocusRow();
    } except Exception as e {
        toast.error("Could not save the task");
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
            refocusRow();
        }
    } except Exception as e {
        toast.error("Could not delete the task");
    }
    taskSaving = False;
}
