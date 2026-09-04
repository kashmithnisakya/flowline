"""The task table: a flat, sortable list of TaskView rows. Sortable columns
are node fields (Title, Status, Priority, Est, Category, Due, Updated);
Project and Assignees render but do not sort (they are edge hops, ordered
server-side only by node field). A row deep-links to the board dialog."""

import from "@jac/runtime" { Link }
import from ...models { TaskView }
import from ..flowlines.kinds { statusChip }
import from ..common.Avatar { AvatarStack }
import from ..ui.card { Card, CardContent }
import from ..ui.table { Table, TableHeader, TableBody, TableRow, TableHead, TableCell }
import from ...lib.dates { todayIso, dueLabel, dueTone, prettyDay }
import from ...lib.utils { fmtEstimate }

glob PRIORITY_TINT: dict[str, str] = {
         "High": "font-semibold text-destructive",
         "Low": "text-muted-foreground",
         "Medium": "text-foreground"
     },
     SORT_COLS: list[list[str]] = [
         ["title", "Task"],
         ["status", "Status"],
         ["priority", "Priority"],
         ["estimate", "Est"],
         ["category", "Category"],
         ["due", "Due"],
         ["updated", "Updated"]
     ];

# A GitHub issue/PR URL to its short "#42" ref, "link" otherwise. Local by
# design: a shared copy in lib/utils gets its cross-module export dropped by
# the 0.36.1 client compiler and dynamic-dispatched (returns an object that
# crashes the render), so the log table keeps its own copy too.
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


# A caret showing the active sort direction, or a faint idle mark.
def sortCaret(active: bool, dir: str) -> str {
    if not active {
        return "↕";
    }
    return "↑" if dir == "asc" else "↓";
}

def:pub TaskTable(
    rows: list[TaskView],
    sort: str,
    sortDir: str,
    onSort: Callable[[str], None],
    emptyLabel: str = "No tasks match these filters."
) -> JsxElement {
    today = todayIso();
    if len(rows) == 0 {
        return
            <Card>
                <CardContent
                    className="py-12 text-center text-sm text-muted-foreground"
                >
                    {emptyLabel}
                </CardContent>
            </Card>;
    }
    return
        <Card>
            <CardContent className="overflow-x-auto p-0">
                <Table>
                    <TableHeader>
                        <TableRow>
                            {for col in SORT_COLS {
                                <TableHead
                                    key={col[0]}
                                    className="cursor-pointer select-none whitespace-nowrap text-xs uppercase tracking-wider text-muted-foreground hover:text-foreground"
                                    onClick={lambda { onSort(col[0]); }}
                                >
                                    {col[1] + " " + sortCaret(sort == col[0], sortDir)}
                                </TableHead>
                            }}
                            <TableHead
                                className="text-xs uppercase tracking-wider text-muted-foreground"
                            >
                                Project
                            </TableHead>
                            <TableHead
                                className="text-xs uppercase tracking-wider text-muted-foreground"
                            >
                                Links
                            </TableHead>
                            <TableHead
                                className="text-xs uppercase tracking-wider text-muted-foreground"
                            >
                                Assignees
                            </TableHead>
                        </TableRow>
                    </TableHeader>
                    <TableBody>
                        {for t in rows {
                            <TableRow key={t.id} className="hover:bg-accent/50">
                                <TableCell className="max-w-72">
                                    <Link
                                        to={"/board?task=" + t.id}
                                        className="block truncate font-medium hover:underline"
                                        title={t.title}
                                    >
                                        {t.title}
                                    </Link>
                                </TableCell>
                                <TableCell className="whitespace-nowrap">
                                    <span
                                        className={"inline-flex items-center rounded-full border px-2 py-0.5 text-xs font-medium "
                                            + statusChip(t.status)}
                                    >
                                        {t.status}
                                    </span>
                                </TableCell>
                                <TableCell
                                    className={"whitespace-nowrap text-sm "
                                        + (
                                            PRIORITY_TINT[t.priority]
                                                if t.priority in PRIORITY_TINT
                                                else "text-foreground"
                                        )}
                                >
                                    {t.priority}
                                </TableCell>
                                <TableCell
                                    className="whitespace-nowrap text-sm tabular-nums text-muted-foreground"
                                >
                                    {fmtEstimate(t.estimate)
                                        if t.estimate > 0.0
                                        else "—"}
                                </TableCell>
                                <TableCell className="text-sm text-muted-foreground">
                                    {t.category or "—"}
                                </TableCell>
                                <TableCell
                                    className={"whitespace-nowrap text-sm "
                                        + (
                                            "font-medium text-destructive"
                                                if dueTone(t.due_date, t.status, today)
                                                    == "overdue"
                                                else "text-muted-foreground"
                                        )}
                                >
                                    {dueLabel(t.due_date, t.status, today)
                                        if t.due_date
                                        else "—"}
                                </TableCell>
                                <TableCell
                                    className="whitespace-nowrap text-sm text-muted-foreground"
                                >
                                    {prettyDay(t.updated_at[:10])
                                        if len(t.updated_at) >= 10
                                        else "—"}
                                </TableCell>
                                <TableCell className="text-sm text-muted-foreground">
                                    {t.project_name or "—"}
                                </TableCell>
                                <TableCell className="whitespace-nowrap text-xs">
                                    {if t.issue_link {
                                        <a
                                            key="issue"
                                            href={t.issue_link}
                                            target="_blank"
                                            rel="noopener"
                                            title="Issue"
                                            onClick={lambda (e: MouseEvent) { e.stopPropagation(); }}
                                            className="font-medium text-primary underline-offset-2 hover:underline"
                                        >
                                            {githubRef(t.issue_link)}
                                        </a>
                                    }}
                                    {if t.issue_link and t.pr_link {
                                        <span
                                            key="sep"
                                            className="text-muted-foreground"
                                        >
                                            {" · "}
                                        </span>
                                    }}
                                    {if t.pr_link {
                                        <a
                                            key="pr"
                                            href={t.pr_link}
                                            target="_blank"
                                            rel="noopener"
                                            title="Pull request"
                                            onClick={lambda (e: MouseEvent) { e.stopPropagation(); }}
                                            className="font-medium text-primary underline-offset-2 hover:underline"
                                        >
                                            {"PR " + githubRef(t.pr_link)}
                                        </a>
                                    }}
                                    {if not t.issue_link and not t.pr_link {
                                        <span
                                            key="dash"
                                            className="text-muted-foreground"
                                        >
                                            —
                                        </span>
                                    }}
                                </TableCell>
                                <TableCell>
                                    {if len(t.assignee_names) > 0 {
                                        <AvatarStack
                                            key="who"
                                            names={t.assignee_names}
                                        />
                                    } else {
                                        <span
                                            key="none"
                                            className="text-sm text-muted-foreground"
                                        >
                                            —
                                        </span>
                                    } }
                                </TableCell>
                            </TableRow>
                        }}
                    </TableBody>
                </Table>
            </CardContent>
        </Card>;
}
