"""One labelled row of chips in the arrow editor (what the arrow carries, what
moves work across on its own)."""

def:pub EdgePicks(
    label: str,
    picks: list[dict[str, str]],
    value: str = "",
    onPick: Callable[[str], None] = None
) -> JsxElement {
    return
        <div className="flex flex-col gap-1.5" role="group" aria-label={label}>
            <span className="text-[13px] font-medium">{label}</span>
            <div className="flex flex-wrap items-center gap-1.5">
                {for pick in picks {
                    <button
                        key={pick["text"]}
                        type="button"
                        aria-pressed={value == pick["key"]}
                        className={"h-[26px] rounded-md border bg-card px-2 text-[12.5px] whitespace-nowrap transition-colors "
                            + (
                                "border-foreground font-medium"
                                    if value == pick["key"]
                                    else "border-border hover:bg-bg-hover"
                            )}
                        onClick={lambda { if onPick { onPick(pick["key"]); }}}
                    >
                        {pick["text"]}
                    </button>
                }}
            </div>
        </div>;
}
