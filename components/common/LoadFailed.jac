"""What a page shows when its data did not arrive. Two volumes: a full panel
for a first load that produced nothing (an empty board must not read as "no
tasks"), and a one-line strip when a later refresh failed but the page still
has data worth keeping on screen.
"""

import from ..ui.button { Button }
import from .glyphs { WarnIcon, Spinner }


def:pub LoadFailed(
    title: str,
    detail: str = "Something went wrong while fetching your workspace. Your data is fine; this is the connection.",
    onRetry: Callable[[], None] = None,
    retrying: bool = False
) -> JsxElement {
    return
        <div
            className="flex flex-col items-center gap-4 rounded-xl border border-dashed border-destructive/40 bg-destructive/5 px-6 py-14 text-center animate-in fade-in slide-in-from-top-1"
            role="alert"
        >
            <WarnIcon size={28} className="text-destructive"/>
            <div>
                <p className="text-sm font-semibold">{title}</p>
                <p className="mx-auto mt-1 max-w-md text-sm text-muted-foreground">
                    {detail}
                </p>
            </div>
            {if onRetry {
                <Button
                    key="retry"
                    variant="outline"
                    size="sm"
                    disabled={retrying}
                    onClick={lambda { onRetry(); }}
                >
                    {if retrying {
                        <Spinner key="sp"/>
                    }}
                    {"Retrying…" if retrying else "Try again"}
                </Button>
            }}
        </div>;
}


# `since` is the wall-clock time of the last good load ("10:42"); empty
# hides the "showing data from" part.
def:pub StaleDataStrip(
    since: str = "", onRetry: Callable[[], None] = None, retrying: bool = False
) -> JsxElement {
    return
        <div
            className="flex flex-wrap items-center gap-x-3 gap-y-1 rounded-lg border border-warning/40 bg-warning/10 px-3 py-1.5 text-xs animate-in fade-in slide-in-from-top-1"
            role="status"
        >
            <WarnIcon size={14} className="shrink-0 text-warning"/>
            <span className="font-medium">Could not refresh.</span>
            {if since {
                <span key="since" className="text-muted-foreground">
                    {"Showing data from " + since + "."}
                </span>
            }}
            {if onRetry {
                <button
                    key="retry"
                    type="button"
                    className="ml-auto font-semibold text-foreground underline-offset-2 hover:underline disabled:opacity-60"
                    disabled={retrying}
                    onClick={lambda { onRetry(); }}
                >
                    {"Retrying…" if retrying else "Retry"}
                </button>
            }}
        </div>;
}
