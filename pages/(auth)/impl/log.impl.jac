"""Implementations for the Daily Log page."""

impl DailyLogPage.loadLists -> None {
    try {
        mResult = root spawn ListMembers();
        pResult = root spawn ListProjects();
        rResult = root spawn ListRepos();
        fetchedMembers = mResult.reports[0] if mResult.reports else [];
        members = fetchedMembers;
        projects = pResult.reports[0] if pResult.reports else [];
        repos = rResult.reports[0] if rResult.reports else [];
        # Restore the last-used member if it still resolves.
        who = localStorage.getItem("standup_log_member") or "";
        found = False;
        for m in fetchedMembers {
            if m.id == who and m.active {
                found = True;
            }
        }
        if who and found {
            form = {**form, "member": who};
        } elif who {
            localStorage.removeItem("standup_log_member");
        }
    } except Exception as e {
        toast("Failed to load roster lists");
    }
}

impl DailyLogPage.loadWeek -> None {
    # Sequence fence: responses can resolve out of order (the 60s reader
    # cache makes the previous week near-instant while a new week is a slow
    # round-trip), so only the newest request may assign state.
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

impl DailyLogPage.setField(key: str, value: str) -> None {
    # NOTE: `{**form, key: value}` compiles to a JS object literal with a
    # LITERAL "key" property — the variable is ignored and the real field
    # never updates (inputs appear frozen). Build a copy and subscript it.
    updated = {**form};
    updated[key] = value;
    form = updated;
    if key == "member" and value {
        localStorage.setItem("standup_log_member", value);
    }
}

impl DailyLogPage.submitLog -> None {
    activity = form["activity"].strip();
    if not activity or not selectedDate {
        return;
    }
    if not editingEntryId and not form["member"] {
        return;
    }
    saving = True;
    wasEditing = bool(editingEntryId);
    keepMember = form["member"];
    repo = form["repo"] if form["repo"] != "none" else "";
    project = form["project"] if form["project"] != "none" else "";
    try {
        if editingEntryId {
            root spawn UpdateLogEntry(
                entry_id=editingEntryId, activity=activity,
                category=form["category"], repo=repo,
                issue_link=form["issue"].strip(), pr_link=form["pr"].strip(),
                status=form["status"], notes=form["notes"]
            );
        } else {
            root spawn LogActivity(
                date=selectedDate, member_id=form["member"], activity=activity,
                project_id=project, category=form["category"], repo=repo,
                issue_link=form["issue"].strip(), pr_link=form["pr"].strip(),
                status=form["status"], notes=form["notes"]
            );
        }
        editingEntryId = "";
        editingMemberName = "";
        if wasEditing {
            # Do not leak the edited row's dropdowns into the next entry.
            form = {**BLANK_LOG, "member": keepMember};
        } else {
            form = {
                **form, "activity": "", "issue": "", "pr": "", "notes": ""
            };
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
    form = {
        **form,
        "activity": en.activity,
        "category": en.category if en.category else "Coding",
        "repo": en.repo if en.repo else "none",
        "issue": en.issue_link,
        "pr": en.pr_link,
        "status": en.status if en.status else "In Progress",
        "notes": en.notes
    };
}

impl DailyLogPage.cancelEdit -> None {
    keepMember = form["member"];
    editingEntryId = "";
    editingMemberName = "";
    form = {**BLANK_LOG, "member": keepMember};
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
