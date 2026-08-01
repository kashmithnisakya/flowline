"""Implementations for the Daily Log page."""

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

impl DailyLogPage.toggleSelect(entryId: str) -> None {
    if entryId in selectedIds {
        selectedIds = [i for i in selectedIds if i != entryId];
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
