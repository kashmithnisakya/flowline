"""The standup, written from the log: Yesterday / Today / Blockers for the
selected day, grouped by person, with a one-click copy as Markdown. Derived
locally from the loaded week, no walker call, so it can never fail. It is a
summary: the table below it is the record.
"""

import from ...models { LogEntry }
import from ..ui.card { Card, CardContent }
import from ..ui.button { Button }
import from "sonner" { toast }

# A person's list is a summary, not the table: past MAX_ITEMS the rest is
# one "+n more" line, and bulk imports (which arrive fifty at a time) fold
# into one line per source repo instead of one per issue.
glob MAX_ITEMS: int = 6,
     IMPORT_PREFIX: str = "Imported from GitHub ",
     DAY_NAMES: list[str] = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
     MONTHS: list[str] = [
         "Jan",
         "Feb",
         "Mar",
         "Apr",
         "May",
         "Jun",
         "Jul",
         "Aug",
         "Sep",
         "Oct",
         "Nov",
         "Dec"
     ];

def prevDay(iso: str) -> str {
    d = new(Date, iso + "T00:00:00");
    d.setDate(d.getDate() - 1);
    shifted = new(Date, d.getTime() - d.getTimezoneOffset() * 60000);
    return shifted.toISOString()[:10];
}

# "2026-08-11" -> "Tue, Aug 11"
def longDay(iso: str) -> str {
    d = new(Date, iso + "T00:00:00");
    return DAY_NAMES[int(d.getDay())] + ", " + MONTHS[int(d.getMonth())] + " " + str(
        int(d.getDate())
    );
}

# member_name is every assignee comma-joined; an empty one is "Unassigned".
def people(e: LogEntry) -> list[str] {
    names = [
        n
        for n in e.member_name.split(", ")
        if n
    ];
    return names if len(names) > 0 else ["Unassigned"];
}

# One group per person (order of appearance), one line per task inside it.
# A task that moved twice in a day keeps only its latest line, so "Added
# to Backlog" then "Moved to Blocked" reads as the one thing that matters.
def grouped(entries: list[LogEntry]) -> list[dict[str, any]] {
    order: list[str] = [];
    perWho: dict[str, dict[str, LogEntry]] = {};
    taskOrder: dict[str, list[str]] = {};
    for e in entries {
        tkey = e.task_id or ("~" + e.activity);
        for who in people(e) {
            if who not in perWho {
                order.append(who);
                perWho[who] = {};
                taskOrder[who] = [];
            }
            if tkey not in perWho[who] {
                taskOrder[who].append(tkey);
                perWho[who][tkey] = e;
            } elif (e.date + e.at) >= (perWho[who][tkey].date + perWho[who][tkey].at) {
                perWho[who][tkey] = e;
            }
        }
    }
    out: list[dict[str, any]] = [];
    for who in order {
        items: list[dict[str, any]] = [];
        # Imports fold per repo: "Imported from GitHub owner/repo #12" ->
        # counted under owner/repo.
        importCounts: dict[str, int] = {};
        importRepos: list[str] = [];
        for tkey in taskOrder[who] {
            e = perWho[who][tkey];
            if e.activity.startswith(IMPORT_PREFIX) {
                repo = e.activity[len(IMPORT_PREFIX):].split(" #")[0];
                if repo not in importCounts {
                    importCounts[repo] = 0;
                    importRepos.append(repo);
                }
                importCounts[repo] = importCounts[repo] + 1;
                continue;
            }
            items.append(
                {
                    "what": (e.task_title or e.activity) + (
                        (" (" + e.activity + ")") if e.task_title else ""
                    ),
                    "blocked": e.status == "Blocked"
                }
            );
        }
        for repo in importRepos {
            n = importCounts[repo];
            items.append(
                {
                    "what": "Imported " + str(n) + (
                        " issue" if n == 1 else " issues"
                    ) + " from " + repo,
                    "blocked": False
                }
            );
        }
        hidden = len(items) - MAX_ITEMS;
        if hidden > 0 {
            items = items[:MAX_ITEMS] + [
                {
                    "what": "+" + str(hidden) + " more in the table below",
                    "blocked": False,
                    "more": True
                }
            ];
        }
        out.append({"who": who, "items": items});
    }
    return out;
}

# The latest entry per task up to `day` decides whether the task is still
# blocked; an earlier "Moved to Blocked" that was since moved on is not.
def blockers(entries: list[LogEntry], day: str) -> list[LogEntry] {
    latest: dict[str, LogEntry] = {};
    order: list[str] = [];
    for e in entries {
        if e.date > day or not e.task_id {
            continue;
        }
        if e.task_id not in latest {
            order.append(e.task_id);
            latest[e.task_id] = e;
        } else {
            prev = latest[e.task_id];
            if (e.date + e.at) >= (prev.date + prev.at) {
                latest[e.task_id] = e;
            }
        }
    }
    return [
        latest[tid]
        for tid in order
        if latest[tid].status == "Blocked"
    ];
}

def markdown(
    day: str,
    yest: list[dict[str, any]],
    today: list[dict[str, any]],
    blocked: list[dict[str, any]]
) -> str {
    def block(title: str, groups: list[dict[str, any]]) -> str {
        if len(groups) == 0 {
            return "**" + title + "**\n- Nothing logged\n";
        }
        out = "**" + title + "**\n";
        for g in groups {
            out = out + "- " + g["who"] + "\n";
            for it in g["items"] {
                # The "+n more" line points at the table on the page; in the
                # pasted text it is just a count.
                out = out + "  - " + (
                    it["what"].split(" in the table")[0] if it["more"] else it["what"]
                ) + "\n";
            }
        }
        return out;
    }
    return "**Standup · " + longDay(day) + "**\n\n" + block("Yesterday", yest) + "\n" + block(
        "Today", today
    ) + "\n" + block("Blockers", blocked);
}

# Typed accessor: the checker cannot see through dict[str, any] values.
def itemsOf(g: dict[str, any]) -> list[dict[str, any]] {
    return g["items"];
}


def DigestColumn(title: str, sub: str, rows: list[dict[str, any]]) -> JsxElement {
    return
        <div className="min-w-0">
            <div
                className="mb-1.5 flex items-baseline gap-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground"
            >
                {title}
                <span className="font-normal normal-case tracking-normal">{sub}</span>
            </div>
            {if len(rows) == 0 {
                <div key="none" className="text-sm text-muted-foreground/70">
                    {"None" if title == "Blockers" else "Nothing logged"}
                </div>
            } else {
                <ul key="rows" className="space-y-2 text-sm">
                    {for (i, g) in enumerate(rows) {
                        <li key={str(i)} className="min-w-0">
                            <div className="font-medium">{g["who"]}</div>
                            <ul
                                className="mt-0.5 space-y-0.5 border-l border-border pl-2.5"
                            >
                                {for (j, it) in enumerate(itemsOf(g)) {
                                    <li
                                        key={str(j)}
                                        className={"truncate " + (
                                            "text-destructive"
                                                if it["blocked"]
                                                else (
                                                    "italic text-muted-foreground/70"
                                                        if it["more"]
                                                        else "text-muted-foreground"
                                                )
                                        )}
                                        title={it["what"]}
                                    >
                                        {it["what"]}
                                    </li>
                                }}
                            </ul>
                        </li>
                    }}
                </ul>
            } }
        </div>;
}


def:pub Digest(entries: list[LogEntry], day: str) -> JsxElement {
    yesterday = prevDay(day);
    yRows = grouped(
        [
            e
            for e in entries
            if e.date == yesterday
        ]
    );
    tRows = grouped(
        [
            e
            for e in entries
            if e.date == day
        ]
    );
    bRows = grouped(blockers(entries, day));
    if len(yRows) == 0 and len(tRows) == 0 and len(bRows) == 0 {
        return <span/>;
    }
    def copy {
        nav: any = navigator;
        nav.clipboard.writeText(markdown(day, yRows, tRows, bRows));
        toast.success("Standup copied as Markdown");
    }
    return
        <Card className="anim-fade-in gap-0 py-0">
            <CardContent className="p-4 sm:p-5">
                <div className="mb-3 flex items-center justify-between gap-3">
                    <div>
                        <div className="font-display text-base font-semibold">
                            Standup for {longDay(day)}
                        </div>
                        <div className="text-xs text-muted-foreground">
                            Written from the log. Paste it wherever the team reads.
                        </div>
                    </div>
                    <Button variant="outline" size="sm" onClick={copy}>
                        <svg
                            width={14}
                            height={14}
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth={2}
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            aria-hidden="true"
                        >
                            <rect width={14} height={14} x={8} y={8} rx={2} ry={2}/>
                            <path
                                d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"
                            />
                        </svg>
                        Copy as Markdown
                    </Button>
                </div>
                <div className="grid gap-4 sm:grid-cols-3">
                    <DigestColumn
                        title="Yesterday"
                        sub={longDay(yesterday)}
                        rows={yRows}
                    />
                    <DigestColumn title="Today" sub={longDay(day)} rows={tRows}/>
                    <DigestColumn title="Blockers" sub="still blocked" rows={bRows}/>
                </div>
            </CardContent>
        </Card>;
}
