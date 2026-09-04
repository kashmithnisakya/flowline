"""The activity feed: rows written automatically by board moves, plus the
PM's own entries. `onEdit` adds a per-row pencil (hidden in select mode)."""

import from "@jac/runtime" { Link }
import from ...models { LogEntry }
import from ..flowlines.kinds { statusChip }
import from ..ui.card { Card, CardContent }
import from ..ui.checkbox { Checkbox }
import from ..ui.table { Table, TableHeader, TableBody, TableRow, TableHead, TableCell }

glob HEAD_CLS: str = "text-xs uppercase tracking-wider text-muted-foreground";

# A GitHub issue/PR URL to its short "#42" ref, "link" otherwise. Local by
# design: extracting it to a shared module made the 0.36.1 client compiler
# drop the cross-module export and dynamic-dispatch the call (returns an
# object, crashing the render); fmtEstimate survives the same path, this
# does not, so both tables keep their own copy.
def githubRef(url: str) -> str {
    parts = [
        p
        for p in url.split("/")
        if p
    ];
    if parts and parts[-1].isdigit() {
        return "#" + parts[-1];
    }
    return "link";
}

# "2026-08-10" -> "Mon, Aug 10", matching the DatePicker trigger.
def prettyDate(iso: str) -> str {
    d = new(Date, iso + "T00:00:00");
    days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    months = [
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
    return days[int(d.getDay())]
        + ", "
        + months[int(d.getMonth())]
        + " "
        + str(int(d.getDate()));
}

def:pub LogTable(
    entries: list[LogEntry],
    emptyLabel: str,
    selecting: bool = False,
    selected: list[str] = [],
    onToggleSelect: Callable[[str], None] = None,
    # The day view already names the day in its header; only the time is news.
    showDate: bool = True,
    onEdit: Callable[[LogEntry], None] = None
) -> JsxElement {
    if len(entries) == 0 {
        return
            <Card>
                <CardContent className="py-10 text-center">
                    <svg
                        className="mx-auto mb-3 text-muted-foreground/50"
                        width={32}
                        height={32}
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth={2}
                        strokeLinecap="round"
                        strokeLinejoin="round"
                    >
                        <path d="M8 2v4"/>
                        <path d="M16 2v4"/>
                        <rect width={18} height={18} x={3} y={4} rx={2}/>
                        <path d="M3 10h18"/>
                    </svg>
                    <p className="text-sm font-semibold">{emptyLabel}</p>
                    <p className="mx-auto mt-1 max-w-sm text-sm text-muted-foreground">
                        Most entries are written automatically as tasks move on the board; Add entry logs work that happened off it.
                    </p>
                    <Link
                        to="/board"
                        className="mt-3 inline-flex items-center gap-1.5 text-sm font-medium text-primary underline-offset-4 hover:underline"
                    >
                        Go to the board
                        <svg
                            width={14}
                            height={14}
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth={2}
                            strokeLinecap="round"
                            strokeLinejoin="round"
                        >
                            <path d="M5 12h14"/>
                            <path d="m12 5 7 7-7 7"/>
                        </svg>
                    </Link>
                </CardContent>
            </Card>;
    }

    return
        <Card>
            <CardContent className="pt-4">
                <Table>
                    <TableHeader>
                        <TableRow>
                            {if selecting {
                                <TableHead key="sel" className="w-8"/>
                            }}
                            <TableHead className={HEAD_CLS}>
                                {"Date" if showDate else "Time"}
                            </TableHead>
                            <TableHead className={HEAD_CLS}>Task</TableHead>
                            <TableHead className={HEAD_CLS}>Action</TableHead>
                            <TableHead className={HEAD_CLS}>Project</TableHead>
                            <TableHead className={HEAD_CLS}>Member</TableHead>
                            <TableHead className={HEAD_CLS}>Links</TableHead>
                            <TableHead className={HEAD_CLS}>Status</TableHead>
                            <TableHead className={HEAD_CLS}>Note</TableHead>
                            {if not selecting and onEdit {
                                <TableHead key="edit" className="w-8"/>
                            }}
                        </TableRow>
                    </TableHeader>
                    <TableBody>
                        {for en in entries {
                            <TableRow
                                key={jid(en)}
                                data-state={"selected"
                                    if selecting and jid(en) in selected
                                    else ""}
                                className={"data-[state=selected]:bg-primary/5"
                                    + (" cursor-pointer" if selecting else "")}
                                onClick={lambda { if selecting and onToggleSelect {
                                    onToggleSelect(jid(en));
                                }}}
                            >
                                {if selecting {
                                    <TableCell key="sel" className="w-8">
                                        <Checkbox
                                            className="cursor-pointer"
                                            checked={jid(en) in selected}
                                            onCheckedChange={lambda { if onToggleSelect {
                                                onToggleSelect(jid(en));
                                            }}}
                                            onClick={lambda (e: MouseEvent) { e.stopPropagation(); }}
                                        />
                                    </TableCell>
                                }}
                                <TableCell className="whitespace-nowrap">
                                    {if showDate {
                                        <div key="date" className="text-sm">
                                            {prettyDate(en.date) if en.date else "—"}
                                        </div>
                                    }}
                                    {if len(en.at) >= 16 {
                                        <div
                                            key="at"
                                            className={"tabular-nums text-muted-foreground "
                                                + (
                                                    "text-xs" if showDate else "text-sm"
                                                )}
                                        >
                                            {en.at[11:16]}
                                        </div>
                                    } elif not showDate {
                                        <span
                                            key="nodate"
                                            className="text-muted-foreground"
                                        >
                                            —
                                        </span>
                                    } }
                                </TableCell>
                                <TableCell className="max-w-56">
                                    <div className="truncate font-medium">
                                        {en.task_title or en.activity}
                                    </div>
                                </TableCell>
                                <TableCell className="text-muted-foreground">
                                    {en.activity if en.task_title else "—"}
                                </TableCell>
                                <TableCell className="text-muted-foreground">
                                    {en.project_name}
                                </TableCell>
                                <TableCell>{en.member_name}</TableCell>
                                <TableCell className="whitespace-nowrap text-xs">
                                    {if en.issue_link {
                                        <a
                                            key="issue"
                                            href={en.issue_link}
                                            target="_blank"
                                            rel="noopener"
                                            title="Issue"
                                            className="font-medium text-primary underline-offset-2 hover:underline"
                                        >
                                            {githubRef(en.issue_link)}
                                        </a>
                                    }}
                                    {if en.issue_link and en.pr_link {
                                        <span
                                            key="sep"
                                            className="text-muted-foreground"
                                        >
                                            {" · "}
                                        </span>
                                    }}
                                    {if en.pr_link {
                                        <a
                                            key="pr"
                                            href={en.pr_link}
                                            target="_blank"
                                            rel="noopener"
                                            title="Pull request"
                                            className="font-medium text-primary underline-offset-2 hover:underline"
                                        >
                                            {"PR " + githubRef(en.pr_link)}
                                        </a>
                                    }}
                                    {if not en.issue_link and not en.pr_link {
                                        <span
                                            key="dash"
                                            className="text-muted-foreground"
                                        >
                                            —
                                        </span>
                                    }}
                                </TableCell>
                                <TableCell className="whitespace-nowrap">
                                    {if en.status {
                                        <span
                                            key="st"
                                            className={"inline-flex items-center rounded-full border px-2 py-0.5 text-xs font-medium "
                                                + statusChip(en.status)}
                                        >
                                            {en.status}
                                        </span>
                                    } else {
                                        <span
                                            key="stdash"
                                            className="text-muted-foreground"
                                        >
                                            —
                                        </span>
                                    } }
                                </TableCell>
                                <TableCell
                                    className="max-w-48 truncate text-muted-foreground"
                                >
                                    {en.notes}
                                </TableCell>
                                {if not selecting and onEdit {
                                    <TableCell key="edit" className="w-8">
                                        <button
                                            type="button"
                                            aria-label="Edit entry"
                                            title="Edit entry"
                                            className="rounded-md p-1.5 text-muted-foreground/60 transition-colors hover:bg-accent hover:text-foreground"
                                            onClick={lambda { if onEdit {
                                                onEdit(en);
                                            }}}
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
                                            >
                                                <path
                                                    d="M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z"
                                                />
                                                <path d="m15 5 4 4"/>
                                            </svg>
                                        </button>
                                    </TableCell>
                                }}
                            </TableRow>
                        }}
                    </TableBody>
                </Table>
            </CardContent>
        </Card>;
}
