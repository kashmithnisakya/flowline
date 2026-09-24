"""Toolbar controls for the flow line page: a segmented pill switch and the
zoom group. One height (30px) so the toolbar reads as a single row."""

import from ..ui.skeleton { Skeleton }

# `options` rows are {value, label} plus an optional `aria` name, used where a
# script or screen reader needs more than the short visible word.
def:pub Segmented(
    label: str,
    options: list[dict[str, str]],
    value: str,
    onChange: Callable[[str], None] = None,
    className: str = ""
) -> JsxElement {
    return
        <div
            role="group"
            aria-label={label}
            className={"inline-flex h-[30px] shrink-0 items-center gap-0.5 rounded-full bg-muted p-0.5 "
                + className}
        >
            {for opt in options {
                <button
                    key={opt["value"]}
                    type="button"
                    aria-pressed={value == opt["value"]}
                    aria-label={opt["aria"] if "aria" in opt else None}
                    className={"h-full rounded-full px-3 text-[12.5px] transition-colors duration-150 "
                        + (
                            "bg-card font-semibold text-foreground shadow-xs"
                                if value == opt["value"]
                                else "text-muted-foreground hover:text-foreground"
                        )}
                    onClick={lambda { if onChange { onChange(opt["value"]); }}}
                >
                    {opt["label"]}
                </button>
            }}
        </div>;
}


def:pub ZoomControls(
    zoom: float,
    onOut: Callable[[], None] = None,
    onIn: Callable[[], None] = None,
    onActual: Callable[[], None] = None,
    onFit: Callable[[], None] = None,
    className: str = "",
    # The first-load frame: the readout is a block, since the fit zoom is
    # not known until the flow line is.
    pending: bool = False
) -> JsxElement {
    pct = str(int(zoom * 100.0 + 0.5)) + "%";
    return
        <div
            role="group"
            aria-label="Zoom"
            className={"flex h-[30px] shrink-0 items-center gap-0.5 rounded-full bg-muted p-0.5 "
                + className}
        >
            <button
                type="button"
                aria-label="Zoom out"
                title="Zoom out (-)"
                className="flex size-[26px] items-center justify-center rounded-full text-muted-foreground transition-colors hover:bg-card hover:text-foreground"
                onClick={lambda { if onOut { onOut(); }}}
            >
                <svg
                    width={14}
                    height={14}
                    viewBox="0 0 16 16"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={1.7}
                    strokeLinecap="round"
                    aria-hidden="true"
                >
                    <path d="M3 8h10"/>
                </svg>
            </button>
            <button
                type="button"
                title="Zoom to 100%"
                data-zoom={None if pending else pct}
                className="num h-full min-w-12 rounded-full px-1 text-[12.5px] text-muted-foreground transition-colors hover:bg-card hover:text-foreground"
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
                className="flex size-[26px] items-center justify-center rounded-full text-muted-foreground transition-colors hover:bg-card hover:text-foreground"
                onClick={lambda { if onIn { onIn(); }}}
            >
                <svg
                    width={14}
                    height={14}
                    viewBox="0 0 16 16"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={1.7}
                    strokeLinecap="round"
                    aria-hidden="true"
                >
                    <path d="M8 3v10M3 8h10"/>
                </svg>
            </button>
            <button
                type="button"
                title="Fit the whole flow line (F)"
                className="ml-0.5 inline-flex h-full items-center gap-1.5 rounded-full bg-card px-3 text-[12.5px] font-semibold text-foreground shadow-xs transition-colors hover:bg-accent"
                onClick={lambda { if onFit { onFit(); }}}
            >
                <svg
                    width={14}
                    height={14}
                    viewBox="0 0 16 16"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={1.5}
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    aria-hidden="true"
                >
                    <path d="M2.5 5.5v-3h3M10.5 2.5h3v3M13.5 10.5v3h-3M5.5 13.5h-3v-3"/>
                </svg>
                Fit
            </button>
        </div>;
}
