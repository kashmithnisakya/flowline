"""Implementations for the Overview page."""

impl OverviewPage.loadAll -> None {
    monday = mondayOf(todayIso());
    loading = True;
    failed = False;
    try {
        # One call, one traversal. Two weeks of log back-story so a blocked
        # move's reason is still in the window.
        result = root spawn OverviewSnapshot(
            monday=monday, from_date=shiftDay(monday, -14), attention_size=8
        );
        # Untyped on purpose: typing the report would pull services.insights.insights
        # objs into the client bundle for the queue lists.
        data: any = result.reports[0] if result.reports else None;
        counts = data["counts"] if data else None;
        logs = data["logs"] if data else None;
        attention = data["attention"] if data else [];
        attentionTotal = data["attention_total"] if data else 0;
        members = data["members"] if data else [];
        projects = data["projects"] if data else [];
        reviewQueue = data["review_queue"] if data else [];
        # Blocked and Review rows already sit in their own groups, so the
        # quiet list keeps only the rest of the snapshot's aging entries.
        stale: list[dict] = [];
        for r in (data["aging"] if data else []) {
            if r["status"] != "Blocked" and r["status"] != "Review" {
                stale.append(r);
            }
        }
        quiet = stale;
        info: dict[str, dict] = {};
        for b in (data["blocked"] if data else []) {
            info[b["task_id"]] = b;
        }
        blockedInfo = info;
        # Every task hangs under a project, so the tallies add up to all of them.
        total = 0;
        for pt in (data["counts"]["projects"] if data else []) {
            total = total + pt["total"];
        }
        taskTotal = total;
        if data and total == 0 {
            loadSetup();
        }
    } except Exception as e {
        # The page shows the failure panel itself; no toast on top of it.
        failed = True;
    }
    loading = False;
}

# Open work by due date, so a page of 200 starts with what is late and what
# is due soon. Done rows are skipped on the page, so one day of them is enough.
impl OverviewPage.loadDue -> None {
    try {
        result = root spawn ListTasks(
            scope="working", sort="due", done_days=1, page_size=200
        );
        got = result.reports[0] if result.reports else None;
        dueRows = got.rows if got else [];
    } except Exception as e {
        dueRows = [];
    }
    dueLoaded = True;
}

# Moves to Done per weekday, counted off this week's log: every move that
# lands a card in Done writes a "Moved to" line carrying the new status. The
# same arguments as the Log page, so the two share the reader cache.
impl OverviewPage.loadMoves -> None {
    monday = mondayOf(todayIso());
    days = [shiftDay(monday, i) for i in range(7)];
    try {
        perDay = [0, 0, 0, 0, 0, 0, 0];
        pageNo = 1;
        more = True;
        while more and pageNo <= 10 {
            result = root spawn ListLogEntries(
                from_date=monday, to_date=days[6], page=pageNo, page_size=500
            );
            got = result.reports[0] if result.reports else None;
            if not got {
                more = False;
            } else {
                for row in got.rows {
                    if row.status == "Done"
                        and row.task_id
                        and row.activity.startswith("Moved to ") {
                        for i in range(7) {
                            if row.date == days[i] {
                                perDay[i] = perDay[i] + 1;
                            }
                        }
                    }
                }
                more = got.has_more;
            }
            pageNo = pageNo + 1;
        }
        doneMoves = perDay;
        movesFailed = False;
    } except Exception as e {
        movesFailed = True;
    }
    movesLoaded = True;
}

# What the first-run checklist ticks off: a flow line, its first column, the
# template it came from, and whether GitHub is configured and connected.
impl OverviewPage.loadSetup -> None {
    try {
        line = root spawn GetFlowLine(with_counts=False);
        views = line.reports[0] if line.reports else [];
        stepCount = len(views);
        firstStepName = views[0].name if len(views) > 0 else "";
        meta = root spawn GetFlowLineMeta();
        key = meta.reports[0]["template_key"] if meta.reports else "";
        named = "";
        for tpl in FLOW_LINE_TEMPLATES {
            if key and tpl["key"] == key {
                named = tpl["name"];
            }
        }
        templateName = named;
        gh = root spawn GithubStatus();
        conn = gh.reports[0] if gh.reports else None;
        ghConfigured = bool(conn and conn.configured);
        ghConnected = bool(conn and conn.connected);
        ghLogin = conn.account_login if conn else "";
    } except Exception as e {
        # A checklist with defaults still points at every next step.
        templateName = "";
    }
    setupLoaded = True;
}

impl OverviewPage.loadHistory -> None {
    historyLoading = True;
    try {
        result = root spawn TaskHistory(
            project_id="" if historyProject == "all" else historyProject,
            monday=mondayOf(todayIso()),
            weeks=int(historyWeeks)
        );
        got = result.reports[0] if result.reports else None;
        history = got;
        # The figure "tasks added" is this week across every project, so it
        # is taken only from an unfiltered history and kept across filters.
        if got and historyProject == "all" and len(got.added) > 0 {
            weekAdded = got.added[len(got.added) - 1];
        }
        historyFailed = False;
    } except Exception as e {
        historyFailed = True;
    }
    historyLoading = False;
}
