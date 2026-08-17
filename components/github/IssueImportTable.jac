"""One page of a repo's issues; picked ones land on the board. Import is keyed
on (repo, issue number), so an issue already on the board is skipped, shown
disabled rather than hidden so the table still matches GitHub.
"""

glob STATUSES: list[str] = [
    "Backlog", "In Progress", "Review", "Changes Requested", "Done", "Blocked"
];
glob ISSUE_STATES: list[str] = ["open", "closed", "all"];

import from ...models { Project, StepView, GhIssueRow }
import from ..ui.badge { Badge }
import from ..ui.button { Button }
import from ..ui.card { Card, CardContent }
import from ..ui.tickbox { Checkbox }
import from ..ui.select {
    Select, SelectTrigger, SelectValue, SelectContent, SelectItem
}
import from ..ui.skeleton { Skeleton }
import from ..ui.table {
    Table, TableHeader, TableBody, TableRow, TableHead, TableCell
}
import from ..common.glyphs { Spinner }

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
    steps: list[StepView],
    stepId: str,
    importing: bool,
    query: str,
    onState: Callable[[str], None],
    onToggle: Callable[[int], None],
    onProject: Callable[[str], None],
    onStatus: Callable[[str], None],
    onStep: Callable[[str], None],
    onImport: Callable[[], None],
    onLoadMore: Callable[[], None]
) -> JsxElement {
    return <Card>
        <CardContent className="space-y-3 pt-4">
            <div className="flex flex-wrap items-center gap-2">
                <div className="text-sm tabular-nums text-muted-foreground">
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
                <div key="loading" className="space-y-1 py-2">
                    {for i in [0, 1, 2, 3, 4] {
                        <div key={"sk-" + str(i)} className="flex items-center gap-3 px-2 py-2.5">
                            <Skeleton className="size-4 shrink-0 rounded" />
                            <Skeleton className="h-4 w-10 shrink-0" />
                            <Skeleton className="h-4 w-full max-w-80" />
                            <Skeleton className="ml-auto hidden h-5 w-16 shrink-0 rounded-full sm:block" />
                            <Skeleton className="hidden h-4 w-14 shrink-0 md:block" />
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
                                <path d="M22 12h-6l-2 3h-4l-2-3H2" />
                                <path d="M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z" />
                            </svg>
                            <p className="mt-3 text-sm font-medium">
                                {"No matches" if query else "Nothing to import"}
                            </p>
                            <p className="mt-1 text-sm text-muted-foreground">
                                {
                                    "No issues match \"" + query + "\" for that state."
                                        if query
                                        else "No issues in this repo for that state."
                                }
                            </p>
                            {if state != "all" {
                                <Button
                                    key="allstates"
                                    variant="ghost"
                                    size="sm"
                                    className="mt-3"
                                    onClick={lambda { onState("all"); }}
                                >
                                    Show all states
                                </Button>
                            }}
                        </div>
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
                                            <Checkbox
                                                checked={r.number in selected}
                                                disabled={r.already_imported}
                                                onCheckedChange={lambda { onToggle(r.number); }}
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
                                            {r.assignee if r.assignee else "—"}
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
                                {if loadingMore {
                                    <Spinner key="sp"/>
                                }}
                                {"Loading…" if loadingMore else "Load more"}
                            </Button>
                        </div>
                    }}
                </div>
            }}

            {if len(rows) > 0 {
            <div key="importbar" className="flex flex-wrap items-center gap-x-4 gap-y-2 rounded-lg border bg-muted/30 p-3 text-sm">
                <span className="inline-flex items-center gap-2">
                    <span className="text-muted-foreground">Into</span>
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
                </span>
                <span className="inline-flex items-center gap-2">
                    <span className="text-muted-foreground">as</span>
                    {if len(steps) > 0 {
                        <Select key="stepsel" value={stepId} onValueChange={onStep}>
                            <SelectTrigger className="h-8 w-44">
                                <SelectValue placeholder="Step" />
                            </SelectTrigger>
                            <SelectContent>
                                {for s in steps {
                                    <SelectItem key={s.id} value={s.id}>{s.name}</SelectItem>
                                }}
                            </SelectContent>
                        </Select>
                    } else {
                        <Select key="statussel" value={status} onValueChange={onStatus}>
                            <SelectTrigger className="h-8 w-44">
                                <SelectValue placeholder="Status" />
                            </SelectTrigger>
                            <SelectContent>
                                {for s in STATUSES {
                                    <SelectItem key={s} value={s}>{s}</SelectItem>
                                }}
                            </SelectContent>
                        </Select>
                    }}
                </span>
                <Button
                    className="ml-auto tabular-nums"
                    size="sm"
                    onClick={onImport}
                    disabled={importing or len(selected) == 0}
                >
                    {if importing {
                        <Spinner key="sp"/>
                    }}
                    {
                        "Importing…" if importing
                        else ("Import " + str(len(selected)) if len(selected) > 0 else "Import")
                    }
                </Button>
            </div>
            }}
            {if len(rows) > 0 {
                <p key="importnote" className="text-xs text-muted-foreground">
                    A closed issue always lands in your done step, whichever you
                    pick. Assignees are matched to roster members by GitHub
                    username, and anyone without a match is left off.
                </p>
            }}
        </CardContent>
    </Card>;
}
