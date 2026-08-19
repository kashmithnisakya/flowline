"""Browse the repositories the installation was granted, and attach one.
Attaching writes a Repo node on this workspace (the same one Projects manages),
which makes the issue and PR tables addressable. Attached rows stay visible.
"""

import from ...models { Project, GhRepoRow }
import from ..ui.badge { Badge }
import from ..ui.button { Button }
import from ..ui.dialog { Dialog, DialogContent, DialogHeader, DialogTitle }
import from ..ui.input { Input }
import from ..ui.label { Label }
import from ..ui.select {
    Select,
    SelectTrigger,
    SelectValue,
    SelectContent,
    SelectItem
}
import from ..ui.skeleton { Skeleton }
import from ..common.glyphs { Spinner }

def:pub RepoPicker(
    open: bool,
    query: str,
    rows: list[GhRepoRow],
    loading: bool,
    projects: list[Project],
    projectId: str,
    attaching: str,
    onQuery: Callable[[str], None],
    onSearch: Callable[[], None],
    onProject: Callable[[str], None],
    onAttach: Callable[[str], None],
    onOpenChange: Callable[[bool], None],
    # GitHub hands installations their repos 100 at a time; past the first
    # hundred the list ends in a row that asks for the next page.
    hasMore: bool = False,
    loadingMore: bool = False,
    onMore: Callable[[], None] = None
) -> JsxElement {
    return
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="sm:max-w-2xl">
                <DialogHeader>
                    <DialogTitle>Browse GitHub repos</DialogTitle>
                </DialogHeader>
                <div className="grid gap-3">
                    <div className="flex gap-2">
                        <Input
                            placeholder="Filter by name"
                            value={query}
                            onChange={lambda (e: ChangeEvent) { onQuery(
                                e.target.value
                            ); }}
                            onKeyDown={lambda (e: KeyboardEvent) { if e.key == "Enter" {
                                onSearch();
                            }}}
                        />
                        <Button variant="outline" onClick={onSearch} disabled={loading}>
                            {if loading {
                                <Spinner key="sp"/>
                            }}
                            {"Asking…" if loading else "Search"}
                        </Button>
                    </div>
                    <div className="grid gap-2">
                        <Label>Attach to project</Label>
                        <Select value={projectId} onValueChange={onProject}>
                            <SelectTrigger>
                                <SelectValue placeholder="Project"/>
                            </SelectTrigger>
                            <SelectContent>
                                <SelectItem value="none">No project</SelectItem>
                                {for p in projects {
                                    <SelectItem key={jid(p)} value={jid(p)}>
                                        {p.name}
                                    </SelectItem>
                                }}
                            </SelectContent>
                        </Select>
                    </div>
                </div>
                <div className="max-h-80 space-y-2 overflow-y-auto">
                    {if loading {
                        <div key="loading" className="space-y-2">
                            {for i in [0, 1, 2] {
                                <div
                                    key={"sk-" + str(i)}
                                    className="flex items-start justify-between gap-3 rounded-lg border bg-card p-3"
                                >
                                    <div className="min-w-0 flex-1 space-y-2">
                                        <Skeleton className="h-4 w-40 max-w-full"/>
                                        <Skeleton className="h-3 w-56 max-w-full"/>
                                    </div>
                                    <Skeleton className="h-7 w-16 shrink-0 rounded-lg"/>
                                </div>
                            }}
                        </div>
                    } else {
                        <div key="list" className="space-y-2">
                            {if len(rows) == 0 {
                                <div
                                    key="empty"
                                    className="space-y-2 py-8 text-center text-sm text-muted-foreground"
                                >
                                    <svg
                                        className="mx-auto text-muted-foreground/50"
                                        width={24}
                                        height={24}
                                        viewBox="0 0 24 24"
                                        fill="none"
                                        stroke="currentColor"
                                        strokeWidth={2}
                                        strokeLinecap="round"
                                        strokeLinejoin="round"
                                    >
                                        <path
                                            d="M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H20v20H6.5a2.5 2.5 0 0 1 0-5H20"
                                        />
                                    </svg>
                                    <p className="font-medium text-foreground">
                                        Nothing here to attach.
                                    </p>
                                    <p className="text-xs">
                                        Only repositories granted to the installation show up. Grant more from your{" "}
                                        <a
                                            href="https://github.com/settings/installations"
                                            target="_blank"
                                            rel="noreferrer"
                                            className="font-medium text-primary underline-offset-2 hover:underline"
                                        >
                                            GitHub installation settings
                                        </a>
                                        .
                                    </p>
                                </div>
                            }}
                            {for r in rows {
                                <div
                                    key={r.full_name}
                                    className="flex items-start justify-between gap-3 rounded-lg border bg-card p-3"
                                >
                                    <div className="min-w-0 space-y-1">
                                        <div className="flex items-center gap-2">
                                            <span
                                                className="truncate text-sm font-medium"
                                            >
                                                {r.full_name}
                                            </span>
                                            {if r.private {
                                                <Badge
                                                    key="priv"
                                                    variant="outline"
                                                    className="font-normal"
                                                >
                                                    Private
                                                </Badge>
                                            }}
                                        </div>
                                        <p
                                            className="line-clamp-2 text-xs text-muted-foreground"
                                        >
                                            {r.description
                                            or "No description on GitHub."}
                                        </p>
                                    </div>
                                    {if r.attached {
                                        <Badge
                                            key="on"
                                            variant="secondary"
                                            className="shrink-0 font-normal text-muted-foreground"
                                        >
                                            <svg
                                                viewBox="0 0 24 24"
                                                fill="none"
                                                stroke="currentColor"
                                                strokeWidth={2}
                                                strokeLinecap="round"
                                                strokeLinejoin="round"
                                            >
                                                <path d="M20 6 9 17l-5-5"/>
                                            </svg>
                                            Attached
                                        </Badge>
                                    } else {
                                        <Button
                                            key="add"
                                            variant="outline"
                                            size="sm"
                                            className="shrink-0"
                                            onClick={lambda { onAttach(r.full_name); }}
                                            disabled={bool(attaching)}
                                        >
                                            {if attaching == r.full_name {
                                                <Spinner key="sp"/>
                                            }}
                                            {"Attaching…"
                                                if attaching == r.full_name
                                                else "Attach"}
                                        </Button>
                                    } }
                                </div>
                            }}
                            {if hasMore or loadingMore {
                                <button
                                    key="more"
                                    type="button"
                                    disabled={loadingMore}
                                    className="w-full rounded-lg border border-dashed py-2 text-xs text-muted-foreground transition-colors hover:bg-accent hover:text-foreground disabled:opacity-60"
                                    onClick={lambda { if onMore { onMore(); }}}
                                >
                                    {"Loading…"
                                        if loadingMore
                                        else "More repositories from GitHub"}
                                </button>
                            }}
                        </div>
                    } }
                </div>
            </DialogContent>
        </Dialog>;
}
