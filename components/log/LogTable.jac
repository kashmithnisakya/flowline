"""The activity feed: rows written automatically by board moves.

Each row can be marked reviewed (the check control); delete unlocks only
after a row is checked, so nothing vanishes unacknowledged.
"""

import from ...models { LogEntry }
import from ..ui.button { Button }
import from ..ui.card { Card, CardContent }
import from ..ui.table {
    Table, TableHeader, TableBody, TableRow, TableHead, TableCell
}

# "https://github.com/org/repo/pull/42" -> "#42" (falls back to "link").
def linkRef(url: str) -> str {
    parts = [p for p in url.split("/") if p];
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

def:pub LogTable(
    entries: list[LogEntry],
    emptyLabel: str,
    onCheck: Callable[[str], None],
    onDelete: Callable[[str], None]
) -> JsxElement {
    if len(entries) == 0 {
        return <Card>
            <CardContent className="py-10 text-center text-sm text-muted-foreground">
                {emptyLabel}
            </CardContent>
        </Card>;
    }

    <Card>
        <CardContent className="pt-4">
            <Table>
                <TableHeader>
                    <TableRow>
                        <TableHead>Date</TableHead>
                        <TableHead>Task</TableHead>
                        <TableHead>Action</TableHead>
                        <TableHead>Project</TableHead>
                        <TableHead>Member</TableHead>
                        <TableHead>Issue</TableHead>
                        <TableHead>PR</TableHead>
                        <TableHead>Status</TableHead>
                        <TableHead>Note</TableHead>
                        <TableHead className="text-right">Actions</TableHead>
                    </TableRow>
                </TableHeader>
                <TableBody>
                    {for en in entries {
                        <TableRow key={jid(en)} className={"opacity-60" if en.checked else ""}>
                            <TableCell className="whitespace-nowrap">
                                <div className="text-sm">{en.date}</div>
                                {if len(en.at) >= 16 {
                                    <div className="text-xs text-muted-foreground">{en.at[11:16]}</div>
                                }}
                            </TableCell>
                            <TableCell className="max-w-56">
                                <div className="truncate font-medium">
                                    {en.task_title if en.task_title else en.activity}
                                </div>
                            </TableCell>
                            <TableCell className="text-muted-foreground">
                                {en.activity if en.task_title else "·"}
                            </TableCell>
                            <TableCell className="text-muted-foreground">{en.project_name}</TableCell>
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
                                    <span key="dash" className="text-muted-foreground">·</span>
                                }}
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
                                    <span key="dash" className="text-muted-foreground">·</span>
                                }}
                            </TableCell>
                            <TableCell className="whitespace-nowrap">{en.status}</TableCell>
                            <TableCell className="max-w-48 truncate text-muted-foreground">{en.notes}</TableCell>
                            <TableCell className="whitespace-nowrap text-right">
                                <Button
                                    variant={"default" if en.checked else "ghost"}
                                    size="icon-xs"
                                    title={"Reviewed. Click to uncheck" if en.checked else "Mark as reviewed"}
                                    onClick={lambda { onCheck(jid(en)); }}
                                >
                                    ✓
                                </Button>
                                <Button
                                    variant="ghost"
                                    size="icon-xs"
                                    className="text-muted-foreground hover:text-destructive"
                                    disabled={not en.checked}
                                    title={"Delete" if en.checked else "Check the row first, then delete"}
                                    onClick={lambda { onDelete(jid(en)); }}
                                >
                                    ✕
                                </Button>
                            </TableCell>
                        </TableRow>
                    }}
                </TableBody>
            </Table>
        </CardContent>
    </Card>
}
