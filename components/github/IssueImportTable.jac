"""One page of a repo's issues, with the ones you pick landing on the board.

Import is keyed on (repo, issue number), so an issue already on the board is
skipped rather than duplicated. Those rows stay visible but disabled: hiding
them would make the table disagree with what GitHub shows.
"""

glob STATUSES: list[str] = [
    "Backlog", "In Progress", "Review", "Changes Requested", "Done", "Blocked"
];
glob ISSUE_STATES: list[str] = ["open", "closed", "all"];

import from ...models { Project, GhIssueRow }
import from ..ui.badge { Badge }
import from ..ui.button { Button }
import from ..ui.card { Card, CardContent }
import from ..ui.select {
    Select, SelectTrigger, SelectValue, SelectContent, SelectItem
}
import from ..ui.table {
    Table, TableHeader, TableBody, TableRow, TableHead, TableCell
}

def:pub IssueImportTable(
    rows: list[GhIssueRow],
    loading: bool,
    loadingMore: bool,
    hasMore: bool,
    state: str,
    selected: list[int],
    projects: list[Project],
    projectId: str,
    status: str,
    importing: bool,
    onState: Callable[[str], None],
    onToggle: Callable[[int], None],
    onProject: Callable[[str], None],
    onStatus: Callable[[str], None],
    onImport: Callable[[], None],
    onLoadMore: Callable[[], None]
) -> JsxElement {
    return <Card>
        <CardContent className="space-y-3 pt-4">
            <div className="flex flex-wrap items-center gap-2">
                <div className="text-sm text-muted-foreground">
                    {str(len(rows)) + (" issue" if len(rows) == 1 else " issues")}
                </div>
                <div className="ml-auto">
                    <Select value={state} onValueChange={onState}>
                        <SelectTrigger className="h-8 w-32">
                            <SelectValue placeholder="State" />
                        </SelectTrigger>
                        <SelectContent>
                            {for s in ISSUE_STATES {
                                <SelectItem key={s} value={s}>{s}</SelectItem>
                            }}
                        </SelectContent>
                    </Select>
                </div>
            </div>

            {if loading {
                <p key="loading" className="py-10 text-center text-sm text-muted-foreground">
                    Asking GitHub…
                </p>
            } else {
                <div key="rows" className="space-y-3">
                    {if len(rows) == 0 {
                        <p key="empty" className="py-10 text-center text-sm text-muted-foreground">
                            No issues in this repo for that state.
                        </p>
                    } else {
                        <Table key="table">
                            <TableHeader>
                                <TableRow>
                                    <TableHead className="w-8" />
                                    <TableHead>#</TableHead>
                                    <TableHead>Title</TableHead>
                                    <TableHead>Labels</TableHead>
                                    <TableHead>Assignee</TableHead>
                                    <TableHead>State</TableHead>
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                {for r in rows {
                                    <TableRow
                                        key={str(r.number)}
                                        className={"opacity-60" if r.already_imported else ""}
                                    >
                                        <TableCell className="w-8">
                                            <input
                                                type="checkbox"
                                                className="h-4 w-4 cursor-pointer disabled:cursor-not-allowed"
                                                style={{"accentColor": "var(--primary)"}}
                                                checked={r.number in selected}
                                                disabled={r.already_imported}
                                                onChange={lambda { onToggle(r.number); }}
                                            />
                                        </TableCell>
                                        <TableCell className="text-muted-foreground">
                                            {"#" + str(r.number)}
                                        </TableCell>
                                        <TableCell className="max-w-96">
                                            <a
                                                href={r.html_url}
                                                target="_blank"
                                                rel="noreferrer"
                                                className="block truncate font-medium underline-offset-2 hover:underline"
                                                title={r.title}
                                            >
                                                {r.title}
                                            </a>
                                        </TableCell>
                                        <TableCell>
                                            <div className="flex flex-wrap gap-1">
                                                {for l in r.labels {
                                                    <Badge key={l} variant="outline" className="font-normal">
                                                        {l}
                                                    </Badge>
                                                }}
                                            </div>
                                        </TableCell>
                                        <TableCell className="text-muted-foreground">
                                            {r.assignee if r.assignee else "·"}
                                        </TableCell>
                                        <TableCell>
                                            {if r.already_imported {
                                                <Badge key="done" variant="secondary" className="font-normal">
                                                    Imported
                                                </Badge>
                                            } else {
                                                <span key="st" className="text-xs text-muted-foreground">
                                                    {r.state}
                                                </span>
                                            }}
                                        </TableCell>
                                    </TableRow>
                                }}
                            </TableBody>
                        </Table>
                    }}
                    {if hasMore {
                        <div key="more" className="flex justify-center">
                            <Button
                                variant="outline"
                                size="sm"
                                onClick={onLoadMore}
                                disabled={loadingMore}
                            >
                                {"Loading…" if loadingMore else "Load more"}
                            </Button>
                        </div>
                    }}
                </div>
            }}

            <div className="flex flex-wrap items-center gap-2 rounded-lg border bg-muted/30 p-3 text-sm">
                <span>
                    {
                        "Import " + str(len(selected))
                        + (" issue into" if len(selected) == 1 else " issues into")
                    }
                </span>
                <Select value={projectId} onValueChange={onProject}>
                    <SelectTrigger className="h-8 w-44">
                        <SelectValue placeholder="Project" />
                    </SelectTrigger>
                    <SelectContent>
                        <SelectItem value="none">The repo's project</SelectItem>
                        {for p in projects {
                            <SelectItem key={jid(p)} value={jid(p)}>{p.name}</SelectItem>
                        }}
                    </SelectContent>
                </Select>
                <span>as</span>
                <Select value={status} onValueChange={onStatus}>
                    <SelectTrigger className="h-8 w-44">
                        <SelectValue placeholder="Status" />
                    </SelectTrigger>
                    <SelectContent>
                        {for s in STATUSES {
                            <SelectItem key={s} value={s}>{s}</SelectItem>
                        }}
                    </SelectContent>
                </Select>
                <Button
                    className="ml-auto"
                    size="sm"
                    onClick={onImport}
                    disabled={importing or len(selected) == 0}
                >
                    {"Importing…" if importing else "Import"}
                </Button>
            </div>
            <p className="text-xs text-muted-foreground">
                A closed issue lands in Done whichever column you pick. Assignees are
                matched to roster members by GitHub username, and anyone without a
                match is left off.
            </p>
        </CardContent>
    </Card>;
}
