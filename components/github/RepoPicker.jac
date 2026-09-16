"""Browse the repositories the installation was granted, and add one. Adding
writes a Repo node on this workspace (the same one Projects manages), which
makes the issue and PR tables addressable. Repositories already added stay
visible, marked.
"""

import from ...models { Project, GhRepoRow }
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
import from ..workspace.icons { IconCheck }

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
            <DialogContent className="bg-card sm:max-w-2xl">
                <DialogHeader>
                    <DialogTitle className="section-title">
                        Add a repository
                    </DialogTitle>
                </DialogHeader>
                <div className="flex flex-col gap-3">
                    <form
                        className="flex gap-2"
                        onSubmit={lambda (e: FormEvent) {
                            e.preventDefault();
                            onSearch();
                        }}
                    >
                        <Input
                            className="h-9"
                            placeholder="Filter by name"
                            value={query}
                            onChange={lambda (e: ChangeEvent) { onQuery(
                                e.target.value
                            ); }}
                        />
                        <Button
                            type="submit"
                            variant="outline"
                            size="lg"
                            disabled={loading}
                        >
                            {if loading {
                                <Spinner key="sp"/>
                            }}
                            {"Loading repositories…" if loading else "Search"}
                        </Button>
                    </form>
                    <div className="flex flex-col gap-1.5">
                        <Label htmlFor="repo-project">Issues land in</Label>
                        <Select value={projectId} onValueChange={onProject}>
                            <SelectTrigger id="repo-project" className="h-9">
                                <SelectValue placeholder="Pick a project"/>
                            </SelectTrigger>
                            <SelectContent>
                                {for p in projects {
                                    <SelectItem key={jid(p)} value={jid(p)}>
                                        {p.name}
                                    </SelectItem>
                                }}
                            </SelectContent>
                        </Select>
                        {if not projectId {
                            <p key="need" className="text-xs text-muted-foreground">
                                Pick the project first, then add a repository.
                            </p>
                        }}
                    </div>
                </div>
                <div className="surface max-h-80 overflow-y-auto">
                    {if loading {
                        <div key="loading" className="flex flex-col divide-y">
                            {for i in [0, 1, 2] {
                                <div
                                    key={"sk-" + str(i)}
                                    className="flex items-center gap-3 px-3 py-2.5"
                                >
                                    <Skeleton className="h-4 w-40 max-w-full"/>
                                    <Skeleton className="ml-auto h-7 w-16 shrink-0"/>
                                </div>
                            }}
                        </div>
                    } else {
                        <div key="list" className="flex flex-col">
                            {if len(rows) == 0 {
                                <div
                                    key="empty"
                                    className="flex flex-col items-center gap-1.5 px-6 py-10 text-center"
                                >
                                    <p className="text-sm font-semibold">
                                        Nothing here to add
                                    </p>
                                    <p
                                        className="max-w-sm text-[13px] text-muted-foreground"
                                    >
                                        {"Only repositories you granted the App show up. Grant more from your "}
                                        <a
                                            href="https://github.com/settings/installations"
                                            target="_blank"
                                            rel="noreferrer"
                                            className="text-primary underline-offset-2 hover:underline"
                                        >
                                            GitHub installation settings
                                        </a>
                                        .
                                    </p>
                                </div>
                            }}
                            <ul className="divide-y">
                                {for r in rows {
                                    <li
                                        key={r.full_name}
                                        className="flex items-center gap-3 px-3 py-2.5"
                                    >
                                        <div className="min-w-0 flex-1">
                                            <div className="flex items-center gap-2">
                                                <span
                                                    className="num truncate text-[13px] font-medium"
                                                >
                                                    {r.full_name}
                                                </span>
                                                {if r.private {
                                                    <span
                                                        key="priv"
                                                        className="shrink-0 text-xs text-subtle"
                                                    >
                                                        Private
                                                    </span>
                                                }}
                                            </div>
                                            {if r.description {
                                                <p
                                                    key="desc"
                                                    className="truncate text-xs text-muted-foreground"
                                                >
                                                    {r.description}
                                                </p>
                                            }}
                                        </div>
                                        {if r.attached {
                                            <span
                                                key="on"
                                                className="flex shrink-0 items-center gap-1.5 text-[12.5px] text-muted-foreground"
                                            >
                                                <IconCheck className="text-success"/>
                                                Added
                                            </span>
                                        } else {
                                            <Button
                                                key="add"
                                                variant="outline"
                                                size="sm"
                                                className="shrink-0"
                                                onClick={lambda { onAttach(
                                                    r.full_name
                                                ); }}
                                                disabled={bool(attaching)
                                                    or not projectId}
                                                title={""
                                                    if projectId
                                                    else "Pick the project its issues land in first"}
                                            >
                                                {if attaching == r.full_name {
                                                    <Spinner key="sp"/>
                                                }}
                                                {"Adding…"
                                                    if attaching == r.full_name
                                                    else "Add"}
                                            </Button>
                                        } }
                                    </li>
                                }}
                            </ul>
                            {if hasMore or loadingMore {
                                <button
                                    key="more"
                                    type="button"
                                    disabled={loadingMore}
                                    className="border-t py-2 text-xs text-muted-foreground transition-colors duration-150 hover:bg-accent hover:text-foreground disabled:opacity-60"
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
