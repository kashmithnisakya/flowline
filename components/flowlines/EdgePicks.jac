"""One labelled row of toggle buttons in the transition editor (what the
arrow carries, what moves work across)."""

def:pub EdgePicks(
    label: str,
    picks: list[dict[str, str]],
    value: str = "",
    onPick: Callable[[str], None] = None
) -> JsxElement {
    return
        <div className="mt-2 flex flex-col gap-1" role="group" aria-label={label}>
            <span className="text-xs text-muted-foreground">{label}</span>
            <div className="flex flex-wrap items-center gap-1">
                {for pick in picks {
                    <button
                        key={pick["text"]}
                        type="button"
                        aria-pressed={value == pick["key"]}
                        className={"rounded-sm border px-1.5 py-0.5 text-xs transition-colors "
                            + (
                                "border-input bg-muted font-semibold text-foreground"
                                    if value == pick["key"]
                                    else "border-transparent text-muted-foreground hover:text-foreground"
                            )}
                        onClick={lambda { if onPick { onPick(pick["key"]); }}}
                    >
                        {pick["text"]}
                    </button>
                }}
            </div>
        </div>;
}
