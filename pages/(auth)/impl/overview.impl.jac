"""Implementations for the Overview page."""

impl OverviewPage.loadAll -> None {
    monday = mondayOf(localIso(new(Date)));
    loading = True;
    failed = False;
    try {
        # Numbers first: both counts walkers read node fields over the whole
        # history, so the page is correct on a workspace of any size. The one
        # list is a page of eight, with its own total beside it.
        cResult = root spawn TaskCounts(monday=monday);
        lResult = root spawn LogCounts(monday=monday);
        aResult = root spawn ListTasks(scope="attention", page_size=8);
        mResult = root spawn ListMembers();
        pResult = root spawn ListProjects();
        counts = cResult.reports[0] if cResult.reports else TaskTotals();
        logs = lResult.reports[0] if lResult.reports else LogTotals();
        aPage = aResult.reports[0] if aResult.reports else None;
        attention = aPage.rows if aPage else [];
        attentionTotal = aPage.total if aPage else 0;
        members = mResult.reports[0] if mResult.reports else [];
        projects = pResult.reports[0] if pResult.reports else [];
    } except Exception as e {
        # The page shows the failure panel itself; no toast on top of it.
        failed = True;
    }
    loading = False;
}
