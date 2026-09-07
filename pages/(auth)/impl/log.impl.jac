"""Implementations for the Daily Log page."""

impl DailyLogPage.loadWeek -> None {
    # Sequence fence: responses can resolve out of order (the 60s reader
    # cache makes the previous week near-instant while a new week is a slow
    # round-trip), so only the newest request may assign state.
    seq = (weekReqRef.current or 0) + 1;
    weekReqRef.current = seq;
    monday = mondayOf(selectedDate);
    sunday = shiftDay(monday, 6);
    # A cold week (a Monday other than the one on screen) re-enters the
    # skeleton; day hops inside the loaded week stay an instant local filter.
    if monday != loadedMonday {
        loading = True;
    }
    weekStreaming = True;
    try {
        # Page 1 lands and paints; a week that outgrew a page (a bulk import
        # writes a row per issue) streams the rest in behind it. Bounded:
        # ten pages of 500 is more week than anyone reads.
        gathered: list[LogEntry] = [];
        pageNo = 1;
        more = True;
        while more and pageNo <= 10 {
            result = root spawn ListLogEntries(
                from_date=monday, to_date=sunday, page=pageNo, page_size=500
            );
            got = result.reports[0] if result.reports else None;
            if not got {
                more = False;
            } else {
                gathered = gathered + got.rows;
                more = got.has_more;
                if weekReqRef.current == seq {
                    # The wire order is newest day first (so page 1 is the
                    # end of the week); the table reads chronologically, so
                    # the assembled week is sorted back before it renders.
                    shownRows = [r for r in gathered];
                    shownRows.sort(
                        key=lambda (r: LogEntry) { r.date + r.member_name; }
                    );
                    entries = shownRows;
                    weekTotal = got.total;
                    weekLoaded = len(shownRows);
                    loadedMonday = monday;
                    loadFailed = False;
                    loading = False;
                }
            }
            pageNo = pageNo + 1;
        }
        # Roster and projects only on the first load; they do not change
        # with the week. The full member views feed the entry dialog.
        if len(memberNames) == 0 {
            mResult = root spawn ListMembers();
            fetched = mResult.reports[0] if mResult.reports else [];
            active = [
                m
                for m in fetched
                if m.active
            ];
            members = active;
            memberNames = [m.name for m in active];
        }
        if len(projects) == 0 {
            pResult = root spawn ListProjects();
            allProjects = pResult.reports[0] if pResult.reports else [];
            projects = [
                p
                for p in allProjects
                if p.active
            ];
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

impl DailyLogPage.retryLoad -> None {
    retrying = True;
    await loadWeek();
}

impl DailyLogPage.toggleSelect(entryId: str) -> None {
    if entryId in selectedIds {
        selectedIds = [
            i
            for i in selectedIds
            if i != entryId
        ];
    } else {
        selectedIds = selectedIds + [entryId];
    }
}

impl DailyLogPage.deleteSelected -> None {
    if len(selectedIds) == 0 {
        return;
    }
    try {
        root spawn DeleteLogEntries(entry_ids=selectedIds);
        selecting = False;
        selectedIds = [];
        await loadWeek();
    } except Exception as e {
        toast("Failed to delete the selected entries");
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
    chosenStatus = "" if entryForm["status"] == "none" else entryForm["status"];
    try {
        if entryEditing {
            entrySaving = True;
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
            toast("Entry updated");
        } else {
            if not entryForm["member"] {
                return;
            }
            entrySaving = True;
            root spawn LogActivity(
                date=entryForm["date"],
                member_id=entryForm["member"],
                activity=entryForm["activity"].strip(),
                project_id=(
                    "" if entryForm["project"] == "none" else entryForm["project"]
                ),
                category=entryForm["category"],
                issue_link=entryForm["issue_link"],
                pr_link=entryForm["pr_link"],
                status=chosenStatus,
                notes=entryForm["notes"]
            );
            toast("Entry added");
        }
        entryOpen = False;
        # A new entry can land outside the loaded week; jumping selectedDate
        # there lets the [selectedDate] effect fetch and show that day. An
        # edit already patched `entries` and must not refetch over it.
        if not entryEditing {
            if entryForm["date"] != selectedDate {
                selectedDate = entryForm["date"];
            } else {
                await loadWeek();
            }
        }
    } except Exception as e {
        toast("Could not save the entry");
    }
    entrySaving = False;
}
