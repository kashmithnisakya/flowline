"""Implementations for the Daily Log page."""

impl DailyLogPage.loadLists -> None {
    try {
        mResult = root spawn ListMembers();
        rResult = root spawn ListRepos();
        fetchedMembers = mResult.reports[0] if mResult.reports else [];
        members = fetchedMembers;
        repos = rResult.reports[0] if rResult.reports else [];
        # Resolve WhoAmI against the freshly fetched roster: a stale jid
        # (e.g. after a data re-import) must not prefill the form, or every
        # submit would be rejected server-side with no visible reason.
        who = localStorage.getItem("standup_who") or "";
        found = False;
        for m in fetchedMembers {
            if jid(m) == who {
                found = True;
            }
        }
        if who and found {
            lMember = who;
        } elif who {
            localStorage.removeItem("standup_who");
            lMember = "";
        }
    } except Exception as e {
        toast("Failed to load roster lists");
    }
}

impl DailyLogPage.loadWeek -> None {
    # Sequence fence: responses can resolve out of order (the 60s reader
    # cache makes the previous week near-instant while a new week is a
    # slow round-trip), so only the newest request may assign state.
    seq = (weekReqRef.current or 0) + 1;
    weekReqRef.current = seq;
    monday = mondayOf(selectedDate);
    sunday = shiftDay(monday, 6);
    try {
        result = root spawn ListLogEntries(from_date=monday, to_date=sunday);
        if weekReqRef.current == seq {
            entries = result.reports[0] if result.reports else [];
        }
    } except Exception as e {
        toast("Failed to load log entries");
    }
    if weekReqRef.current == seq {
        loading = False;
    }
}

impl DailyLogPage.submitLog -> None {
    if not lActivity.strip() or not selectedDate {
        return;
    }
    if not editingEntryId and not lMember {
        return;
    }
    saving = True;
    wasEditing = bool(editingEntryId);
    repo = lRepo if lRepo != "none" else "";
    try {
        if editingEntryId {
            root spawn UpdateLogEntry(
                entry_id=editingEntryId, activity=lActivity.strip(),
                category=lCategory, repo=repo, issue_link=lIssue.strip(),
                pr_link=lPr.strip(), status=lStatus, notes=lNotes
            );
        } else {
            root spawn LogActivity(
                date=selectedDate, member_id=lMember, activity=lActivity.strip(),
                category=lCategory, repo=repo, issue_link=lIssue.strip(),
                pr_link=lPr.strip(), status=lStatus, notes=lNotes
            );
        }
        editingEntryId = "";
        editingMemberName = "";
        lActivity = "";
        lIssue = "";
        lPr = "";
        lNotes = "";
        if wasEditing {
            # Do not leak the edited row's dropdowns into the next fresh entry.
            lCategory = "Coding";
            lRepo = "none";
            lStatus = "In Progress";
        }
        await loadWeek();
    } except Exception as e {
        toast("Failed to save log entry");
    }
    saving = False;
}

impl DailyLogPage.startEdit(en: LogEntry) -> None {
    editingEntryId = jid(en);
    editingMemberName = en.member_name;
    lActivity = en.activity;
    lCategory = en.category if en.category else "Coding";
    lRepo = en.repo if en.repo else "none";
    lIssue = en.issue_link;
    lPr = en.pr_link;
    lStatus = en.status if en.status else "In Progress";
    lNotes = en.notes;
}

impl DailyLogPage.cancelEdit -> None {
    editingEntryId = "";
    editingMemberName = "";
    lActivity = "";
    lIssue = "";
    lPr = "";
    lNotes = "";
    lCategory = "Coding";
    lRepo = "none";
    lStatus = "In Progress";
}

impl DailyLogPage.deleteEntry(entryId: str) -> None {
    try {
        root spawn DeleteLogEntry(entry_id=entryId);
        if editingEntryId == entryId {
            cancelEdit();
        }
        await loadWeek();
    } except Exception as e {
        toast("Failed to delete entry");
    }
}
