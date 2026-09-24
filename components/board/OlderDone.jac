"""The Done group's footer: open the Done history older than the board's
window, page through it, or fold it away again."""

def:pub OlderDone(
    total: int,
    showing: bool,
    shown: int,
    more: bool,
    loading: bool,
    onToggle: Callable[[], None],
    onMore: Callable[[], None]
) -> JsxElement {
    link = "rounded-sm px-1 py-1 text-[13px] text-primary hover:underline disabled:opacity-60";
    if total == 0 and not showing {
        return <></>;
    }
    return
        <div className="flex flex-wrap items-center gap-4 pt-1 pl-8">
            {if showing and (more or loading) {
                <button
                    key="more"
                    type="button"
                    disabled={loading}
                    className={link}
                    onClick={onMore}
                >
                    {"Loading…"
                        if loading
                        else "Show more"
                            + (
                                " (" + str(shown) + " of " + str(total) + ")"
                                    if total > 0
                                    else ""
                            )}
                </button>
            }}
            <button type="button" className={link} onClick={onToggle}>
                {(
                    (str(total) + " more done earlier")
                        if total > 0
                        else "Show done earlier"
                )
                    if not showing
                    else "Show the recent days only"}
            </button>
        </div>;
}
