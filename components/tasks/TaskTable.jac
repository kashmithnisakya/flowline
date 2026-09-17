"""One page of tasks: a fixed-layout table once its container (the page's
`@container` surface) is 50rem wide, a two-line list below that. The page
places each row on its board column (`stepNames`, `stepColors`) and keeps the
J/K `cursor`; only the active sort header shows an arrow."""

import from ...models { TaskView }
import from ..common.Avatar { AvatarStack }
import from ..common.StepName { StepName }
import from ..common.KindGlyph { KindGlyph }
import from ..ui.skeleton { Skeleton }
import from ...lib.dates { todayIso, dueTone, daysUntil }

# Title widths for the placeholder rows, so they read as a list.
glob PH_WIDTHS: list[str] = ["w-3/5", "w-2/5", "w-1/2", "w-[70%]"];

glob MONTHS: list[str] = [
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
     ],
     WEEKDAYS: list[str] = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
     # [sort key or "" for a plain header, label, width class]. Task takes
     # what is left; the rest widen once the surface reaches 72rem.
     COLUMNS: list[list[str]] = [
         ["title", "Task", ""],
         ["step", "Step", "w-[9rem] @6xl:w-[10rem]"],
         ["", "People", "w-[6rem] @6xl:w-[8.5rem]"],
         ["due", "Due", "w-[7rem] @6xl:w-[7.5rem]"],
         ["priority", "Priority", "w-[5.5rem]"],
         ["", "GitHub", "w-[4.5rem] @6xl:w-[5rem]"],
         ["updated", "Updated", "w-[7.5rem] @6xl:w-[8rem]"]
     ];

# "2026-09-16" -> "Wed 16 Sep", with the year when it is not this one.
def:pub dayText(iso: str) -> str {
    if len(iso) < 10 {
        return iso;
    }
    d: any = new(Date, iso[:10] + "T00:00:00");
    text = WEEKDAYS[int(d.getDay())]
        + " "
        + str(int(iso[8:10]))
        + " "
        + MONTHS[int(iso[5:7]) - 1];
    if iso[:4] != todayIso()[:4] {
        text = text + " " + iso[:4];
    }
    return text;
}

def lateText(iso: str, today: str) -> str {
    late = 0 - daysUntil(iso, today);
    return str(late) + (" day overdue" if late == 1 else " days overdue");
}

# A server stamp (naive UTC ISO) as a relative age: "just now", "3 hours ago",
# "yesterday", "4 days ago", then the day itself.
def:pub agoText(stamp: str) -> str {
    if len(stamp) < 19 {
        return prettyStamp(stamp);
    }
    then: any = new(Date, stamp[:19] + "Z");
    now: any = new(Date);
    mins = int(Math.floor((now.getTime() - then.getTime()) / 60000));
    if mins < 1 {
        return "just now";
    }
    if mins < 60 {
        return str(mins) + " min ago";
    }
    local: any = new(Date, then.getTime() - then.getTimezoneOffset() * 60000);
    days = daysUntil(todayIso(), local.toISOString()[:10]);
    if days == 0 {
        hours = int(Math.floor(mins / 60));
        return str(hours) + (" hour ago" if hours == 1 else " hours ago");
    }
    if days == 1 {
        return "yesterday";
    }
    if days < 7 {
        return str(days) + " days ago";
    }
    return dayText(local.toISOString()[:10]);
}

# The full local date and time of a server stamp, for a hover title.
def stampTitle(stamp: str) -> str {
    if len(stamp) < 19 {
        return stamp;
    }
    d: any = new(Date, stamp[:19] + "Z");
    return str(d.toLocaleString());
}

def prettyStamp(stamp: str) -> str {
    return dayText(stamp[:10]) if len(stamp) >= 10 else "";
}

# The trailing number of an issue or pull request URL, or 0.
def linkNumber(url: str) -> int {
    parts = [
        p
        for p in url.split("#")[0].split("?")[0].split("/")
        if p
    ];
    last = parts[len(parts) - 1] if len(parts) > 0 else "";
    if not last {
        return 0;
    }
    for c in last {
        if c not in "0123456789" {
            return 0;
        }
    }
    return int(last);
}

# The row's GitHub reference as [label, href, description]: the issue when
# there is one, else the pull request. Empty strings when neither is known.
def:pub ghRef(t: TaskView) -> list[str] {
    href = "";
    label = "";
    about = "";
    if t.issue_link or t.gh_issue_number > 0 {
        n = t.gh_issue_number if t.gh_issue_number > 0 else linkNumber(t.issue_link);
        href = t.issue_link;
        label = ("#" + str(n)) if n > 0 else "Issue";
        about = "Issue "
            + label
            + (" (closed)" if t.gh_issue_state == "closed" else "");
    } elif t.pr_link or t.pr_number > 0 {
        n = t.pr_number if t.pr_number > 0 else linkNumber(t.pr_link);
        href = t.pr_link;
        label = ("#" + str(n)) if n > 0 else "PR";
        about = "Pull request "
            + label
            + ((" (" + t.pr_state + ")") if t.pr_state else "");
    }
    if not href.startswith("http") {
        href = "";
    }
    return [label, href, about];
}

def firstName(name: str) -> str {
    parts = name.split();
    return parts[0] if len(parts) > 0 else name;
}

def Chevron(up: bool) -> JsxElement {
    return
        <svg width={12} height={12} viewBox="0 0 16 16" aria-hidden="true">
            <path
                d={"m4.5 10 3.5-3.5 3.5 3.5" if up else "m4.5 6.5 3.5 3.5 3.5-3.5"}
                fill="none"
                stroke="currentColor"
                strokeWidth={1.8}
                strokeLinecap="round"
                strokeLinejoin="round"
            />
        </svg>;
}

def Flag -> JsxElement {
    return
        <svg
            width={14}
            height={14}
            viewBox="0 0 16 16"
            aria-hidden="true"
            className="shrink-0"
        >
            <path
                d="M4 14V2.5M4 3h8l-1.8 3L12 9H4"
                fill="none"
                stroke="currentColor"
                strokeWidth={1.6}
                strokeLinejoin="round"
                strokeLinecap="round"
            />
        </svg>;
}

# The assignee the view is filtered on goes first, so every row names them.
def leadFirst(names: list[str], lead: str) -> list[str] {
    if not lead or lead not in names {
        return names;
    }
    return [lead]
        + [
            n
            for n in names
            if n != lead
        ];
}

# Faces, at most two plus a count, and once the table is wide enough the
# first person's name ("Priya +1"). Every name is in the title.
def People(names: list[str]) -> JsxElement {
    if len(names) == 0 {
        return <span className="text-muted-foreground">Unassigned</span>;
    }
    return
        <span
            className="inline-flex max-w-full min-w-0 items-center gap-1.5"
            title={", ".join(names)}
        >
            <AvatarStack names={names} max={2} size="sm"/>
            <span className="hidden min-w-0 truncate @6xl:inline">
                {firstName(names[0])}
                {if len(names) > 1 {
                    <span key="more" className="num ml-1 text-muted-foreground">
                        {"+" + str(len(names) - 1)}
                    </span>
                }}
            </span>
        </span>;
}

def GitHubCell(task: TaskView) -> JsxElement {
    ref = ghRef(task);
    if not ref[0] {
        return <span className="text-muted-foreground">None</span>;
    }
    if not ref[1] {
        return <span className="num" title={ref[2]}>{ref[0]}</span>;
    }
    return
        <a
            href={ref[1]}
            target="_blank"
            rel="noreferrer"
            title={ref[2]}
            aria-label={ref[2]}
            className="num rounded-xs underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring"
            onClick={lambda (e: MouseEvent) { e.stopPropagation(); }}
        >
            {ref[0]}
        </a>;
}

# A row's column: the step swatch and name, or, with no flow line, the legacy
# status with its kind glyph (`kind` set).
def StepLabel(name: str, color: str, kind: str, className: str) -> JsxElement {
    if kind {
        return
            <span
                className={"inline-flex max-w-full min-w-0 items-center gap-1.5 "
                    + className}
            >
                <KindGlyph kind={kind} className="text-muted-foreground"/>
                <span className="truncate">{name}</span>
            </span>;
    }
    return <StepName name={name} color={color} className={className}/>;
}

def HeaderCell(
    col: list[str],
    sort: str,
    sortDir: str,
    onSort: Callable[[str], None],
    stickyTop: int
) -> JsxElement {
    active = bool(col[0]) and sort == col[0];
    cellClass = "sticky z-10 border-b-0! bg-card shadow-[inset_0_-1px_0_var(--border)] "
        + col[2];
    top: dict[str, str] = {"top": str(stickyTop) + "px"};
    if not col[0] {
        return <th scope="col" className={cellClass} style={top}>{col[1]}</th>;
    }
    return
        <th
            scope="col"
            className={cellClass
                + (" font-semibold! text-foreground!" if active else "")}
            style={top}
            aria-sort={("ascending" if sortDir == "asc" else "descending")
                if active
                else "none"}
        >
            <button
                type="button"
                className="-mx-1 inline-flex items-center gap-1 rounded-sm px-1 hover:text-foreground focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-ring"
                onClick={lambda { onSort(col[0]); }}
            >
                {col[1]}
                {if active {
                    <Chevron key="dir" up={sortDir == "asc"}/>
                }}
            </button>
        </th>;
}

def:pub TaskTable(
    rows: list[TaskView],
    sort: str,
    sortDir: str,
    onSort: Callable[[str], None],
    onOpen: Callable[[str], None],
    stepNames: dict[str, str] = {},
    stepColors: dict[str, str] = {},
    # Filled only without a flow line: the kind each legacy status carries.
    stepKinds: dict[str, str] = {},
    stepHeader: str = "Step",
    leadName: str = "",
    cursor: int = -1,
    onCursor: Callable[[int], None] = None,
    refreshing: bool = False,
    stickyTop: int = 0,
    emptyLabel: str = "No tasks match these filters.",
    emptyAction: str = "",
    onEmptyAction: Callable[[], None] = None,
    # The first load: this many skeleton rows under the real header, at the
    # real row height, instead of the empty state.
    placeholder: int = 0
) -> JsxElement {
    today = todayIso();

    def pointAt(i: int) {
        if onCursor {
            onCursor(i);
        }
    }

    if len(rows) == 0 and placeholder == 0 {
        return
            <div className="flex flex-col items-center gap-3 px-6 py-14 text-center">
                <p className="text-sm text-muted-foreground">{emptyLabel}</p>
                {if emptyAction and onEmptyAction {
                    <button
                        key="action"
                        type="button"
                        className="text-sm font-semibold text-primary underline-offset-4 hover:underline"
                        onClick={lambda { onEmptyAction(); }}
                    >
                        {emptyAction}
                    </button>
                }}
            </div>;
    }
    return
        <div className="min-w-0" aria-busy={refreshing or placeholder > 0}>
            <table className="data-table hidden table-fixed @min-[50rem]:table">
                <thead>
                    <tr>
                        {for col in COLUMNS {
                            <HeaderCell
                                key={col[1]}
                                col={[col[0], stepHeader, col[2]]
                                    if col[0] == "step"
                                    else col}
                                sort={sort}
                                sortDir={sortDir}
                                onSort={onSort}
                                stickyTop={stickyTop}
                            />
                        }}
                    </tr>
                </thead>
                <tbody>
                    {for i in range(placeholder) {
                        <tr key={"ph" + str(i)}>
                            <td className="overflow-hidden whitespace-normal">
                                <div className="flex h-[19px] items-center">
                                    <Skeleton className={"h-3.5 " + PH_WIDTHS[i % 4]}/>
                                </div>
                                <div className="mt-0.5 flex h-4 items-center">
                                    <Skeleton className="h-3 w-20"/>
                                </div>
                            </td>
                            <td className="overflow-hidden whitespace-nowrap">
                                <Skeleton className="h-3.5 w-24"/>
                            </td>
                            <td className="overflow-hidden whitespace-nowrap">
                                <div className="flex items-center gap-1.5">
                                    <Skeleton className="size-6 shrink-0 rounded-full"/>
                                    <Skeleton className="h-3.5 w-12"/>
                                </div>
                            </td>
                            <td className="overflow-hidden">
                                <Skeleton className="h-3.5 w-20"/>
                            </td>
                            <td className="overflow-hidden whitespace-nowrap">
                                <Skeleton className="h-3.5 w-14"/>
                            </td>
                            <td className="overflow-hidden whitespace-nowrap">
                                <Skeleton className="h-3.5 w-10"/>
                            </td>
                            <td className="overflow-hidden">
                                <Skeleton className="h-3.5 w-20"/>
                            </td>
                        </tr>
                    }}
                    {for (i, t) in enumerate(rows) {
                        <tr
                            key={t.id}
                            data-cursor={"true" if i == cursor else "false"}
                            className={"cursor-pointer hover:[&_.ring-card]:ring-accent "
                                + (
                                    "bg-accent [&_.ring-card]:ring-accent"
                                        if i == cursor
                                        else ""
                                )}
                            onClick={lambda { onOpen(t.id); }}
                        >
                            <td
                                className={"overflow-hidden whitespace-normal "
                                    + (
                                        "shadow-[inset_2px_0_0_var(--primary)]"
                                            if i == cursor
                                            else ""
                                    )}
                            >
                                <button
                                    type="button"
                                    data-task-row={str(i)}
                                    className="max-w-full scroll-mt-28 scroll-mb-16 rounded-xs text-left leading-snug font-medium [overflow-wrap:anywhere] outline-none focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-ring focus-visible:outline-solid"
                                    onFocus={lambda { pointAt(i); }}
                                >
                                    {t.title}
                                </button>
                                {if t.project_name {
                                    <div key="proj" className="meta mt-0.5 truncate">
                                        {t.project_name}
                                    </div>
                                }}
                            </td>
                            <td
                                className="overflow-hidden whitespace-nowrap"
                                title={stepNames[t.id]
                                    if t.id in stepNames
                                    else t.status}
                            >
                                <StepLabel
                                    name={stepNames[t.id]
                                        if t.id in stepNames
                                        else t.status}
                                    color={stepColors[t.id]
                                        if t.id in stepColors
                                        else "slate"}
                                    kind={stepKinds[t.id] if t.id in stepKinds else ""}
                                    className="text-[13px] font-semibold"
                                />
                            </td>
                            <td className="overflow-hidden whitespace-nowrap">
                                <People names={leadFirst(t.assignee_names, leadName)}/>
                            </td>
                            {if dueTone(t.due_date, t.status, today) == "overdue" {
                                <td
                                    key="due"
                                    className="overflow-hidden text-destructive"
                                >
                                    <span
                                        className="num block text-[13px] font-semibold"
                                    >
                                        {dayText(t.due_date)}
                                    </span>
                                    <span className="block text-xs font-medium">
                                        {lateText(t.due_date, today)}
                                    </span>
                                </td>
                            } else {
                                <td
                                    key="due"
                                    className={"num overflow-hidden text-[13px] "
                                        + (
                                            "text-muted-foreground"
                                                if t.status == "Done"
                                                else ""
                                        )}
                                >
                                    {dayText(t.due_date)}
                                </td>
                            } }
                            <td className="overflow-hidden whitespace-nowrap">
                                {if t.priority == "High" {
                                    <span
                                        key="high"
                                        className="inline-flex items-center gap-1.5 font-medium"
                                    >
                                        <Flag/>
                                        High
                                    </span>
                                } else {
                                    <span key="other" className="text-muted-foreground">
                                        {t.priority}
                                    </span>
                                } }
                            </td>
                            <td
                                className="overflow-hidden text-[13px] whitespace-nowrap"
                            >
                                <GitHubCell task={t}/>
                            </td>
                            <td
                                className="num overflow-hidden text-[13px] text-muted-foreground"
                                title={stampTitle(t.updated_at)}
                            >
                                {agoText(t.updated_at)}
                            </td>
                        </tr>
                    }}
                </tbody>
            </table>
            <ul className="divide-y @min-[50rem]:hidden">
                {for i in range(placeholder) {
                    <li key={"ph" + str(i)}>
                        <div
                            className="flex min-h-16 w-full flex-col justify-center gap-1 px-4 py-2.5"
                        >
                            <div className="flex h-5 items-center">
                                <Skeleton className={"h-3.5 " + PH_WIDTHS[i % 4]}/>
                            </div>
                            <div className="flex min-h-6 items-center gap-1.5">
                                <Skeleton className="h-3 w-20"/>
                                <Skeleton className="h-3 w-16"/>
                                <Skeleton className="ml-auto size-6 rounded-full"/>
                            </div>
                        </div>
                    </li>
                }}
                {for (i, t) in enumerate(rows) {
                    <li key={t.id}>
                        <button
                            type="button"
                            data-task-row={str(i)}
                            className={"flex min-h-16 w-full scroll-mt-16 flex-col justify-center gap-1 px-4 py-2.5 text-left outline-none hover:bg-accent hover:[&_.ring-card]:ring-accent focus-visible:bg-accent focus-visible:shadow-[inset_2px_0_0_var(--primary)] focus-visible:[&_.ring-card]:ring-accent "
                                + (
                                    "bg-accent [&_.ring-card]:ring-accent"
                                        if i == cursor
                                        else ""
                                )}
                            onFocus={lambda { pointAt(i); }}
                            onClick={lambda { onOpen(t.id); }}
                        >
                            <span
                                className="line-clamp-2 text-[15px] leading-snug font-medium [overflow-wrap:anywhere]"
                            >
                                {t.title}
                            </span>
                            <span
                                className="flex min-h-6 w-full min-w-0 items-center gap-1.5 text-xs text-muted-foreground"
                            >
                                <StepLabel
                                    name={stepNames[t.id]
                                        if t.id in stepNames
                                        else t.status}
                                    color={stepColors[t.id]
                                        if t.id in stepColors
                                        else "slate"}
                                    kind={stepKinds[t.id] if t.id in stepKinds else ""}
                                    className="max-w-[45%] shrink-0 font-medium text-foreground"
                                />
                                {if dueTone(t.due_date, t.status, today) == "overdue" {
                                    <span
                                        key="late"
                                        className="shrink-0 font-semibold text-destructive"
                                    >
                                        {"· " + lateText(t.due_date, today)}
                                    </span>
                                } elif t.due_date {
                                    <span key="due" className="shrink-0">
                                        {"· "}
                                        <span className="num">
                                            {dayText(t.due_date)}
                                        </span>
                                    </span>
                                } }
                                {if t.project_name {
                                    <span key="proj" className="min-w-0 truncate">
                                        {"· " + t.project_name}
                                    </span>
                                }}
                                {if len(t.assignee_names) > 0 {
                                    <span key="who" className="ml-auto shrink-0 pl-1">
                                        <AvatarStack
                                            names={leadFirst(
                                                t.assignee_names, leadName
                                            )}
                                            size="sm"
                                        />
                                    </span>
                                }}
                            </span>
                        </button>
                    </li>
                }}
            </ul>
        </div>;
}
