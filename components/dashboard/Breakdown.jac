"""Projects and People on the Overview, as aligned rows. Project rows (id,
name, done, open, alarm, total) draw one stacked bar with matching legend
keys; people rows (id, name, color, open, done, byDay, total) draw a Monday
to Sunday strip. Either list empty shows a line linking to Workspace."""

import from "@jac/runtime" { Link }
import from ..common.Avatar { Avatar }

# Share of a total as a CSS width.
def share(part: int, whole: int) -> str {
    if whole == 0 {
        return "0%";
    }
    return str(part * 100.0 / whole) + "%";
}

def EmptyLine(text: str, action: str, to: str) -> JsxElement {
    return
        <p className="px-3.5 pt-1 pb-3 text-[13.5px] text-muted-foreground">
            {text + " "}
            <Link
                to={to}
                className="text-primary underline underline-offset-[3px] hover:decoration-2"
            >
                {action}
            </Link>
        </p>;
}

def Key(color: str, label: str) -> JsxElement {
    return
        <span className="inline-flex items-center gap-1.5">
            <span
                className="inline-block h-2 w-2.5 rounded-[2px]"
                style={{"background": color}}
                aria-hidden="true"
            />
            {label}
        </span>;
}

def:pub ProjectBars(rows: list[dict]) -> JsxElement {
    return
        <section className="surface min-w-0" aria-labelledby="projects-h">
            <div className="px-3.5 pt-3 pb-1">
                <h2 id="projects-h" className="section-title text-[15px]">Projects</h2>
            </div>
            {if len(rows) == 0 {
                <EmptyLine
                    key="empty"
                    text="No active projects."
                    action="Add a project"
                    to="/workspace?tab=projects"
                />
            }}
            <ul
                className="grid grid-cols-[minmax(0,7.5rem)_minmax(0,1fr)_auto] gap-x-2.5 px-3.5 pb-2"
                hidden={len(rows) == 0}
            >
                {for (i, r) in enumerate(rows) {
                    <li
                        key={r["id"]}
                        className={"col-span-3 grid grid-cols-subgrid items-center py-1.5 text-[13px] "
                            + ("border-t" if i > 0 else "")}
                    >
                        <span className="truncate" title={r["name"]}>{r["name"]}</span>
                        <span
                            className="flex h-2 gap-0.5 overflow-hidden rounded-[2px] bg-muted"
                            role="img"
                            aria-label={r["name"]
                                + ": "
                                + str(r["done"])
                                + " done, "
                                + str(r["open"])
                                + " open, "
                                + str(r["alarm"])
                                + " overdue or blocked"}
                        >
                            {if r["done"] > 0 {
                                <span
                                    key="d"
                                    className="block h-full"
                                    style={{
                                        "width": share(r["done"], r["total"]),
                                        "background": "var(--series-done)"
                                    }}
                                />
                            }}
                            {if r["open"] > 0 {
                                <span
                                    key="o"
                                    className="block h-full"
                                    style={{
                                        "width": share(r["open"], r["total"]),
                                        "background": "var(--series-open)"
                                    }}
                                />
                            }}
                            {if r["alarm"] > 0 {
                                <span
                                    key="x"
                                    className="block h-full"
                                    style={{
                                        "width": share(r["alarm"], r["total"]),
                                        "background": "var(--series-blocked)"
                                    }}
                                />
                            }}
                        </span>
                        <span className="num min-w-12 text-right text-xs text-subtle">
                            {(str(r["done"]) + " of " + str(r["total"]))
                                if r["total"] > 0
                                else "no tasks"}
                        </span>
                    </li>
                }}
            </ul>
            <div
                className="flex flex-wrap gap-x-3.5 gap-y-1 px-3.5 pb-3 text-xs text-muted-foreground"
                hidden={len(rows) == 0}
            >
                <Key color="var(--series-done)" label="Done"/>
                <Key color="var(--series-open)" label="Open"/>
                <Key color="var(--series-blocked)" label="Overdue or blocked"/>
            </div>
        </section>;
}

# A day cell's fill by entry count: none, one, two or three, four and up. A
# past day with none is an empty cell with a solid edge; days ahead are dashed.
def dayFill(count: int) -> str {
    if count <= 0 {
        return "transparent";
    }
    if count == 1 {
        return "color-mix(in oklab, var(--foreground) 30%, var(--card))";
    }
    if count <= 3 {
        return "color-mix(in oklab, var(--foreground) 55%, var(--card))";
    }
    return "color-mix(in oklab, var(--foreground) 80%, var(--card))";
}

def:pub PeopleTable(
    rows: list[dict], dayNames: list[str], todayIndex: int
) -> JsxElement {
    # Columns follow the panel's own width: beside a docked Ask it is too
    # narrow for five, so the counts fold under the name as on a phone. Each
    # row is its own grid, so wide columns are fixed to line up with the header.
    cols = "grid grid-cols-[minmax(0,1fr)_auto] items-center gap-3 @min-[36rem]:grid-cols-[minmax(0,1fr)_3rem_6rem_7.75rem_4rem]";
    return
        <section className="@container surface min-w-0" aria-labelledby="people-h">
            <div className="px-3.5 pt-3 pb-1">
                <h2 id="people-h" className="section-title text-[15px]">People</h2>
            </div>
            {if len(rows) == 0 {
                <EmptyLine
                    key="empty"
                    text="No active people."
                    action="Add a person"
                    to="/workspace?tab=people"
                />
            }}
            <div
                className="px-3.5 pb-2"
                role="table"
                aria-labelledby="people-h"
                hidden={len(rows) == 0}
            >
                <div
                    className={cols
                        + " py-1.5 text-xs text-muted-foreground @max-[36rem]:hidden"}
                    role="row"
                >
                    <span role="columnheader">Name</span>
                    <span role="columnheader" className="text-right">Open</span>
                    <span role="columnheader" className="text-right">
                        Done this week
                    </span>
                    <span role="columnheader">Logged, Mon to Sun</span>
                    <span role="columnheader" className="text-right">Entries</span>
                </div>
                {for r in rows {
                    <div
                        key={r["id"]}
                        className={cols + " border-t py-1.5 text-[13.5px]"}
                        role="row"
                    >
                        <span className="flex min-w-0 items-center gap-2.5" role="cell">
                            <Avatar name={r["name"]} color={r["color"]}/>
                            <span className="min-w-0">
                                <span className="block truncate">{r["name"]}</span>
                                <span
                                    className="block truncate text-xs tabular-nums text-muted-foreground @min-[36rem]:hidden"
                                >
                                    {str(r["open"])
                                        + " open · "
                                        + str(r["done"])
                                        + " done · "
                                        + str(r["total"])
                                        + (" entry" if r["total"] == 1 else " entries")}
                                </span>
                            </span>
                        </span>
                        <span
                            className="num text-right @max-[36rem]:hidden"
                            role="cell"
                        >
                            {str(r["open"])}
                        </span>
                        <span
                            className="num text-right @max-[36rem]:hidden"
                            role="cell"
                        >
                            {str(r["done"])}
                        </span>
                        <span
                            className="inline-flex gap-[3px] @min-[36rem]:gap-1"
                            role="cell"
                            aria-label={"Logged on "
                                + str(
                                    len(
                                        [
                                            c
                                            for c in r["byDay"]
                                            if c > 0
                                        ]
                                    )
                                )
                                + " of "
                                + str(todayIndex + 1)
                                + " days so far"}
                        >
                            {for (di, name) in enumerate(dayNames) {
                                <span
                                    key={name}
                                    title={name
                                        + (
                                            ": ahead"
                                                if di > todayIndex
                                                else ": "
                                                    + str(r["byDay"][di])
                                                    + " entries"
                                        )}
                                    className={"size-3 rounded-[2px] @min-[36rem]:size-3.5 "
                                        + (
                                            "border border-dashed border-input"
                                                if di > todayIndex
                                                else (
                                                    "border border-input/70"
                                                        if r["byDay"][di] <= 0
                                                        else ""
                                                )
                                        )
                                        + (
                                            " outline outline-[1.5px] outline-offset-1 outline-primary"
                                                if di == todayIndex
                                                else ""
                                        )}
                                    style={{
                                        "background": "transparent"
                                            if di > todayIndex
                                            else dayFill(r["byDay"][di])
                                    }}
                                />
                            }}
                        </span>
                        <span
                            className="num text-right text-muted-foreground @max-[36rem]:hidden"
                            role="cell"
                        >
                            {str(r["total"])}
                        </span>
                    </div>
                }}
            </div>
        </section>;
}
