"""The AI page's tabs: the agents, the workspace's own model keys, and the
runs and responsibilities that were the whole page before agents."""

glob AI_TABS: list[list[str]] = [
         ["agents", "Agents"],
         ["models", "Models and keys"],
         ["runs", "Runs and responsibilities"]
     ];

def:pub AiTabs(tab: str, onTab: Callable[[str], None]) -> JsxElement {
    return
        <div
            role="tablist"
            aria-label="AI"
            className="flex gap-0.5 overflow-x-auto border-b"
        >
            {for t in AI_TABS {
                <button
                    key={t[0]}
                    type="button"
                    role="tab"
                    aria-selected={tab == t[0]}
                    className={"-mb-px border-b-2 px-3 py-1.5 text-[13px] whitespace-nowrap transition-colors "
                        + (
                            "border-foreground font-medium text-foreground"
                                if tab == t[0]
                                else "border-transparent text-muted-foreground hover:text-foreground"
                        )}
                    onClick={lambda { onTab(t[0]); }}
                >
                    {t[1]}
                </button>
            }}
        </div>;
}
