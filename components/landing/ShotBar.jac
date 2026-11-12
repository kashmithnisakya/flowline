"""The product picture's filter row and column heads, inert like the rest of it.
A phone's picture keeps the two filters and drops the columns the row drops."""

glob CONTROL: str = "inline-flex h-[30px] items-center gap-1.5 rounded-md px-3 text-[13px] font-medium whitespace-nowrap";

def:pub ShotBar -> JsxElement {
    return
        <div>
            <div className="flex items-center gap-2 px-6 py-2.5 max-sm:px-4">
                <span
                    className={CONTROL + " border border-border-strong bg-bg-elevated"}
                >
                    <svg
                        className="size-4"
                        viewBox="0 0 16 16"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth={1.5}
                        strokeLinecap="round"
                    >
                        <path d="M2.5 4.5h11M4.5 8h7M6.5 11.5h3"/>
                    </svg>
                    Filter
                </span>
                <span className={CONTROL}>All tasks</span>
                <span
                    className="ml-auto flex h-[30px] w-[220px] items-center rounded-md border bg-bg-elevated px-2 text-[13px] text-text-tertiary max-sm:hidden"
                >
                    Search tasks
                </span>
                <span className={CONTROL + " max-sm:hidden"}>Display</span>
            </div>
            <div
                className="lp-shot-row h-[26px] border-b border-border-subtle text-[12px] text-text-tertiary max-sm:hidden"
            >
                <span/>
                <span>Task</span>
                <span>People</span>
                <span>Due</span>
                <span>GitHub</span>
                <span>AI</span>
            </div>
        </div>;
}
