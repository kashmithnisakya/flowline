"""One project's row on the Overview (id, name, done, open, alarm, total):
its name, one stacked bar in the series colours and "done of total", plus
the legend whose keys match the bar's parts."""

glob PARTS: list[list[str]] = [
         ["done", "var(--series-done)", "Done"],
         ["open", "var(--series-open)", "Open"],
         ["alarm", "var(--series-blocked)", "Overdue or blocked"]
     ];

def share(part: int, whole: int) -> str {
    return str(part * 100.0 / whole) + "%" if whole > 0 else "0%";
}

def:pub ProjectRow(row: dict[str, any]) -> JsxElement {
    return
        <li className="col-span-3 grid grid-cols-subgrid items-center text-sm">
            <span className="truncate" title={row["name"]}>{row["name"]}</span>
            <span
                className="flex h-2 gap-0.5 overflow-hidden rounded-full bg-muted"
                role="img"
                aria-label={row["name"]
                    + ": "
                    + str(row["done"])
                    + " done, "
                    + str(row["open"])
                    + " open, "
                    + str(row["alarm"])
                    + " overdue or blocked"}
            >
                {for p in PARTS {
                    if row[p[0]] > 0 {
                        <span
                            key={p[0]}
                            className="block h-full"
                            style={{
                                "width": share(row[p[0]], row["total"]),
                                "background": p[1]
                            }}
                        />
                    }
                }}
            </span>
            <span className="num min-w-12 text-right text-xs text-muted-foreground">
                {(str(row["done"]) + " of " + str(row["total"]))
                    if row["total"] > 0
                    else "no tasks"}
            </span>
        </li>;
}

def:pub ProjectLegend -> JsxElement {
    return
        <div
            className="mt-4 flex flex-wrap gap-x-3.5 gap-y-1 text-xs text-muted-foreground"
        >
            {for p in PARTS {
                <span key={p[0]} className="inline-flex items-center gap-1.5">
                    <span
                        className="inline-block size-2 rounded-full"
                        style={{"background": p[1]}}
                        aria-hidden="true"
                    />
                    {p[2]}
                </span>
            }}
        </div>;
}
