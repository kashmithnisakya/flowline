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
    loading = True;
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
        every: list[dict] = [];
        for b in (data["blocked"] if data else []) {
            info[b["task_id"]] = b;
            every.append(b);
        }
        blockedInfo = info;
        blockedList = every;
        # Every task hangs under a project, so the tallies add up to all of
        # them. The checklist's reads are needed until a card reaches Done.
        total = 0;
        doneSum = 0;
        for pt in (data["counts"]["projects"] if data else []) {
            total = total + pt["total"];
            doneSum = doneSum + pt["done"];
        }
        for v in (data["counts"]["done_by_week"] if data else []) {
            doneSum = doneSum + v;
        }
        taskTotal = total;
        if data and doneSum == 0 {
            loadSetup();
        }
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

# This week's log, a day wider on each side: rows carry the server's UTC
# date, and the page buckets them by the local day of their stamp. `full`
# is False when the page cap cut the read short.
impl OverviewPage.fetchWeekLog(monday: str) -> any {
    rows: list[any] = [];
    pageNo = 1;
    more = True;
    while more and pageNo <= 10 {
        result = root spawn ListLogEntries(
            from_date=shiftDay(monday, -1),
            to_date=shiftDay(monday, 7),
            page=pageNo,
            page_size=500
        );
        got = result.reports[0] if result.reports else None;
        if not got {
            more = False;
        } else {
            for row in got.rows {
                rows.append(row);
            }
            more = got.has_more;
        }
        pageNo = pageNo + 1;
    }
    return {"rows": rows, "full": not more};
}

# Tasks that entered Done per local weekday. A task counts once, on the day
# of its last move into Done, and only while its last move left it in Done,
# so a reopened card drops out and the bars add up to the week's figure.
impl OverviewPage.loadMoves -> None {
    today = todayIso();
    monday = mondayOf(today);
    days = [shiftDay(monday, i) for i in range(7)];
    mine = False;
    key = "log:" + monday;
    if not inflight(key) {
        LOADS[key] = fetchWeekLog(monday);
        mine = True;
    }
    movesLoaded = False;
    movesFailed = False;
    pending: any = LOADS[key];
    try {
        got: any = await pending;
        rows: list[any] = got["rows"];
        perDay = [0, 0, 0, 0, 0, 0, 0];
        people: dict[str, list[int]] = {};
        entriesWeek = 0;
        movesOf: dict[str, list[dict]] = {};
        taskIds: list[str] = [];
        sinceAt: dict[str, str] = {};
        sinceDay: dict[str, str] = {};
        handWeek = 0;
        for row in rows {
            stamp = row.at or row.date;
            # A task event is dated by its own UTC stamp; a hand-written line
            # keeps the day its author picked.
            day = localDayOf(row.at, row.date)
                if row.task_id and row.at[:10] == row.date
                else row.date;
            slot = -1;
            for i in range(7) {
                if days[i] == day {
                    slot = i;
                }
            }
            if slot >= 0 {
                entriesWeek = entriesWeek + 1;
                for who in row.member_name.split(",") {
                    name = who.strip();
                    if name and name not in people {
                        people[name] = [0, 0, 0, 0, 0, 0, 0];
                    }
                    if name {
                        people[name][slot] = people[name][slot] + 1;
                    }
                }
            }
            if not row.task_id {
                if slot >= 0 {
                    handWeek = handWeek + 1;
                }
                continue;
            }
            tid = row.task_id;
            if row.status == "Blocked"
                and (tid not in sinceAt or sinceAt[tid] < stamp) {
                sinceAt[tid] = stamp;
                sinceDay[tid] = day;
            }
            if row.status and row.activity.startswith("Moved to ") {
                if tid not in movesOf {
                    movesOf[tid] = [];
                    taskIds.append(tid);
                }
                movesOf[tid].append({"stamp": stamp, "status": row.status, "day": day});
            }
        }
        for tid in taskIds {
            moves = movesOf[tid];
            moves.sort(key=lambda (m: dict) { m["stamp"]; });
            last = "";
            entered = "";
            for m in moves {
                if m["status"] == "Done" and last != "Done" {
                    entered = m["day"];
                }
                last = m["status"];
            }
            if last == "Done" and entered {
                for i in range(7) {
                    if days[i] == entered {
                        perDay[i] = perDay[i] + 1;
                    }
                }
            }
        }
        doneMoves = perDay;
        blockedSince = sinceDay;
        handEntries = handWeek;
        weekPeople = people;
        weekEntries = entriesWeek if got["full"] else -1;
    } except Exception as e {
        movesFailed = True;
    }
    if mine {
        LOADS[key] = None;
    }
    movesLoaded = True;
}

# What the first-run checklist ticks off: a flow line, its first column, the
# template it came from, and whether GitHub is configured and connected.
impl OverviewPage.fetchSetup -> any {
    line = root spawn GetFlowLine(with_counts=False);
    views = line.reports[0] if line.reports else [];
    meta = root spawn GetFlowLineMeta();
    key = meta.reports[0]["template_key"] if meta.reports else "";
    named = "";
    for tpl in FLOW_LINE_TEMPLATES {
        if key and tpl["key"] == key {
            named = tpl["name"];
        }
    }
    gh = root spawn GithubStatus();
    conn = gh.reports[0] if gh.reports else None;
    return {
        "steps": len(views),
        "first": views[0].name if len(views) > 0 else "",
        "template": named,
        "configured": bool(conn and conn.configured),
        "connected": bool(conn and conn.connected),
        "login": conn.account_login if conn else ""
    };
}

impl OverviewPage.loadSetup -> None {
    mine = False;
    if not inflight("setup") {
        LOADS["setup"] = fetchSetup();
        mine = True;
    }
    pending: any = LOADS["setup"];
    try {
        got: any = await pending;
        stepCount = got["steps"];
        firstStepName = got["first"];
        templateName = got["template"];
        ghConfigured = got["configured"];
        ghConnected = got["connected"];
        ghLogin = got["login"];
    } except Exception as e {
        # A checklist with defaults still points at every next step.
        templateName = "";
    }
    if mine {
        LOADS["setup"] = None;
    }
    setupLoaded = True;
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
        # "tasks added" is this week across every project, so it is taken
        # only from an unfiltered history and kept across filters.
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
    if projectId != "" and weekAdded < 0 {
        loadWeekAdded();
    }
}

# The week's "tasks added" when the charts were filtered before it landed.
impl OverviewPage.loadWeekAdded -> None {
    try {
        got: any = await fetchHistory("", 4);
        if got and len(got.added) > 0 {
            weekAdded = got.added[len(got.added) - 1];
            addedFailed = False;
        }
    } except Exception as e {
        addedFailed = True;
    }
}
