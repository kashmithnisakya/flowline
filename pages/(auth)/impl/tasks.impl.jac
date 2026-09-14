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
        # A project or assignee id from the URL that is not in the dropdowns
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
        rResult = root spawn ListRoles();
        roleRows = rResult.reports[0] if rResult.reports else [];
    } except Exception as e {
        # Non-fatal: the filters just show fewer options; loadTasks owns the
        # failure panel for the table itself.
        members = [];
    }
    await loadTasks();
}

impl TasksPage.loadTasks -> None {
    seq = (reqRef.current or 0) + 1;
    reqRef.current = seq;
    try {
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
        if reqRef.current == seq {
            fetched: list[TaskView] = data.rows if data else [];
            rows = fetched;
            total = data.total if data else 0;
            hasMore = data.has_more if data else False;
            # Distinct categories and tags present, for the filter dropdowns.
            # Read the local `fetched`, not the just-assigned `rows` has,
            # which is the pre-call value for the rest of this handler.
            # The active filters count as seen, so a view from the URL that
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
    }
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
}

impl TasksPage.chooseScope(value: str) -> None {
    scope = value;
    page = 1;
}

impl TasksPage.setProject(value: str) -> None {
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
}

impl TasksPage.setAssignee(value: str) -> None {
    fAssignee = value;
    page = 1;
}

impl TasksPage.setCategory(value: str) -> None {
    fCategory = value;
    page = 1;
}

impl TasksPage.setTag(value: str) -> None {
    fTag = value;
    page = 1;
}

impl TasksPage.setEstimate(value: str) -> None {
    fEstimate = value;
    page = 1;
}

impl TasksPage.runSearch -> None {
    query = queryDraft.strip();
    page = 1;
}

impl TasksPage.clearSearch -> None {
    query = "";
    queryDraft = "";
    page = 1;
}

impl TasksPage.goPage(delta: int) -> None {
    next = page + delta;
    if next >= 1 {
        page = next;
    }
}

impl TasksPage.writeUrl -> None {
    # Defaults stay out of the URL. replaceState, not push: a filter change
    # is not a page the back button should step through.
    w: any = window;
    params: any = new(w.URLSearchParams);
    if scope != "all" {
        params.set("scope", scope);
    }
    if fProject != "all" {
        params.set("project", fProject);
    }
    if fAssignee != "All" {
        params.set("assignee", fAssignee);
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
        w.history.replaceState(None, "", target);
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
    for t in rows {
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
            notes=taskForm["notes"],
            issue_link=taskForm["issue"].strip(),
            pr_link=taskForm["pr"].strip(),
            reviewer_id=reviewer,
            review_due=taskForm["review_due"],
            assignee_ids=taskAssignees,
            project_id=project
        );
        taskOpen = False;
        await loadTasks();
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
