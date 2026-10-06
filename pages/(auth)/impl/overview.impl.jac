"""Implementations for the Overview page."""

impl OverviewPage.fetchSnapshot(monday: str) -> any {
    # Two weeks of log back-story so a blocked move's reason is still in the
    # window. Untyped on purpose: typing the report would pull
    # services.insights.insights objs into the client bundle.
    result = root spawn OverviewSnapshot(
        monday=monday, from_date=shiftDay(monday, -14), attention_size=24
    );
    return result.reports[0] if result.reports else None;
}

impl OverviewPage.loadAll -> None {
    monday = mondayOf(todayIso());
    # A retry with figures already on screen keeps them; only an empty page
    # shows the frame.
    if not counts {
        loading = True;
    }
    failed = False;
    mine = False;
    if not inflight("snap") {
        LOADS["snap"] = fetchSnapshot(monday);
        mine = True;
    }
    pending: any = LOADS["snap"];
    try {
        data: any = await pending;
        counts = data["counts"] if data else None;
        weekDone = data["counts"]["done_by_day"] if data else [0, 0, 0, 0, 0, 0, 0];
        logs = data["logs"] if data else None;
        attention = data["attention"] if data else [];
        attentionTotal = data["attention_total"] if data else 0;
        members = data["members"] if data else [];
        projects = data["projects"] if data else [];
        reviewQueue = data["review_queue"] if data else [];
        # Blocked and Review rows already sit in their own groups, so the
        # quiet list keeps only the rest of the snapshot's aging entries.
        stale: list[dict[str, any]] = [];
        for r in (data["aging"] if data else []) {
            if r["status"] != "Blocked" and r["status"] != "Review" {
                stale.append(r);
            }
        }
        quiet = stale;
        info: dict[str, dict[str, any]] = {};
        every: list[dict[str, any]] = [];
        for b in (data["blocked"] if data else []) {
            info[b["task_id"]] = b;
            every.append(b);
        }
        blockedInfo = info;
        blockedList = every;
        # Every task hangs under a project, so the tallies add up to all of them.
        total = 0;
        for pt in (data["counts"]["projects"] if data else []) {
            total = total + pt["total"];
        }
        taskTotal = total;
    } except Exception as e {
        # The page shows the failure panel itself; no toast on top of it.
        failed = True;
    }
    if mine {
        LOADS["snap"] = None;
    }
    loading = False;
}

impl OverviewPage.fetchDue -> any {
    result = root spawn ListTasks(
        scope="working", sort="due", done_days=1, page_size=100
    );
    return result.reports[0] if result.reports else None;
}

# Open work by due date, so a page of 100 starts with what is late and what
# is due soon. Done rows are skipped on the page, so one day of them is enough.
impl OverviewPage.loadDue -> None {
    dueFailed = False;
    mine = False;
    if not inflight("due") {
        LOADS["due"] = fetchDue();
        mine = True;
    }
    pending: any = LOADS["due"];
    try {
        got: any = await pending;
        dueRows = got.rows if got else [];
        dueHasMore = bool(got and got.has_more);
    } except Exception as e {
        dueFailed = True;
    }
    if mine {
        LOADS["due"] = None;
    }
    dueLoaded = True;
}

# The workspace view (shared, cached a minute): the flow line for the row
# pills and the checklist, its template, and the GitHub connection.
impl OverviewPage.loadShared -> None {
    ws = await loadWorkspace();
    named = "";
    for tpl in FLOW_LINE_TEMPLATES {
        if ws["template_key"] and tpl["key"] == ws["template_key"] {
            named = tpl["name"];
        }
    }
    gh: any = ws["github"];
    steps = ws["steps"];
    templateName = named;
    ghConfigured = bool(gh and gh.configured);
    ghConnected = bool(gh and gh.connected);
    ghLogin = gh.account_login if gh else "";
    sharedLoaded = True;
}

impl OverviewPage.fetchHistory(projectId: str, weeks: int) -> any {
    result = root spawn TaskHistory(
        project_id=projectId, monday=mondayOf(todayIso()), weeks=weeks
    );
    return result.reports[0] if result.reports else None;
}

impl OverviewPage.loadHistory -> None {
    historyLoading = True;
    projectId = "" if historyProject == "all" else historyProject;
    weeks = int(historyWeeks);
    key = "hist:" + projectId + ":" + str(weeks);
    mine = False;
    if not inflight(key) {
        LOADS[key] = fetchHistory(projectId, weeks);
        mine = True;
    }
    pending: any = LOADS[key];
    try {
        got: any = await pending;
        # A reply for a filter the user has already left is dropped.
        if historyProject == (projectId or "all") and historyWeeks == str(weeks) {
            history = got;
            historyFailed = False;
        }
        # "tasks added" is this week across every project: the last entry
        # of an unfiltered history, kept across filters (no second walker).
        if got and projectId == "" and len(got.added) > 0 {
            weekAdded = got.added[len(got.added) - 1];
            addedFailed = False;
        }
    } except Exception as e {
        historyFailed = True;
        if projectId == "" and weekAdded < 0 {
            addedFailed = True;
        }
    }
    if mine {
        LOADS[key] = None;
    }
    historyLoading = False;
}
