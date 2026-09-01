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
        # Two weeks of log back-story so a blocked move's reason is still in
        # the window; the queue lists themselves are open-task-bounded.
        dResult = root spawn Digest(from_date=shiftDay(monday, -14));
        counts = cResult.reports[0] if cResult.reports else TaskTotals();
        logs = lResult.reports[0] if lResult.reports else LogTotals();
        aPage = aResult.reports[0] if aResult.reports else None;
        attention = aPage.rows if aPage else [];
        attentionTotal = aPage.total if aPage else 0;
        members = mResult.reports[0] if mResult.reports else [];
        projects = pResult.reports[0] if pResult.reports else [];
        # Untyped on purpose: the report arrives as a plain object, and typing
        # it as Snapshot would mean importing obj types from walkers.insights.
        snap: any = dResult.reports[0] if dResult.reports else None;
        reviewQueue = snap["review_queue"] if snap else [];
        # Blocked and Review rows already sit in the other two panels, so the
        # quiet list keeps only the rest of the snapshot's aging entries.
        stale: list[dict] = [];
        for r in (snap["aging"] if snap else []) {
            if r["status"] != "Blocked" and r["status"] != "Review" {
                stale.append(r);
            }
        }
        quiet = stale;
        info: dict[str, dict] = {};
        for b in (snap["blocked"] if snap else []) {
            info[b["task_id"]] = b;
        }
        blockedInfo = info;
    } except Exception as e {
        # The page shows the failure panel itself; no toast on top of it.
        failed = True;
    }
    loading = False;
}
