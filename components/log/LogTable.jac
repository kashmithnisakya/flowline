"""The activity feed: rows written automatically by board moves."""

import from "@jac/runtime" { Link }
import from ...models { LogEntry }
import from ...constants { STATUS_KIND, KIND_COLORS }
import from ..workflow.kinds { COUNT_TINT }
import from ..ui.card { Card, CardContent }
import from ..ui.checkbox { Checkbox }
import from ..ui.table { Table, TableHeader, TableBody, TableRow, TableHead, TableCell }

glob HEAD_CLS: str = "text-xs uppercase tracking-wider text-muted-foreground";

# "https://github.com/org/repo/pull/42" -> "#42" (falls back to "link").
def linkRef(url: str) -> str {
    parts = [
        p
        for p in url.split("/")
        if p
    ];
    if parts {
        tail = parts[-1];
        digits = True;
        for ch in tail {
            if ch not in "0123456789" {
                digits = False;
            }
        }
        if digits and tail {
            return "#" + tail;
        }
    }
    return "link";
}

# The legacy status in the board's colour voice: status -> kind -> colour key
# -> chip classes (literal strings live in constants/kinds tables).
def statusTint(status: str) -> str {
    kind = STATUS_KIND[status] if status in STATUS_KIND else "active";
    color = KIND_COLORS[kind] if kind in KIND_COLORS else "slate";
    return COUNT_TINT[color] if color in COUNT_TINT else COUNT_TINT["slate"];
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
    return days[int(d.getDay())] + ", " + months[int(d.getMonth())] + " " + str(
        int(d.getDate())
    );
}

def:pub LogTable(
    entries: list[LogEntry],
    emptyLabel: str,
    selecting: bool = False,
    selected: list[str] = [],
    onToggleSelect: Callable[[str], None] = None
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
                        Entries are written automatically as tasks move on the board.
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
                            <TableHead className={HEAD_CLS}>Date</TableHead>
                            <TableHead className={HEAD_CLS}>Task</TableHead>
                            <TableHead className={HEAD_CLS}>Action</TableHead>
                            <TableHead className={HEAD_CLS}>Project</TableHead>
                            <TableHead className={HEAD_CLS}>Member</TableHead>
                            <TableHead className={HEAD_CLS}>Issue</TableHead>
                            <TableHead className={HEAD_CLS}>PR</TableHead>
                            <TableHead className={HEAD_CLS}>Status</TableHead>
                            <TableHead className={HEAD_CLS}>Note</TableHead>
                        </TableRow>
                    </TableHeader>
                    <TableBody>
                        {for en in entries {
                            <TableRow
                                key={jid(en)}
                                data-state={"selected"
                                    if selecting and jid(en) in selected
                                    else ""}
                                className={"data-[state=selected]:bg-primary/5" + (
                                    " cursor-pointer" if selecting else ""
                                )}
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
                                    <div className="text-sm">
                                        {prettyDate(en.date) if en.date else "—"}
                                    </div>
                                    {if len(en.at) >= 16 {
                                        <div
                                            key="at"
                                            className="text-xs tabular-nums text-muted-foreground"
                                        >
                                            {en.at[11:16]}
                                        </div>
                                    }}
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
                                <TableCell className="text-xs">
                                    {if en.issue_link {
                                        <a
                                            href={en.issue_link}
                                            target="_blank"
                                            rel="noopener"
                                            className="font-medium text-primary underline-offset-2 hover:underline"
                                        >
                                            {linkRef(en.issue_link)}
                                        </a>
                                    } else {
                                        <span
                                            key="dash"
                                            className="text-muted-foreground"
                                        >
                                            —
                                        </span>
                                    } }
                                </TableCell>
                                <TableCell className="text-xs">
                                    {if en.pr_link {
                                        <a
                                            href={en.pr_link}
                                            target="_blank"
                                            rel="noopener"
                                            className="font-medium text-primary underline-offset-2 hover:underline"
                                        >
                                            {linkRef(en.pr_link)}
                                        </a>
                                    } else {
                                        <span
                                            key="dash"
                                            className="text-muted-foreground"
                                        >
                                            —
                                        </span>
                                    } }
                                </TableCell>
                                <TableCell className="whitespace-nowrap">
                                    {if en.status {
                                        <span
                                            key="st"
                                            className={"inline-flex items-center rounded-full border px-2 py-0.5 text-xs font-medium " + statusTint(
                                                en.status
                                            )}
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
                            </TableRow>
                        }}
                    </TableBody>
                </Table>
            </CardContent>
        </Card>;
}
