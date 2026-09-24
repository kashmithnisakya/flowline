"""A series' legend key (the same mark the plot draws, a 2px line or a short
bar) and the hover tooltip that sits beside the hovered week, never over it.
`colX` is the middle of week `i` of `n` in percent across the plot."""

def:pub colX(i: int, n: int) -> float {
    return (i + 0.5) * 100.0 / n;
}

def:pub SeriesKey(color: str, bar: bool = False) -> JsxElement {
    return
        <span
            className={"inline-block shrink-0 "
                + ("h-2.5 w-2 rounded-t-[2px]" if bar else "h-0.5 w-3.5 rounded-full")}
            style={{"background": color}}
            aria-hidden="true"
        />;
}

# `rows` are dicts: color (empty for no key), bar, value, label.
def:pub ChartTip(week: str, i: int, n: int, rows: list[dict[str, any]]) -> JsxElement {
    return
        <div
            className="pointer-events-none absolute top-1 z-10 min-w-32 rounded-lg border bg-popover px-2.5 py-2 text-xs whitespace-nowrap shadow-md"
            style={{
                "left": str(colX(i, n)) + "%",
                "transform": "translateX(14px)"
                    if i * 2 < n
                    else "translateX(calc(-100% - 14px))"
            }}
        >
            <div className="mb-1 text-muted-foreground">{"Week of " + week}</div>
            {for r in rows {
                <div
                    key={r["label"]}
                    className={"flex items-center gap-2 "
                        + ("" if r["color"] else "pl-5.5")}
                >
                    {if r["color"] {
                        <SeriesKey key="k" color={r["color"]} bar={r["bar"]}/>
                    }}
                    <span className="num font-semibold">{str(r["value"])}</span>
                    <span className="text-muted-foreground">{r["label"]}</span>
                </div>
            }}
        </div>;
}
