"""The flow line's zoom: out, the readout (a click goes to 100%), in, and Fit.
`pending` is the first-load frame: the fit zoom is not known yet, so the readout
is a block."""

import from ..ui.skeleton { Skeleton }

glob ICON_BTN: str = "flex size-[30px] items-center justify-center rounded-md text-text-secondary transition-colors hover:bg-bg-hover hover:text-text-primary";

def:pub ZoomControls(
    zoom: float,
    onOut: Callable[[], None] = None,
    onIn: Callable[[], None] = None,
    onActual: Callable[[], None] = None,
    onFit: Callable[[], None] = None,
    pending: bool = False,
    fitTitle: str = "Fit the whole flow line (F)"
) -> JsxElement {
    pct = str(int(zoom * 100.0 + 0.5)) + "%";
    if zoom < 0.1 {
        pct = str(float(int(zoom * 1000.0 + 0.5)) / 10.0) + "%";
    }
    return
        <div
            role="group"
            aria-label="Zoom"
            className="flex shrink-0 items-center gap-0.5"
        >
            <button
                type="button"
                aria-label="Zoom out"
                title="Zoom out (-)"
                className={ICON_BTN}
                onClick={lambda { if onOut { onOut(); }}}
            >
                <svg
                    width={16}
                    height={16}
                    viewBox="0 0 16 16"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={1.5}
                    strokeLinecap="round"
                    aria-hidden="true"
                >
                    <path d="M3.5 8h9"/>
                </svg>
            </button>
            <button
                type="button"
                title="Zoom to 100%"
                data-zoom={None if pending else pct}
                className="num h-[30px] min-w-11 rounded-md px-1 text-xs text-text-secondary transition-colors hover:bg-bg-hover hover:text-text-primary"
                onClick={lambda { if onActual { onActual(); }}}
            >
                {if pending {
                    <Skeleton key="ph" className="mx-auto h-3 w-8"/>
                } else {
                    <span key="pct">{pct}</span>
                } }
            </button>
            <button
                type="button"
                aria-label="Zoom in"
                title="Zoom in (+)"
                className={ICON_BTN}
                onClick={lambda { if onIn { onIn(); }}}
            >
                <svg
                    width={16}
                    height={16}
                    viewBox="0 0 16 16"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={1.5}
                    strokeLinecap="round"
                    aria-hidden="true"
                >
                    <path d="M8 3.5v9M3.5 8h9"/>
                </svg>
            </button>
            <button
                type="button"
                title={fitTitle}
                className="h-[30px] rounded-md px-2 text-[13px] font-medium transition-colors hover:bg-bg-hover"
                onClick={lambda { if onFit { onFit(); }}}
            >
                Fit
            </button>
        </div>;
}
