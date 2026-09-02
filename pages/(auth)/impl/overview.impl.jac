"""Implementations for the Overview page."""

impl OverviewPage.loadAll -> None {
    monday = mondayOf(localIso(new(Date)));
    loading = True;
    failed = False;
    try {
        # One call, one traversal. Two weeks of log back-story so a blocked
        # move's reason is still in the window.
        result = root spawn OverviewSnapshot(
            monday=monday, from_date=shiftDay(monday, -14), attention_size=8
        );
        # Untyped on purpose: typing the report would pull walkers.insights
        # objs into the client bundle for the queue lists.
        data: any = result.reports[0] if result.reports else None;
        counts = data["counts"] if data else TaskTotals();
        logs = data["logs"] if data else LogTotals();
        attention = data["attention"] if data else [];
        attentionTotal = data["attention_total"] if data else 0;
        members = data["members"] if data else [];
        projects = data["projects"] if data else [];
        reviewQueue = data["review_queue"] if data else [];
        # Blocked and Review rows already sit in the other two panels, so the
        # quiet list keeps only the rest of the snapshot's aging entries.
        stale: list[dict] = [];
        for r in (data["aging"] if data else []) {
            if r["status"] != "Blocked" and r["status"] != "Review" {
                stale.append(r);
            }
        }
        quiet = stale;
        info: dict[str, dict] = {};
        for b in (data["blocked"] if data else []) {
            info[b["task_id"]] = b;
        }
        blockedInfo = info;
    } except Exception as e {
        # The page shows the failure panel itself; no toast on top of it.
        failed = True;
    }
    loading = False;
}
