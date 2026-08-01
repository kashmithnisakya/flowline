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
                        <TableHead>Member</TableHead>
                        <TableHead>Project</TableHead>
                        <TableHead>Tags</TableHead>
                        <TableHead>Activity</TableHead>
                        <TableHead>Category</TableHead>
                        <TableHead>Links</TableHead>
                        <TableHead>Status</TableHead>
                        <TableHead>Notes</TableHead>
                        <TableHead className="text-right">Actions</TableHead>
                    </TableRow>
                </TableHeader>
                <TableBody>
                    {for en in entries {
                        <TableRow key={jid(en)}>
                            <TableCell className="whitespace-nowrap text-muted-foreground">{en.date}</TableCell>
                            <TableCell className="font-medium">{en.member_name}</TableCell>
                            <TableCell className="text-muted-foreground">{en.project_name}</TableCell>
                            <TableCell className="text-muted-foreground">{en.tags}</TableCell>
                            <TableCell>{en.activity}</TableCell>
                            <TableCell className="text-muted-foreground">{en.category}</TableCell>
                            <TableCell className="whitespace-nowrap text-xs">
                                {if en.issue_link {
                                    <a
                                        href={en.issue_link}
                                        target="_blank"
                                        className="text-primary underline-offset-2 hover:underline"
                                    >
                                        Issue
                                    </a>
                                }}
                                {if en.issue_link and en.pr_link {
                                    <span className="text-muted-foreground"> · </span>
                                }}
                                {if en.pr_link {
                                    <a
                                        href={en.pr_link}
                                        target="_blank"
                                        className="text-primary underline-offset-2 hover:underline"
                                    >
                                        PR
                                    </a>
                                }}
                            </TableCell>
                            <TableCell>{en.status}</TableCell>
                            <TableCell className="max-w-48 truncate text-muted-foreground">{en.notes}</TableCell>
                            <TableCell className="text-right whitespace-nowrap">
                                <Button
                                    variant="ghost"
                                    size="sm"
                                    className="text-destructive"
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
