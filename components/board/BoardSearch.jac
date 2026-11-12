"""The board's title filter: matches a title or an issue or PR number. "/" from
the board focuses it (data-board-search), Escape clears it."""

def:pub BoardSearch(
    query: str, onQuery: Callable[[str], None], className: str = ""
) -> JsxElement {
    return
        <label
            className={"flex h-[30px] items-center gap-1.5 rounded-md border border-input bg-card px-2 text-[13px] focus-within:outline-2 focus-within:outline-ring "
                + className}
        >
            <svg
                width={14}
                height={14}
                viewBox="0 0 16 16"
                aria-hidden="true"
                fill="none"
                stroke="currentColor"
                strokeWidth={1.6}
                strokeLinecap="round"
                className="shrink-0 text-subtle"
            >
                <circle cx={7} cy={7} r={4.5}/>
                <path d="m10.5 10.5 3 3"/>
            </svg>
            <input
                data-board-search="true"
                className="h-full min-w-0 flex-1 bg-transparent text-foreground outline-none placeholder:text-subtle focus-visible:outline-none"
                placeholder="Search tasks"
                aria-label="Filter by title or issue number"
                value={query}
                onChange={lambda (e: ChangeEvent) { onQuery(e.target.value); }}
                onKeyDown={lambda (e: KeyboardEvent) { if e.key == "Escape" and query {
                    e.preventDefault();
                    onQuery("");
                }}}
            />
            {if query {
                <button
                    key="clear"
                    type="button"
                    aria-label="Clear the title filter"
                    className="inline-flex size-5 items-center justify-center rounded-sm text-subtle hover:text-foreground"
                    onClick={lambda (e: MouseEvent) {
                        e.preventDefault();
                        onQuery("");
                    }}
                >
                    <svg
                        width={12}
                        height={12}
                        viewBox="0 0 16 16"
                        aria-hidden="true"
                        stroke="currentColor"
                        strokeWidth={1.8}
                        strokeLinecap="round"
                    >
                        <path d="m4 4 8 8M12 4l-8 8"/>
                    </svg>
                </button>
            } else {
                <span key="kbd" className="kbd max-md:hidden" aria-hidden="true">
                    /
                </span>
            } }
        </label>;
}
