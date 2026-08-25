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
            t = spaceRoot();
            result = t spawn ListLogEntries(
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
        # Roster only on the first load; it does not change with the week.
        if len(memberNames) == 0 {
            t = spaceRoot();
            mResult = t spawn ListMembers();
            fetched = mResult.reports[0] if mResult.reports else [];
            memberNames = [
                m.name
                for m in fetched
                if m.active
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
        t = spaceRoot();
        t spawn DeleteLogEntries(entry_ids=selectedIds);
        selecting = False;
        selectedIds = [];
        await loadWeek();
    } except Exception as e {
        toast("Failed to delete the selected entries");
    }
}
