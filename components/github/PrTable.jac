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
import from ..ui.skeleton { Skeleton }
import from ..ui.table {
    Table, TableHeader, TableBody, TableRow, TableHead, TableCell
}

# Relative "3d ago" label from an ISO stamp. Empty in, empty out; anything
# older than a month falls back to the plain date. No date libs, just an
# explicit if-chain over truncated divisions.
def timeAgo(iso: str) -> str {
    if not iso {
        return "";
    }
    then = new(Date, iso);
    now = new(Date);
    ms = now.getTime() - then.getTime();
    if ms < 0 {
        ms = 0;
    }
    mins = int(ms / 60000);
    if mins < 1 {
        return "just now";
    }
    if mins < 60 {
        return str(mins) + "m ago";
    }
    hours = int(mins / 60);
    if hours < 24 {
        return str(hours) + "h ago";
    }
    days = int(hours / 24);
    if days < 31 {
        return str(days) + "d ago";
    }
    return iso[:10];
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
                <div className="text-sm tabular-nums text-muted-foreground">
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
                <div key="loading" className="space-y-1 py-2">
                    {for i in [0, 1, 2, 3, 4] {
                        <div key={"sk-" + str(i)} className="flex items-center gap-3 px-2 py-2.5">
                            <Skeleton className="h-4 w-10 shrink-0" />
                            <Skeleton className="h-4 w-full max-w-80" />
                            <Skeleton className="ml-auto hidden h-4 w-16 shrink-0 sm:block" />
                            <Skeleton className="h-5 w-14 shrink-0 rounded-full" />
                            <Skeleton className="hidden h-4 w-12 shrink-0 md:block" />
                        </div>
                    }}
                </div>
            } else {
                <div key="rows" className="space-y-3">
                    {if len(rows) == 0 {
                        <div key="empty" className="py-10 text-center">
                            <svg
                                className="mx-auto text-muted-foreground/50"
                                width={28}
                                height={28}
                                viewBox="0 0 24 24"
                                fill="none"
                                stroke="currentColor"
                                strokeWidth={2}
                                strokeLinecap="round"
                                strokeLinejoin="round"
                            >
                                <circle cx={18} cy={18} r={3} />
                                <circle cx={6} cy={6} r={3} />
                                <path d="M13 6h3a2 2 0 0 1 2 2v7" />
                                <path d="M6 9v12" />
                            </svg>
                            <p className="mt-3 text-sm font-medium">Nothing to show</p>
                            <p className="mt-1 text-sm text-muted-foreground">
                                No pull requests in this repo for that state.
                            </p>
                        </div>
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
                                            {("@" + r.author) if r.author else "—"}
                                        </TableCell>
                                        <TableCell>
                                            <Badge
                                                variant="outline"
                                                className={"font-normal " + stateClass(r.state)}
                                            >
                                                {r.state}
                                            </Badge>
                                        </TableCell>
                                        <TableCell
                                            className="text-xs tabular-nums text-muted-foreground"
                                            title={r.updated_at[:16].replace("T", " ")}
                                        >
                                            {timeAgo(r.updated_at) if r.updated_at else "—"}
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
                                {if loadingMore {
                                    <svg
                                        key="sp"
                                        className="animate-spin"
                                        width={14}
                                        height={14}
                                        viewBox="0 0 24 24"
                                        fill="none"
                                        stroke="currentColor"
                                        strokeWidth={2}
                                        strokeLinecap="round"
                                    >
                                        <path d="M21 12a9 9 0 1 1-6.219-8.56" />
                                    </svg>
                                }}
                                {"Loading…" if loadingMore else "Load more"}
                            </Button>
                        </div>
                    }}
                </div>
            }}
        </CardContent>
    </Card>;
}
