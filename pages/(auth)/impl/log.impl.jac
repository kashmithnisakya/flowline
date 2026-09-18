"""Implementations for the Daily Log page."""

impl DailyLogPage.loadWeek -> None {
    # Sequence fence: responses can resolve out of order (a small week
    # answers before a big one that was asked earlier; ListLogEntries is
    # never served from the browser cache), so only the newest request may
    # assign state.
    seq = (weekReqRef.current or 0) + 1;
    weekReqRef.current = seq;
    monday = mondayOf(selectedDate);
    sunday = shiftDay(monday, 6);
    # From the Friday before: a Monday standup reads back to it, and Stuck
    # sees a task blocked late last week.
    start = shiftDay(monday, -3);
    # A cold week (a Monday other than the one on screen) re-enters the
    # skeleton; day hops inside the loaded week stay an instant local filter.
    if monday != loadedMonday {
        loading = True;
    }
    weekStreaming = True;
    try {
        # Page 1 goes out beside the workspace read (first load only) and
        # the blocked list; it lands and paints on its own. A week that
        # outgrew a page (a bulk import writes a row per issue) streams the
        # rest in behind it. Bounded: ten pages of 500 is more week than
        # anyone reads.
        w: any = window;
        jobs: list[any] = [weekPage(seq, monday, start, sunday, 1, [])];
        needRoster = len(memberNames) == 0 or len(projects) == 0;
        if needRoster {
            jobs.append(loadShared());
        }
        if not blockedLive {
            jobs.append(loadBlocked());
        }
        landed: list[any] = await w.Promise.all(jobs);
        page: dict[str, any] = landed[0];
        more = bool(page["more"]);
        pageNo = 2;
        while more and pageNo <= 10 {
            page = await weekPage(seq, monday, start, sunday, pageNo, page["rows"]);
            more = bool(page["more"]);
            pageNo = pageNo + 1;
        }
        if needRoster and not bool(landed[1]) and weekReqRef.current == seq {
            loadFailed = True;
        }
    } except Exception as e {
        # The page says so itself (panel or strip); no toast.
        if weekReqRef.current == seq {
            loadFailed = True;
        }
    }
    if weekReqRef.current == seq {
        loading = False;
        retrying = False;
        weekStreaming = False;
    }
}

# One page of the week's entries on top of `sofar`; when this request is
# still the newest, the rows go on screen at once. Answers the rows so far
# and whether the server has more.
impl DailyLogPage.weekPage(
    seq: int, monday: str, start: str, sunday: str, pageNo: int, sofar: list[LogEntry]
) -> dict[str, any] {
    result = root spawn ListLogEntries(
        from_date=start, to_date=sunday, page=pageNo, page_size=500
    );
    got = result.reports[0] if result.reports else None;
    if not got {
        return {"rows": sofar, "more": False};
    }
    gathered = sofar + got.rows;
    if weekReqRef.current == seq {
        # Wire order is newest day first; the components order a day by
        # its stamps themselves.
        entries = [r for r in gathered];
        weekTotal = got.total;
        weekLoaded = len(gathered);
        loadedMonday = monday;
        loadedFrom = start;
        loadFailed = False;
        loading = False;
    }
    return {"rows": gathered, "more": got.has_more};
}

impl DailyLogPage.loadShared -> bool {
    # Roster and projects only on the first load; they do not change with
    # the week. The full member views feed the entry dialog.
    ws = await loadWorkspace();
    if not ws["ok"] {
        return False;
    }
    fetched: list[MemberView] = ws["members"];
    active = [
        m
        for m in fetched
        if m.active
    ];
    members = active;
    memberNames = [m.name for m in active];
    rosterReady = True;
    allProjects: list[Project] = ws["projects"];
    projects = [
        p
        for p in allProjects
        if p.active
    ];
    return True;
}

impl DailyLogPage.loadBlocked -> None {
    # "attention" lists blocked tasks first; a failure keeps Stuck on the log.
    try {
        result = root spawn ListTasks(scope="attention", page_size=100);
        got = result.reports[0] if result.reports else None;
        if got {
            blockedTasks = [
                t
                for t in got.rows
                if t.status == "Blocked"
            ];
            blockedLive = True;
        }
    } except Exception as e {
        blockedLive = False;
    }
}

impl DailyLogPage.retryLoad -> None {
    retrying = True;
    await loadWeek();
}

# `rowId`, not `entryId`: a parameter named like a `has` field compiles to
# that field's state cell, so every toggle used to add the edit dialog's id.
impl DailyLogPage.toggleSelect(rowId: str) -> None {
    if rowId in selectedIds {
        selectedIds = [
            i
            for i in selectedIds
            if i != rowId
        ];
    } else {
        selectedIds = selectedIds + [rowId];
    }
}

impl DailyLogPage.deleteSelected -> None {
    if len(selectedIds) == 0 {
        return;
    }
    gone = [i for i in selectedIds];
    try {
        root spawn DeleteLogEntries(entry_ids=gone);
        selecting = False;
        selectedIds = [];
        entries = [
            e
            for e in entries
            if jid(e) not in gone
        ];
        await loadWeek();
        # A cached read can still carry the rows; they cannot come back.
        entries = [
            e
            for e in entries
            if jid(e) not in gone
        ];
    } except Exception as e {
        toast.error("Failed to delete the selected entries");
    }
}

impl DailyLogPage.openNewEntry -> None {
    entryEditing = False;
    entryId = "";
    entryForm = {
        "date": selectedDate or todayIso(),
        "member": "",
        "member_name": "",
        "activity": "",
        "project": "none",
        "category": "",
        "status": "none",
        "issue_link": "",
        "pr_link": "",
        "notes": "",
        "repo": ""
    };
    entryOpen = True;
}

impl DailyLogPage.openEditEntry(en: LogEntry) -> None {
    entryEditing = True;
    entryId = jid(en);
    # Prefill every field: UpdateLogEntry overwrites the whole row, so an
    # absent value would blank real data on save.
    entryForm = {
        "date": en.date,
        "member": "",
        "member_name": en.member_name,
        "activity": en.activity,
        "project": "none",
        "category": en.category,
        "status": en.status or "none",
        "issue_link": en.issue_link,
        "pr_link": en.pr_link,
        "notes": en.notes,
        "repo": en.repo
    };
    entryOpen = True;
}

impl DailyLogPage.entryField(key: str, value: str) -> None {
    # A computed key does not survive a dict-literal spread; go through a local.
    updated = {** entryForm};
    updated[key] = value;
    entryForm = updated;
}

impl DailyLogPage.saveEntry -> None {
    if not entryForm["activity"].strip() {
        return;
    }
    if entryEditing {
        chosenStatus = "" if entryForm["status"] == "none" else entryForm["status"];
        entrySaving = True;
        try {
            uResult = root spawn UpdateLogEntry(
                entry_id=entryId,
                activity=entryForm["activity"].strip(),
                category=entryForm["category"],
                repo=entryForm["repo"],
                issue_link=entryForm["issue_link"],
                pr_link=entryForm["pr_link"],
                status=chosenStatus,
                notes=entryForm["notes"]
            );
            # Patch the row in place from the walker's report: an edit touches
            # LogEntry, which does not invalidate the week's Root-keyed reader
            # cache, so a refetch here would render the pre-edit values.
            updatedRow = uResult.reports[0] if uResult.reports else None;
            if updatedRow {
                entries = [(updatedRow if jid(e) == entryId else e) for e in entries];
            }
            entryOpen = False;
            toast.success("Entry updated");
        } except Exception as e {
            toast.error("Could not save the entry");
        }
        entrySaving = False;
        return;
    }
    if not entryForm["member"] {
        return;
    }
    entrySaving = True;
    ok = await createEntry(entryForm);
    if ok {
        entryOpen = False;
        toast.success("Entry added");
    }
    entrySaving = False;
}

impl DailyLogPage.createEntry(fields: dict[str, str]) -> bool {
    # The one create path: the dialog and the composer both land here.
    chosenStatus = "" if fields["status"] == "none" else fields["status"];
    try {
        result = root spawn LogActivity(
            date=fields["date"],
            member_id=fields["member"],
            activity=fields["activity"].strip(),
            project_id=("" if fields["project"] == "none" else fields["project"]),
            category=fields["category"],
            issue_link=fields["issue_link"],
            pr_link=fields["pr_link"],
            status=chosenStatus,
            notes=fields["notes"]
        );
        added = result.reports[0] if result.reports else None;
        if not added {
            toast.error("Could not save the entry");
            return False;
        }
        # A row for another day jumps there and the [selectedDate] effect
        # fetches it; one for this day shows at once and survives a cached read.
        if fields["date"] != selectedDate {
            selectedDate = fields["date"];
        } else {
            entries = entries + [added];
            await loadWeek();
            if jid(added) not in [jid(e) for e in entries] {
                entries = entries + [added];
            }
        }
        return True;
    } except Exception as e {
        toast.error("Could not save the entry");
    }
    return False;
}

impl DailyLogPage.quickLog(fields: dict[str, str]) -> bool {
    quickSaving = True;
    ok = await createEntry(
        {
            "date": selectedDate or todayIso(),
            "member": fields["member"],
            "activity": fields["activity"],
            "project": fields["project"],
            "category": "",
            "status": fields["status"],
            "issue_link": "",
            "pr_link": "",
            "notes": ""
        }
    );
    quickSaving = False;
    return ok;
}

impl DailyLogPage.logNote -> None {
    if viewMode != "day" or selecting {
        viewMode = "day";
        selecting = False;
        selectedIds = [];
        window.setTimeout(lambda { focusComposer(); }, 50);
        return;
    }
    focusComposer();
}

impl DailyLogPage.step(direction: int) -> None {
    if selectedDate {
        selectedDate = shiftDay(
            selectedDate, direction * (7 if viewMode == "week" else 1)
        );
    }
}
