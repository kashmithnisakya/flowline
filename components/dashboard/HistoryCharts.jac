"""The Overview's charts: a burn-up (scope and done, running totals), weekly
throughput, and this week's moves to Done per day. Marks are SVG or plain
boxes stretched to the plot; every label is HTML over it, so text never
scales. Colours are the series tokens, and each legend key is the drawn mark."""

glob PLOT_H: str = "h-44",
     SCOPE_COLOR: str = "var(--foreground)",
     DONE_COLOR: str = "var(--series-done)";

# A clean axis top at or above the peak: 1.2, 1.5, 2, 2.5 ... 10 times a power
# of ten (multipliers in tenths, integer math), whole and even so the midline
# tick is whole too. max() over a list is NaN on the client.
def niceTop(values: list[int]) -> int {
    peak = 0;
    for v in values {
        if v > peak {
            peak = v;
        }
    }
    if peak <= 2 {
        return 2;
    }
    step = 1;
    while step * 10 <= peak {
        step = step * 10;
    }
    for m in [12, 15, 20, 25, 30, 40, 50, 60, 80, 100] {
        top = m * step // 10;
        if (m * step) % 10 == 0 and top >= peak and top % 2 == 0 {
            return top;
        }
    }
    return 10 * step;
}

# Percent across the plot for week `i` of `n`: the middle of its column.
def colX(i: int, n: int) -> float {
    return (i + 0.5) * 100.0 / n;
}

# Percent down the plot for a value on an axis topped at `top`.
def valY(v: int, top: int) -> float {
    return 100.0 - v * 100.0 / top;
}

def linePath(values: list[int], top: int) -> str {
    n = len(values);
    parts: list[str] = [];
    for (i, v) in enumerate(values) {
        parts.append(
            ("M" if i == 0 else "L") + str(colX(i, n)) + " " + str(valY(v, top))
        );
    }
    return " ".join(parts);
}

# Every how many weeks a label prints: all up to 8 weeks, then every 2nd or
# 4th, counted back from the newest so the current week is always labelled.
def labelStep(n: int) -> int {
    return 1 if n <= 8 else (2 if n <= 16 else 4);
}

# Tooltip placement beside the hovered week, never over it: the left half
# opens to the right of the crosshair, the right half to its left.
def tipShift(i: int, n: int) -> str {
    return "translateX(14px)" if i * 2 < n else "translateX(calc(-100% - 14px))";
}

def YAxis(top: int, plotH: str = PLOT_H) -> JsxElement {
    return
        <div
            className={"relative w-7 shrink-0 text-right font-mono text-xs tabular-nums text-subtle "
                + plotH}
            aria-hidden="true"
        >
            <span className="absolute right-0 top-0 -translate-y-1/2">{str(top)}</span>
            <span className="absolute right-0 top-1/2 -translate-y-1/2">
                {str(top // 2)}
            </span>
            <span className="absolute right-0 bottom-0 translate-y-1/2">0</span>
        </div>;
}

def Gridlines -> JsxElement {
    return
        <div className="pointer-events-none absolute inset-0" aria-hidden="true">
            <div className="absolute inset-x-0 top-0 border-t border-border"/>
            <div className="absolute inset-x-0 top-1/2 border-t border-border"/>
            <div className="absolute inset-x-0 bottom-0 border-t border-border"/>
        </div>;
}

# Below `sm` only every other printed label shows; `invisible` keeps each
# column's width so the labels stay under their weeks.
def XLabels(labels: list[str], gutter: str) -> JsxElement {
    n = len(labels);
    step = labelStep(n);
    return
        <div
            className={"mt-2 flex font-mono text-xs text-subtle " + gutter}
            aria-hidden="true"
        >
            {for (i, lab) in enumerate(labels) {
                <div
                    key={str(i)}
                    className={"flex-1 text-center whitespace-nowrap "
                        + (
                            ""
                                if (n - 1 - i) % (step * 2) == 0
                                else "invisible sm:visible"
                        )}
                >
                    {lab if (n - 1 - i) % step == 0 else ""}
                </div>
            }}
        </div>;
}

# The legend key for a line series: the same 2px stroke the plot draws.
def LineKey(color: str) -> JsxElement {
    return
        <span
            className="inline-block h-0.5 w-3.5 shrink-0 rounded-full"
            style={{"background": color}}
            aria-hidden="true"
        />;
}

# The legend key for a bar series: a short bar with the plot's square foot.
def BarKey(color: str) -> JsxElement {
    return
        <span
            className="inline-block h-2.5 w-2 shrink-0 rounded-t-[2px]"
            style={{"background": color}}
            aria-hidden="true"
        />;
}

def:pub BurnUpChart(
    labels: list[str], scope: list[int], done: list[int]
) -> JsxElement {
    has hover: int = -1;

    n = len(scope);
    top = niceTop(scope);
    last = n - 1;
    scopeEnd = scope[last] if n > 0 else 0;
    doneEnd = done[last] if n > 0 else 0;
    # End labels ride their lines unless the two ends sit within ~16px of
    # each other on the 176px plot; then the legend and tooltip carry them.
    apart = (scopeEnd - doneEnd) * 176 >= top * 16;
    return
        <section className="surface min-w-0" aria-label="Burn-up">
            <div
                className="flex flex-wrap items-baseline gap-x-4 gap-y-1 px-3.5 pt-3 pb-2"
            >
                <h3 className="section-title text-[15px]">Burn-up</h3>
                <div
                    className="flex flex-wrap items-center gap-x-3.5 gap-y-1 text-xs text-muted-foreground"
                >
                    <span className="inline-flex items-center gap-1.5">
                        <LineKey color={SCOPE_COLOR}/>
                        Scope
                    </span>
                    <span className="inline-flex items-center gap-1.5">
                        <LineKey color={DONE_COLOR}/>
                        Done
                    </span>
                </div>
            </div>
            <div className="px-3.5 pt-2 pb-3.5">
                <div className="flex gap-2">
                    <YAxis top={top}/>
                    <div className={"relative mr-10 flex-1 " + PLOT_H}>
                        <Gridlines/>
                        <svg
                            className="absolute inset-0 h-full w-full overflow-visible"
                            viewBox="0 0 100 100"
                            preserveAspectRatio="none"
                            aria-hidden="true"
                        >
                            <path
                                d={linePath(scope, top)}
                                fill="none"
                                stroke={SCOPE_COLOR}
                                strokeWidth={2}
                                strokeLinejoin="round"
                                strokeLinecap="round"
                                vectorEffect="non-scaling-stroke"
                            />
                            <path
                                d={linePath(done, top)}
                                fill="none"
                                stroke={DONE_COLOR}
                                strokeWidth={2}
                                strokeLinejoin="round"
                                strokeLinecap="round"
                                vectorEffect="non-scaling-stroke"
                            />
                        </svg>
                        {if hover >= 0 and hover < n {
                            <div
                                key="cross"
                                className="pointer-events-none absolute inset-y-0 w-px bg-foreground/25"
                                style={{"left": str(colX(hover, n)) + "%"}}
                            />
                        }}
                        {for (i, v) in enumerate(scope) {
                            if i == last or i == hover {
                                <div
                                    key={"s" + str(i)}
                                    className="pointer-events-none absolute h-2 w-2 -translate-x-1/2 -translate-y-1/2 rounded-full"
                                    style={{
                                        "left": str(colX(i, n)) + "%",
                                        "top": str(valY(v, top)) + "%",
                                        "background": SCOPE_COLOR,
                                        "boxShadow": "0 0 0 2px var(--card)"
                                    }}
                                />
                            }
                        }}
                        {for (i, v) in enumerate(done) {
                            if i == last or i == hover {
                                <div
                                    key={"d" + str(i)}
                                    className="pointer-events-none absolute h-2 w-2 -translate-x-1/2 -translate-y-1/2 rounded-full"
                                    style={{
                                        "left": str(colX(i, n)) + "%",
                                        "top": str(valY(v, top)) + "%",
                                        "background": DONE_COLOR,
                                        "boxShadow": "0 0 0 2px var(--card)"
                                    }}
                                />
                            }
                        }}
                        {if n > 0 and apart {
                            <div key="ends" className="pointer-events-none">
                                <span
                                    className="absolute left-full ml-2.5 -translate-y-1/2 whitespace-nowrap font-mono text-xs font-medium tabular-nums text-foreground"
                                    style={{"top": str(valY(scopeEnd, top)) + "%"}}
                                >
                                    {str(scopeEnd)}
                                </span>
                                <span
                                    className="absolute left-full ml-2.5 -translate-y-1/2 whitespace-nowrap font-mono text-xs font-medium tabular-nums text-foreground"
                                    style={{"top": str(valY(doneEnd, top)) + "%"}}
                                >
                                    {str(doneEnd)}
                                </span>
                            </div>
                        }}
                        <div
                            className="absolute inset-0 flex"
                            onMouseLeave={lambda { hover = -1; }}
                        >
                            {for (i, lab) in enumerate(labels) {
                                <div
                                    key={str(i)}
                                    tabIndex={0}
                                    className="h-full flex-1 focus-visible:bg-muted/60 focus-visible:-outline-offset-2"
                                    aria-label={"Week of "
                                        + lab
                                        + ": scope "
                                        + str(scope[i])
                                        + ", done "
                                        + str(done[i])}
                                    onMouseEnter={lambda { hover = i; }}
                                    onFocus={lambda { hover = i; }}
                                    onBlur={lambda { hover = -1; }}
                                />
                            }}
                        </div>
                        {if hover >= 0 and hover < n {
                            <div
                                key="tip"
                                className="pointer-events-none absolute top-1 z-10 min-w-32 rounded-md border bg-popover px-2.5 py-2 text-xs whitespace-nowrap shadow-md"
                                style={{
                                    "left": str(colX(hover, n)) + "%",
                                    "transform": tipShift(hover, n)
                                }}
                            >
                                <div className="mb-1 text-muted-foreground">
                                    {"Week of " + labels[hover]}
                                </div>
                                <div className="flex items-center gap-2">
                                    <LineKey color={SCOPE_COLOR}/>
                                    <span className="num font-semibold">
                                        {str(scope[hover])}
                                    </span>
                                    <span className="text-muted-foreground">Scope</span>
                                </div>
                                <div className="flex items-center gap-2">
                                    <LineKey color={DONE_COLOR}/>
                                    <span className="num font-semibold">
                                        {str(done[hover])}
                                    </span>
                                    <span className="text-muted-foreground">Done</span>
                                </div>
                            </div>
                        }}
                    </div>
                </div>
                <XLabels labels={labels} gutter="ml-9 mr-10"/>
            </div>
        </section>;
}

def:pub ThroughputChart(
    labels: list[str], finished: list[int], added: list[int]
) -> JsxElement {
    has hover: int = -1;

    n = len(finished);
    top = niceTop(finished);
    last = n - 1;
    return
        <section className="surface min-w-0" aria-label="Throughput">
            <div
                className="flex flex-wrap items-baseline gap-x-4 gap-y-1 px-3.5 pt-3 pb-2"
            >
                <h3 className="section-title text-[15px]">Throughput</h3>
                <div
                    className="flex flex-wrap items-center gap-x-3.5 gap-y-1 text-xs text-muted-foreground"
                >
                    <span className="inline-flex items-center gap-1.5">
                        <BarKey color={DONE_COLOR}/>
                        Moved to Done
                    </span>
                </div>
            </div>
            <div className="px-3.5 pt-2 pb-3.5">
                <div className="flex gap-2">
                    <YAxis top={top}/>
                    <div className={"relative flex-1 " + PLOT_H}>
                        <Gridlines/>
                        <div
                            className="absolute inset-0 flex"
                            onMouseLeave={lambda { hover = -1; }}
                        >
                            {for (i, v) in enumerate(finished) {
                                <div
                                    key={str(i)}
                                    tabIndex={0}
                                    className={"relative flex h-full flex-1 items-end justify-center focus-visible:-outline-offset-2 "
                                        + ("bg-muted/60" if i == hover else "")}
                                    aria-label={"Week of "
                                        + labels[i]
                                        + ": "
                                        + str(v)
                                        + " done, "
                                        + str(added[i])
                                        + " added"}
                                    onMouseEnter={lambda { hover = i; }}
                                    onFocus={lambda { hover = i; }}
                                    onBlur={lambda { hover = -1; }}
                                >
                                    {if i == last and v > 0 {
                                        <span
                                            key="cap"
                                            className="pointer-events-none absolute -translate-y-1 font-mono text-xs font-medium tabular-nums text-foreground"
                                            style={{
                                                "bottom": str(v * 100.0 / top) + "%"
                                            }}
                                        >
                                            {str(v)}
                                        </span>
                                    }}
                                    <div
                                        className="w-3/5 max-w-6 rounded-t-[2px]"
                                        style={{
                                            "height": str(v * 100.0 / top) + "%",
                                            "background": DONE_COLOR,
                                            "opacity": "1"
                                                if hover < 0 or hover == i
                                                else "0.55"
                                        }}
                                    />
                                </div>
                            }}
                        </div>
                        {if hover >= 0 and hover < n {
                            <div
                                key="tip"
                                className="pointer-events-none absolute top-1 z-10 min-w-32 rounded-md border bg-popover px-2.5 py-2 text-xs whitespace-nowrap shadow-md"
                                style={{
                                    "left": str(colX(hover, n)) + "%",
                                    "transform": tipShift(hover, n)
                                }}
                            >
                                <div className="mb-1 text-muted-foreground">
                                    {"Week of " + labels[hover]}
                                </div>
                                <div className="flex items-center gap-2">
                                    <BarKey color={DONE_COLOR}/>
                                    <span className="num font-semibold">
                                        {str(finished[hover])}
                                    </span>
                                    <span className="text-muted-foreground">
                                        moved to Done
                                    </span>
                                </div>
                                <div className="flex items-center gap-2 pl-3.5">
                                    <span className="num font-semibold">
                                        {str(added[hover])}
                                    </span>
                                    <span className="text-muted-foreground">added</span>
                                </div>
                            </div>
                        }}
                    </div>
                </div>
                <XLabels labels={labels} gutter="ml-9"/>
            </div>
        </section>;
}

# This week's moves to Done, one column per day. `days` rows are dicts:
# label, value, future (outlined, never drawn as zero) and today (the label
# turns primary and reads "Today").
def:pub DayChart(days: list[dict]) -> JsxElement {
    values: list[int] = [];
    spoken: list[str] = [];
    for d in days {
        if not d["future"] {
            values.append(d["value"]);
            spoken.append(d["name"] + " " + str(d["value"]));
        }
    }
    top = niceTop(values);
    return
        <div
            role="img"
            aria-label={"Tasks moved to Done: " + ", ".join(spoken) + " so far"}
        >
            <div className="flex gap-2 pt-4">
                <YAxis top={top} plotH="h-24"/>
                <div className="relative h-24 flex-1">
                    <Gridlines/>
                    <div
                        className="absolute inset-0 flex gap-2 px-1"
                        aria-hidden="true"
                    >
                        {for d in days {
                            <div
                                key={d["name"]}
                                className="relative flex h-full flex-1 items-end justify-center"
                            >
                                {if d["future"] {
                                    <div
                                        key="ahead"
                                        className="h-[15px] w-full max-w-9 rounded-[2px] border border-dashed border-input"
                                    />
                                } else {
                                    <div
                                        key="bar"
                                        className="w-full max-w-9 rounded-t-[2px] bg-series-done"
                                        style={{
                                            "height": str(d["value"] * 100.0 / top)
                                                + "%"
                                        }}
                                    />
                                } }
                                {if not d["future"] {
                                    <span
                                        key="val"
                                        className={"absolute mb-0.5 font-mono text-xs tabular-nums "
                                            + (
                                                "text-foreground"
                                                    if d["value"] > 0
                                                    else "text-subtle"
                                            )}
                                        style={{
                                            "bottom": str(d["value"] * 100.0 / top)
                                                + "%"
                                        }}
                                    >
                                        {str(d["value"])}
                                    </span>
                                }}
                            </div>
                        }}
                    </div>
                </div>
            </div>
            <div className="mt-1.5 ml-9 flex gap-2 px-1 text-xs" aria-hidden="true">
                {for d in days {
                    <span
                        key={d["name"]}
                        className={"flex-1 text-center whitespace-nowrap "
                            + (
                                "font-semibold text-primary"
                                    if d["today"]
                                    else "font-mono text-subtle"
                            )}
                    >
                        {"Today" if d["today"] else d["label"]}
                    </span>
                }}
            </div>
        </div>;
}
