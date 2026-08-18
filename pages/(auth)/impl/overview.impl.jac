"""Implementations for the Overview page."""

impl OverviewPage.loadAll -> None {
    monday = mondayOf(localIso(new(Date)));
    sunday = shiftDay(monday, 6);
    # Four weeks of log entries in one call: this week feeds the page, the
    # three before it feed the deltas and sparklines.
    since = shiftDay(monday, -21);
    loading = True;
    failed = False;
    try {
        tResult = root spawn ListTasks();
        mResult = root spawn ListMembers();
        pResult = root spawn ListProjects();
        lResult = root spawn ListLogEntries(from_date=since, to_date=sunday);
        tasks = tResult.reports[0] if tResult.reports else [];
        members = mResult.reports[0] if mResult.reports else [];
        projects = pResult.reports[0] if pResult.reports else [];
        fetched = lResult.reports[0] if lResult.reports else [];
        entries = [
            e
            for e in fetched
            if e.date >= monday
        ];
        pastEntries = [
            e
            for e in fetched
            if e.date < monday
        ];
    } except Exception as e {
        # The page shows the failure panel itself; no toast on top of it.
        failed = True;
    }
    loading = False;
}
