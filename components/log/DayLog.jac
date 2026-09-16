"""The selected day in words: a written standup grouped by what each entry
means (its status kind), and the day's timeline, newest first. Both derive
from the entries the page already loaded, so neither can fail on its own.
"""

import from "@jac/runtime" { Link }
import from ...models { LogEntry, TaskView }
import from ...constants { STATUS_KIND }
import from ...lib.dates { daysUntil }
import from ..common.KindGlyph { KindGlyph }
import from ..ui.button { Button }
import from ..ui.checkbox { Checkbox }
import from "sonner" { toast }

# Reading order: what needs someone first. Stuck and Handed off never fold,
# so a long list cannot bury them.
glob SECTIONS: list[str] = ["blocked", "handoff", "done", "active", "start"],
     SECTION_LABEL: dict[str, str] = {
         "done": "Finished",
         "handoff": "Handed off",
         "active": "In progress",
         "blocked": "Stuck",
         "start": "To do"
     },
     HEAD_TONE: dict[str, str] = {
         "done": "text-success",
         "handoff": "text-foreground",
         "active": "text-foreground",
         "blocked": "text-destructive",
         "start": "text-foreground"
     },
     GLYPH_TONE: dict[str, str] = {
         "done": "text-success",
         "handoff": "text-muted-foreground",
         "active": "text-muted-foreground",
         "blocked": "text-destructive",
         "start": "text-muted-foreground"
     },
     NEVER_FOLD: list[str] = ["handoff", "blocked"],
     FOLD_AT: int = 5,
     IMPORT_PREFIX: str = "Imported from GitHub ",
     DAY_LONG: list[str] = [
         "Sunday",
         "Monday",
         "Tuesday",
         "Wednesday",
         "Thursday",
         "Friday",
         "Saturday"
     ],
     DAY_SHORT: list[str] = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
     MONTH_LONG: list[str] = [
         "January",
         "February",
         "March",
         "April",
         "May",
         "June",
         "July",
         "August",
         "September",
         "October",
         "November",
         "December"
     ],
     # Past forms a manual note often opens with that do not end in -ed.
     PAST_IRREGULAR: list[str] = [
         "wrote",
         "met",
         "ran",
         "sent",
         "built",
         "made",
         "did",
         "had",
         "took",
         "spoke",
         "gave",
         "went",
         "got",
         "set",
         "put",
         "read",
         "led",
         "began",
         "drew",
         "found",
         "kept",
         "left",
         "paid",
         "told",
         "thought",
         "brought",
         "caught",
         "taught",
         "won",
         "saw",
         "chose",
         "broke",
         "held",
         "heard",
         "spent",
         "split",
         "cut",
         "shut",
         "hit",
         "fed"
     ];

# "2026-09-15" -> "Tuesday 15 September"
def longDate(iso: str) -> str {
    d = new(Date, iso + "T00:00:00");
    return DAY_LONG[int(d.getDay())]
        + " "
        + str(int(d.getDate()))
        + " "
        + MONTH_LONG[int(d.getMonth())];
}

# "2026-09-11" -> "Fri 11 Sep"
def shortDate(iso: str) -> str {
    d = new(Date, iso + "T00:00:00");
    return DAY_SHORT[int(d.getDay())]
        + " "
        + str(int(d.getDate()))
        + " "
        + MONTH_LONG[int(d.getMonth())][:3];
}

# A UTC stamp as the viewer's wall clock, "16:20".
def clock(at: str) -> str {
    if len(at) < 16 {
        return "";
    }
    d = new(Date, at[:19] + "Z");
    t = d.getTime();
    if t != t {
        return at[11:16];
    }
    hh = str(int(d.getHours()));
    mm = str(int(d.getMinutes()));
    return ("0" + hh if len(hh) < 2 else hh) + ":" + ("0" + mm if len(mm) < 2 else mm);
}

# member_name is every assignee comma-joined.
def people(e: LogEntry) -> list[str] {
    return [
        n
        for n in e.member_name.split(", ")
        if n
    ];
}

# First names read like a standup; a first name two people share stays full.
def shortName(full: str, roster: list[str]) -> str {
    first = full.split(" ")[0];
    same = 0;
    for n in roster {
        if n.split(" ")[0] == first {
            same = same + 1;
        }
    }
    return full if same > 1 else first;
}

def joinNames(names: list[str]) -> str {
    if len(names) == 0 {
        return "";
    }
    if len(names) == 1 {
        return names[0];
    }
    return ", ".join(names[:len(names) - 1]) + " and " + names[len(names) - 1];
}

def namesOf(full: list[str], roster: list[str]) -> str {
    return joinNames([shortName(n, roster) for n in full]);
}

def lowerFirst(s: str) -> str {
    if len(s) == 0 {
        return s;
    }
    if len(s) > 1 and s[1] != s[1].lower() {
        return s;
    }
    return s[0].lower() + s[1:];
}

def endStop(s: str) -> str {
    t = s.strip();
    if len(t) == 0 {
        return t;
    }
    return t if t[len(t) - 1] in ".!?" else t + ".";
}

def pastTense(word: str) -> bool {
    w = word.lower();
    if w in PAST_IRREGULAR {
        return True;
    }
    return len(w) > 3 and w.endswith("ed") and not w.endswith("eed");
}

def kindOf(status: str) -> str {
    return STATUS_KIND[status] if status in STATUS_KIND else "active";
}

def overdueText(days: int) -> str {
    return ("1 day" if days == 1 else str(days) + " days") + " overdue.";
}

# One entry as words around its task title: {lead, title, tail}. `who` is the
# subject ("" writes the timeline's verb-first form); `prose` adds the stop.
# A hand-off names the new owner, since member_name is already theirs.
def phrase(e: LogEntry, who: str, roster: list[str], prose: bool) -> dict[str, str] {
    act = e.activity.strip();
    title = e.task_title;
    stop = "." if prose else "";
    if not title {
        text = endStop(act) if prose else act;
        if not who {
            return {"lead": text, "title": "", "tail": ""};
        }
        if pastTense(act.split(" ")[0]) {
            return {"lead": who + " " + lowerFirst(text), "title": "", "tail": ""};
        }
        return {"lead": who + ": " + text, "title": "", "tail": ""};
    }
    if act.startswith("Added to ") {
        return {
            "lead": (who + " added " if who else "Added "),
            "title": title,
            "tail": " to " + act[9:] + stop
        };
    }
    if act.startswith("Moved to ") {
        bits = act[9:].split(" · ");
        mates = people(e);
        handed = "";
        others = "";
        for b in bits[1:] {
            if b in mates {
                handed = b;
            } else {
                others = others + ", " + lowerFirst(b);
            }
        }
        if handed and who {
            return {
                "lead": "",
                "title": title,
                "tail": " moved to "
                    + bits[0]
                    + ", now with "
                    + shortName(handed, roster)
                    + others
                    + stop
            };
        }
        if handed {
            return {
                "lead": "Moved ",
                "title": title,
                "tail": " to "
                    + bits[0]
                    + ", now with "
                    + shortName(handed, roster)
                    + others
                    + stop
            };
        }
        return {
            "lead": (who + " moved " if who else "Moved "),
            "title": title,
            "tail": " to " + bits[0] + others + stop
        };
    }
    if act.startswith("Checked off: ") {
        rest = act[13:];
        parts = rest.split(" (");
        item = rest;
        count = "";
        if len(parts) > 1 {
            item = " (".join(parts[:len(parts) - 1]);
            count = " ("
                + parts[len(parts) - 1].replace(")", "").replace("/", " of ")
                + ")";
        }
        return {
            "lead": (who + " checked off " if who else "Checked off ") + item + " on ",
            "title": title,
            "tail": count + stop
        };
    }
    # The timeline links the issue number itself, so its sentence drops it.
    if act.startswith(IMPORT_PREFIX) {
        source = act[len(IMPORT_PREFIX):];
        return {
            "lead": (who + " imported " if who else "Imported "),
            "title": title,
            "tail": " from "
                + (source.split(" #")[0] if e.issue_link and not prose else source)
                + stop
        };
    }
    if act.startswith("Opened GitHub issue ") {
        source = act[20:];
        return {
            "lead": (who + " opened " if who else "Opened ")
                + (
                    "an issue in " + source.split(" #")[0]
                        if e.issue_link and not prose
                        else source
                )
                + " for ",
            "title": title,
            "tail": stop
        };
    }
    return {
        "lead": (who + ": " if who else ""),
        "title": title,
        "tail": ", " + lowerFirst(act) + stop
    };
}

def lineOf(parts: dict[str, str], task: str, meta: str, at: str) -> dict[str, str] {
    return {
        "lead": parts["lead"],
        "title": parts["title"],
        "tail": parts["tail"],
        "task": task,
        "meta": meta,
        "at": at
    };
}

# The standup for `day`: each task's latest line since `since` in the section
# of its kind, imports folded per repo. Stuck is the live blocked list when
# `live`, else every task whose latest line since `loadedFrom` is Blocked.
def buildSections(
    entries: list[LogEntry],
    day: str,
    since: str,
    loadedFrom: str,
    today: str,
    blocked: list[TaskView],
    live: bool,
    roster: list[str]
) -> dict[str, list[dict[str, str]]] {
    out: dict[str, list[dict[str, str]]] = {
        "done": [],
        "handoff": [],
        "active": [],
        "blocked": [],
        "start": []
    };
    latest: dict[str, LogEntry] = {};
    order: list[str] = [];
    lastSeen: dict[str, LogEntry] = {};
    seenOrder: list[str] = [];
    for e in entries {
        if e.date > day or e.date < loadedFrom {
            continue;
        }
        stamp = e.date + e.at;
        if e.task_id {
            if e.task_id not in lastSeen {
                seenOrder.append(e.task_id);
                lastSeen[e.task_id] = e;
            } elif stamp >= (lastSeen[e.task_id].date + lastSeen[e.task_id].at) {
                lastSeen[e.task_id] = e;
            }
        }
        if e.date < since {
            continue;
        }
        # The same note on two days of the window reads once, at its latest.
        key = e.task_id or ("~" + e.member_name + "|" + e.activity.strip().lower());
        if key not in latest {
            order.append(key);
            latest[key] = e;
        } elif stamp >= (latest[key].date + latest[key].at) {
            latest[key] = e;
        }
    }
    liveIds: list[str] = [t.id for t in blocked] if live else [];
    importCount: dict[str, int] = {};
    importFirst: dict[str, LogEntry] = {};
    importAt: dict[str, str] = {};
    importRepos: list[str] = [];
    for key in order {
        e = latest[key];
        kind = kindOf(e.status);
        if e.task_id and (kind == "blocked" or e.task_id in liveIds) {
            continue;
        }
        if e.task_id and e.activity.startswith(IMPORT_PREFIX) {
            repo = e.activity[len(IMPORT_PREFIX):].split(" #")[0];
            if repo not in importCount {
                importRepos.append(repo);
                importCount[repo] = 0;
                importFirst[repo] = e;
                importAt[repo] = "";
            }
            importCount[repo] = importCount[repo] + 1;
            if (e.date + e.at) > importAt[repo] {
                importAt[repo] = e.date + e.at;
            }
            continue;
        }
        who = namesOf(people(e), roster);
        if kind == "blocked" {
            out["blocked"].append(
                lineOf(
                    {"lead": endStop(e.activity), "title": "", "tail": ""},
                    "",
                    " · ".join(
                        [
                            x
                            for x in [e.project_name, who]
                            if x
                        ]
                    ),
                    e.date + e.at
                )
            );
            continue;
        }
        out[kind].append(
            lineOf(
                phrase(e, who, roster, True), e.task_id, e.project_name, e.date + e.at
            )
        );
    }
    for repo in importRepos {
        n = importCount[repo];
        first = importFirst[repo];
        if n == 1 {
            out["start"].append(
                lineOf(
                    phrase(first, namesOf(people(first), roster), roster, True),
                    first.task_id,
                    first.project_name,
                    importAt[repo]
                )
            );
        } else {
            out["start"].append(
                lineOf(
                    {
                        "lead": "Imported " + str(n) + " issues from " + repo + ".",
                        "title": "",
                        "tail": ""
                    },
                    "",
                    first.project_name,
                    importAt[repo]
                )
            );
        }
    }
    if live {
        for t in blocked {
            seen = lastSeen[t.id] if t.id in lastSeen else None;
            tail = " is stuck.";
            if seen and kindOf(seen.status) == "blocked" and seen.notes {
                tail = tail + " " + endStop(seen.notes);
            }
            if len(t.due_date) >= 10 {
                late = daysUntil(t.due_date, today);
                if late < 0 {
                    tail = tail + " " + overdueText(-late);
                }
            }
            out["blocked"].append(
                lineOf(
                    {"lead": "", "title": t.title, "tail": tail},
                    t.id,
                    " · ".join(
                        [
                            x
                            for x in [
                                t.project_name,
                                namesOf(t.assignee_names, roster)
                            ]
                            if x
                        ]
                    ),
                    t.updated_at[:10] + t.updated_at
                )
            );
        }
    } else {
        for tid in seenOrder {
            e = lastSeen[tid];
            if kindOf(e.status) != "blocked" {
                continue;
            }
            tail = " is stuck." + (" " + endStop(e.notes) if e.notes else "");
            out["blocked"].append(
                lineOf(
                    {"lead": "", "title": e.task_title or e.activity, "tail": tail},
                    tid,
                    " · ".join(
                        [
                            x
                            for x in [e.project_name, namesOf(people(e), roster)]
                            if x
                        ]
                    ),
                    e.date + e.at
                )
            );
        }
    }
    for k in SECTIONS {
        out[k] = sorted(
            out[k], key=lambda (ln: dict[str, str]) { ln["at"]; }, reverse=True
        );
    }
    return out;
}

def sentenceOf(ln: dict[str, str]) -> str {
    return ln["lead"] + ln["title"] + ln["tail"];
}

def markdown(
    day: str,
    windowLabel: str,
    sections: dict[str, list[dict[str, str]]],
    stuckNote: str
) -> str {
    out = "**Standup · " + longDate(day) + "**\n";
    if windowLabel {
        out = out + "_" + windowLabel + "_\n";
    }
    for k in SECTIONS {
        rows = sections[k];
        if len(rows) == 0 {
            continue;
        }
        out = out
            + "\n**"
            + SECTION_LABEL[k]
            + "**"
            + (" (" + stuckNote + ")" if k == "blocked" and stuckNote else "")
            + "\n";
        for ln in rows {
            out = out
                + "- "
                + sentenceOf(ln)
                + (" (" + ln["meta"] + ")" if ln["meta"] else "")
                + "\n";
        }
    }
    return out;
}


def:pub Standup(
    entries: list[LogEntry],
    day: str,
    since: str,
    loadedFrom: str,
    today: str,
    blocked: list[TaskView] = [],
    liveBlocked: bool = False,
    roster: list[str] = [],
    windowLabel: str = ""
) -> JsxElement {
    has opened: list[str] = [];

    live = liveBlocked and day == today;
    sections = buildSections(
        entries, day, since, loadedFrom, today, blocked, live, roster
    );
    shown = [
        k
        for k in SECTIONS
        if len(sections[k]) > 0
    ];
    stuckNote = "" if live else "from the log since " + shortDate(loadedFrom);
    if len(shown) == 0 {
        return <span className="hidden"/>;
    }
    def copy {
        nav: any = navigator;
        nav.clipboard.writeText(markdown(day, windowLabel, sections, stuckNote));
        toast.success("Standup copied as Markdown");
    }
    return
        <section
            aria-label="Standup"
            className="grid max-w-[68ch] gap-3.5 [--kind-knockout:var(--background)]"
        >
            {for k in shown {
                <div key={k}>
                    <h3
                        className={"mb-1 flex flex-wrap items-center gap-x-[7px] text-[13.5px] font-semibold "
                            + HEAD_TONE[k]}
                    >
                        <KindGlyph kind={k} className={GLYPH_TONE[k]}/>
                        {SECTION_LABEL[k]}
                        {if k == "blocked" and stuckNote {
                            <span
                                key="note"
                                className="text-xs font-normal text-muted-foreground"
                            >
                                {stuckNote}
                            </span>
                        }}
                    </h3>
                    <ul
                        className="grid list-disc gap-1 pl-[21px] text-sm marker:text-subtle"
                    >
                        {for (i, ln) in enumerate(sections[k]) {
                            if i < FOLD_AT or k in NEVER_FOLD or k in opened {
                                <li key={k + str(i)} className="break-words">
                                    {ln["lead"]}
                                    {if ln["task"] and ln["title"] {
                                        <Link
                                            key="t"
                                            to={"/board?task=" + ln["task"]}
                                            className="decoration-border underline-offset-[3px] hover:underline"
                                        >
                                            {ln["title"]}
                                        </Link>
                                    } else {
                                        <span key="t">{ln["title"]}</span>
                                    } }
                                    {ln["tail"]}
                                    {if ln["meta"] {
                                        <span
                                            key="m"
                                            className="text-[12.5px] text-muted-foreground"
                                        >
                                            {" " + "\u00a0".join(ln["meta"].split(" "))}
                                        </span>
                                    }}
                                </li>
                            }
                        }}
                    </ul>
                    {if len(sections[k]) > FOLD_AT
                        and k not in NEVER_FOLD
                        and k not in opened {
                        <button
                            key="more"
                            type="button"
                            className="mt-1 ml-[21px] text-[13px] font-medium text-muted-foreground underline-offset-[3px] hover:text-foreground hover:underline"
                            onClick={lambda { opened = opened + [k]; }}
                        >
                            {"Show " + str(len(sections[k]) - FOLD_AT) + " more"}
                        </button>
                    }}
                </div>
            }}
            <div>
                <Button
                    variant="ghost"
                    size="sm"
                    className="-ml-2.5 text-muted-foreground"
                    onClick={copy}
                >
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
        </section>;
}

# "https://github.com/org/repo/pull/42" -> "42" ("" when it is not a number).
def refNumber(url: str) -> str {
    parts = [
        p
        for p in url.split("/")
        if p
    ];
    if len(parts) == 0 {
        return "";
    }
    tail = parts[len(parts) - 1];
    for ch in tail {
        if ch not in "0123456789" {
            return "";
        }
    }
    return tail;
}

# Timeline rows newest first; rows without a stamp go last in their day.
# Imports fold per repo per day unless rows are being picked. `sorted` with
# reverse flips ties, so the input is flipped first to keep wire order.
def timelineRows(
    entries: list[LogEntry], fold: bool, roster: list[str]
) -> list[dict[str, any]] {
    flipped = [entries[len(entries) - 1 - i] for i in range(len(entries))];
    ordered = sorted(
        flipped, key=lambda (e: LogEntry) { e.date + "|" + e.at; }, reverse=True
    );
    rows: list[dict[str, any]] = [];
    folded: dict[str, dict[str, any]] = {};
    for e in ordered {
        if fold and e.task_id and e.activity.startswith(IMPORT_PREFIX) {
            repo = e.activity[len(IMPORT_PREFIX):].split(" #")[0];
            fkey = e.date + "|" + repo;
            if fkey in folded {
                grown = folded[fkey];
                grown["count"] = grown["count"] + 1;
                grown["lead"] = "Imported "
                    + str(grown["count"])
                    + " issues from "
                    + repo;
                grown["title"] = "";
                grown["tail"] = "";
                grown["task"] = "";
                grown["issue"] = "";
                grown["entry"] = None;
                continue;
            }
            parts = phrase(e, "", roster, False);
            row = {
                "id": jid(e),
                "date": e.date,
                "time": clock(e.at),
                "kind": "start",
                "lead": parts["lead"],
                "title": parts["title"],
                "tail": parts["tail"],
                "task": e.task_id,
                "who": "GitHub",
                "notes": "",
                "issue": refNumber(e.issue_link) if e.issue_link else "",
                "pr": "",
                "count": 1,
                "entry": e
            };
            folded[fkey] = row;
            rows.append(row);
            continue;
        }
        parts = phrase(e, "", roster, False);
        rows.append(
            {
                "id": jid(e),
                "date": e.date,
                "time": clock(e.at),
                "kind": kindOf(e.status),
                "lead": parts["lead"],
                "title": parts["title"],
                "tail": parts["tail"],
                "task": e.task_id,
                "who": ", ".join([shortName(n, roster) for n in people(e)]),
                "notes": e.notes,
                "issue": refNumber(e.issue_link) if e.issue_link else "",
                "pr": refNumber(e.pr_link) if e.pr_link else "",
                "count": 1,
                "entry": e
            }
        );
    }
    return rows;
}

# Typed accessor: the checker cannot see through dict[str, any] values.
def entryOf(r: dict[str, any]) -> LogEntry {
    return r["entry"];
}

def glyphTone(kind: str) -> str {
    if kind == "done" {
        return "text-success";
    }
    if kind == "blocked" {
        return "text-destructive";
    }
    return "text-muted-foreground";
}


def:pub LogTimeline(
    entries: list[LogEntry],
    roster: list[str] = [],
    showDate: bool = False,
    selecting: bool = False,
    selected: list[str] = [],
    onToggleSelect: Callable[[str], None] = None,
    onEdit: Callable[[LogEntry], None] = None
) -> JsxElement {
    rows = timelineRows(entries, not selecting, roster);
    # A handler with its own `if`: inline in the row slot it compiles into a
    # push onto the rendered children.
    def pick(rowId: str) {
        if selecting and onToggleSelect {
            onToggleSelect(rowId);
        }
    }
    return
        <ul className="border-t [--kind-knockout:var(--background)]">
            {for r in rows {
                <li
                    key={r["id"]}
                    data-state={"selected" if selecting and r["id"] in selected else ""}
                    className={"group grid items-start gap-x-2.5 gap-y-0.5 border-b py-2 text-[13.5px] "
                        + (
                            "cursor-pointer grid-cols-[20px_48px_16px_minmax(0,1fr)] data-[state=selected]:bg-accent md:grid-cols-[20px_52px_18px_minmax(0,1fr)_auto]"
                                if selecting
                                else "grid-cols-[48px_16px_minmax(0,1fr)] md:grid-cols-[52px_18px_minmax(0,1fr)_auto]"
                        )}
                    onClick={lambda { pick(r["id"]); }}
                >
                    {if selecting {
                        <span key="pick" className="pt-0.5">
                            <Checkbox
                                aria-label="Select entry"
                                checked={r["id"] in selected}
                                onCheckedChange={lambda { pick(r["id"]); }}
                                onClick={lambda (e: MouseEvent) { e.stopPropagation(); }}
                            />
                        </span>
                    }}
                    <span
                        className="num pt-px text-[12.5px] leading-5 text-subtle group-data-[state=selected]:text-muted-foreground"
                    >
                        {if showDate {
                            <span key="d" className="block">
                                {shortDate(r["date"])[:6]}
                            </span>
                        }}
                        {r["time"]}
                    </span>
                    <span className={"pt-[3px] " + glyphTone(r["kind"])}>
                        <KindGlyph kind={r["kind"]}/>
                    </span>
                    <div className="min-w-0 leading-5 break-words">
                        {r["lead"]}
                        {if r["task"] and r["title"] and not selecting {
                            <Link
                                key="t"
                                to={"/board?task=" + r["task"]}
                                className="font-semibold decoration-border underline-offset-[3px] hover:underline"
                            >
                                {r["title"]}
                            </Link>
                        } else {
                            <span key="t" className="font-semibold">{r["title"]}</span>
                        } }
                        {r["tail"]}
                        {if r["issue"] {
                            <a
                                key="issue"
                                href={entryOf(r).issue_link}
                                target="_blank"
                                rel="noopener"
                                title="Issue"
                                className="num ml-1.5 text-xs text-muted-foreground hover:text-foreground hover:underline"
                            >
                                {"#" + r["issue"]}
                            </a>
                        }}
                        {if r["pr"] {
                            <a
                                key="pr"
                                href={entryOf(r).pr_link}
                                target="_blank"
                                rel="noopener"
                                title="Pull request"
                                className="num ml-1.5 text-xs text-muted-foreground hover:text-foreground hover:underline"
                            >
                                {"PR #" + r["pr"]}
                            </a>
                        }}
                        {if r["notes"] {
                            <p
                                key="n"
                                className="mt-0.5 text-[13px] text-muted-foreground"
                            >
                                {r["notes"]}
                            </p>
                        }}
                    </div>
                    <div
                        className={"flex min-h-5 items-center gap-1 md:col-start-auto md:justify-end "
                            + ("col-start-4" if selecting else "col-start-3")}
                    >
                        {if r["who"] {
                            <span
                                key="who"
                                className="text-xs whitespace-nowrap text-subtle group-data-[state=selected]:text-muted-foreground"
                            >
                                {r["who"]}
                            </span>
                        }}
                        {if not selecting and onEdit and r["entry"] {
                            <button
                                key="edit"
                                type="button"
                                aria-label="Edit entry"
                                title="Edit entry"
                                className="-my-1 inline-flex size-7 shrink-0 items-center justify-center rounded-md text-muted-foreground transition-opacity hover:bg-accent hover:text-foreground md:opacity-0 md:group-hover:opacity-100 md:group-focus-within:opacity-100"
                                onClick={lambda { onEdit(entryOf(r)); }}
                            >
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
                                    <path
                                        d="M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z"
                                    />
                                    <path d="m15 5 4 4"/>
                                </svg>
                            </button>
                        } elif not selecting and onEdit {
                            <span
                                key="edit"
                                className="-my-1 hidden size-7 shrink-0 md:block"
                                aria-hidden="true"
                            />
                        } }
                    </div>
                </li>
            }}
        </ul>;
}
