"""One page of a repo's pull requests. Read-only.

Nothing here writes to GitHub or to the board: a PR joins a task by its link
or number on the task itself, and this table only says which ones already
have. Merged and draft are standup's own reading of GitHub's flags, which
report both as "closed" and "open".
"""

glob PR_STATES: list[str] = ["open", "closed", "all"];

import from ...models { GhPrRow }
import from ..ui.badge { Badge }
import from ..ui.button { Button }
import from ..ui.card { Card, CardContent }
import from ..ui.select {
    Select, SelectTrigger, SelectValue, SelectContent, SelectItem
}
import from ..ui.table {
    Table, TableHeader, TableBody, TableRow, TableHead, TableCell
}

# Tint per state. Merged and draft have no palette token of their own, so they
# borrow Tailwind's violet and the muted surface.
def stateClass(state: str) -> str {
    if state == "merged" {
        return "border-violet-500/40 bg-violet-500/10 text-violet-700 dark:text-violet-300";
    }
    if state == "closed" {
        return "border-destructive/40 bg-destructive/10 text-destructive";
    }
    if state == "draft" {
        return "border-border bg-muted text-muted-foreground";
    }
    return "border-sky-500/40 bg-sky-500/10 text-sky-700 dark:text-sky-300";
}

def:pub PrTable(
    rows: list[GhPrRow],
    loading: bool,
    loadingMore: bool,
    hasMore: bool,
    state: str,
    onState: Callable[[str], None],
    onLoadMore: Callable[[], None]
) -> JsxElement {
    return <Card>
        <CardContent className="space-y-3 pt-4">
            <div className="flex flex-wrap items-center gap-2">
                <div className="text-sm text-muted-foreground">
                    {
                        str(len(rows))
                        + (" pull request" if len(rows) == 1 else " pull requests")
                    }
                </div>
                <div className="ml-auto">
                    <Select value={state} onValueChange={onState}>
                        <SelectTrigger className="h-8 w-32">
                            <SelectValue placeholder="State" />
                        </SelectTrigger>
                        <SelectContent>
                            {for s in PR_STATES {
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
                            No pull requests in this repo for that state.
                        </p>
                    } else {
                        <Table key="table">
                            <TableHeader>
                                <TableRow>
                                    <TableHead>#</TableHead>
                                    <TableHead>Title</TableHead>
                                    <TableHead>Author</TableHead>
                                    <TableHead>State</TableHead>
                                    <TableHead>Updated</TableHead>
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                {for r in rows {
                                    <TableRow key={str(r.number)}>
                                        <TableCell className="text-muted-foreground">
                                            {"#" + str(r.number)}
                                        </TableCell>
                                        <TableCell className="max-w-96">
                                            <div className="flex items-center gap-2">
                                                <a
                                                    href={r.html_url}
                                                    target="_blank"
                                                    rel="noreferrer"
                                                    className="truncate font-medium underline-offset-2 hover:underline"
                                                    title={r.title}
                                                >
                                                    {r.title}
                                                </a>
                                                {if r.linked_task_id {
                                                    <Badge
                                                        key="linked"
                                                        variant="outline"
                                                        className="shrink-0 font-normal"
                                                        title="A task on the board points at this PR"
                                                    >
                                                        linked
                                                    </Badge>
                                                }}
                                            </div>
                                        </TableCell>
                                        <TableCell className="text-muted-foreground">
                                            {("@" + r.author) if r.author else "·"}
                                        </TableCell>
                                        <TableCell>
                                            <Badge
                                                variant="outline"
                                                className={"font-normal " + stateClass(r.state)}
                                            >
                                                {r.state}
                                            </Badge>
                                        </TableCell>
                                        <TableCell className="text-xs text-muted-foreground">
                                            {r.updated_at[:10]}
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
        </CardContent>
    </Card>;
}
