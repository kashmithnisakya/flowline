"""The flow line toolbar's segmented switch. `options` rows are {value, label}
plus an optional `aria` name, used where a script or screen reader needs more
than the short visible word."""

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
            className={"inline-flex h-[30px] shrink-0 items-center gap-0.5 rounded-[7px] bg-bg-surface p-0.5 "
                + className}
        >
            {for opt in options {
                <button
                    key={opt["value"]}
                    type="button"
                    aria-pressed={value == opt["value"]}
                    aria-label={opt["aria"] if "aria" in opt else None}
                    className={"h-[26px] rounded-[5px] px-2.5 text-[12.5px] transition-colors duration-150 "
                        + (
                            "bg-card font-medium text-text-primary ring-1 ring-border"
                                if value == opt["value"]
                                else "text-text-secondary hover:text-text-primary"
                        )}
                    onClick={lambda { if onChange { onChange(opt["value"]); }}}
                >
                    {opt["label"]}
                </button>
            }}
        </div>;
}
