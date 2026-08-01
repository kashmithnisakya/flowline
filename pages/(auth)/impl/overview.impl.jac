"""Implementations for the Overview page."""

impl OverviewPage.loadAll -> None {
    monday = mondayOf(localIso(new(Date)));
    sunday = shiftDay(monday, 6);
    try {
        tResult = root spawn ListTasks();
        mResult = root spawn ListMembers();
        pResult = root spawn ListProjects();
        lResult = root spawn ListLogEntries(from_date=monday, to_date=sunday);
        tasks = tResult.reports[0] if tResult.reports else [];
        members = mResult.reports[0] if mResult.reports else [];
        projects = pResult.reports[0] if pResult.reports else [];
        entries = lResult.reports[0] if lResult.reports else [];
    } except Exception as e {
        toast("Failed to load the overview");
    }
    loading = False;
}
