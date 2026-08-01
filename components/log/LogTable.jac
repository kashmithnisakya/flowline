"""The activity feed: rows written automatically by board moves."""

import from ...models { LogEntry }
import from ..ui.button { Button }
import from ..ui.card { Card, CardContent }
import from ..ui.table {
    Table, TableHeader, TableBody, TableRow, TableHead, TableCell
}

def:pub LogTable(
    entries: list[LogEntry],
    emptyLabel: str,
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
                        <TableRow key={jid(en)}>
                            <TableCell className="whitespace-nowrap">
                                <div className="text-sm">{en.date}</div>
                                {if len(en.at) >= 16 {
                                    <div className="text-xs text-muted-foreground">{en.at[11:16]}</div>
                                }}
                            </TableCell>
                            <TableCell>
                                <div className="font-medium">
                                    {en.task_title if en.task_title else en.activity}
                                </div>
                                {if en.task_title {
                                    <div className="text-xs text-muted-foreground">{en.activity}</div>
                                }}
                            </TableCell>
                            <TableCell className="text-muted-foreground">{en.project_name}</TableCell>
                            <TableCell>{en.member_name}</TableCell>
                            <TableCell className="text-xs">
                                {if en.issue_link {
                                    <a
                                        href={en.issue_link}
                                        target="_blank"
                                        className="text-primary underline-offset-2 hover:underline"
                                    >
                                        Issue
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
                                        className="text-primary underline-offset-2 hover:underline"
                                    >
                                        PR
                                    </a>
                                } else {
                                    <span key="dash" className="text-muted-foreground">·</span>
                                }}
                            </TableCell>
                            <TableCell className="whitespace-nowrap">{en.status}</TableCell>
                            <TableCell className="max-w-56 truncate text-muted-foreground">{en.notes}</TableCell>
                            <TableCell className="text-right">
                                <Button
                                    variant="ghost"
                                    size="sm"
                                    className="text-muted-foreground hover:text-destructive"
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
