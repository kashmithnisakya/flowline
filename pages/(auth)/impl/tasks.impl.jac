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
            sort=sort,
            sort_dir=sortDir,
            page=page,
            page_size=PAGE_SIZE
        );
        data = result.reports[0] if result.reports else None;
        if reqRef.current == seq {
            rows = data.rows if data else [];
            total = data.total if data else 0;
            hasMore = data.has_more if data else False;
            # The distinct categories present, for the filter dropdown. Kept
            # from the rows on screen; a page with none keeps the last list.
            seen: list[str] = [];
            for t in rows {
                if t.category and t.category not in seen {
                    seen.append(t.category);
                }
            }
            if len(seen) > 0 {
                merged = [c for c in categories];
                for c in seen {
                    if c not in merged {
                        merged.append(c);
                    }
                }
                merged.sort();
                categories = merged;
            }
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
