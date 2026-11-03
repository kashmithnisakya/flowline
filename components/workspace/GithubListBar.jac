"""The list's toolbar: issues or pull requests, the state filter, how many are
shown and how old the stored page is. The search box goes in as `children`.
"""

import from ...components.ui.select {
    Select,
    SelectTrigger,
    SelectValue,
    SelectContent,
    SelectItem
}

glob ISSUE_STATES: list[list[str]] = [
         ["open", "Open"],
         ["closed", "Closed"],
         ["all", "Every state"]
     ],
     LIST_TABS: list[list[str]] = [["issues", "Issues"], ["pulls", "Pull requests"]];

def:pub GithubListBar(
    tab: str,
    state: str,
    countNum: str,
    countWord: str,
    listAge: str,
    showAge: bool,
    refreshing: bool,
    refreshBusy: bool,
    onTab: Callable[[str], None],
    onState: Callable[[str], None],
    onRefresh: Callable[[], any],
    children: any = None
) -> JsxElement {
    return
        <div className="flex flex-wrap items-center gap-2 border-b px-3 py-2">
            <div
                className="inline-flex items-center gap-0.5 rounded-md border bg-muted p-0.5"
            >
                {for item in LIST_TABS {
                    <button
                        key={item[0]}
                        type="button"
                        aria-pressed={tab == item[0]}
                        className={"rounded-sm px-2.5 py-1 text-[13px] "
                            + (
                                "bg-card font-semibold text-foreground"
                                    if tab == item[0]
                                    else "text-muted-foreground hover:text-foreground"
                            )}
                        onClick={lambda { onTab(item[0]); }}
                    >
                        {item[1]}
                    </button>
                }}
            </div>
            <Select value={state} onValueChange={lambda (v: str) { onState(v); }}>
                <SelectTrigger
                    className="toolbar-filter"
                    aria-label="Filter by state"
                    data-active={"true" if state != "open" else "false"}
                >
                    <SelectValue placeholder="State"/>
                </SelectTrigger>
                <SelectContent>
                    {for s in ISSUE_STATES {
                        <SelectItem key={s[0]} value={s[0]}>{s[1]}</SelectItem>
                    }}
                </SelectContent>
            </Select>
            <span className="text-xs text-subtle">
                <span className="num">{countNum}</span>
                {countWord}
            </span>
            {if showAge {
                <span key="age" className="flex items-center gap-1 text-xs text-subtle">
                    {"· " + listAge}
                    <button
                        type="button"
                        className="rounded-sm px-1.5 py-0.5 text-xs text-muted-foreground transition-colors duration-150 hover:bg-accent hover:text-foreground disabled:opacity-50"
                        onClick={lambda { onRefresh(); }}
                        disabled={refreshBusy}
                        title="Read this list from GitHub again"
                    >
                        {"Refreshing…" if refreshing else "Refresh"}
                    </button>
                </span>
            }}
            {children}
        </div>;
}
