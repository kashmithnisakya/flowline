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
            seenCats: list[str] = [];
            seenTags: list[str] = [];
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
