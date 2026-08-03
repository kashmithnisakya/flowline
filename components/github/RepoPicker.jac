"""Browse the repositories the installation was granted, and attach one.

Attaching writes a Repo node on this workspace (the same one the Projects
page manages), which is what makes the issue and pull-request tables
addressable. Rows already attached are shown, not hidden, so the list still
matches what GitHub reports.
"""

import from ...models { Project, GhRepoRow }
import from ..ui.badge { Badge }
import from ..ui.button { Button }
import from ..ui.dialog {
    Dialog, DialogContent, DialogHeader, DialogTitle
}
import from ..ui.input { Input }
import from ..ui.label { Label }
import from ..ui.select {
    Select, SelectTrigger, SelectValue, SelectContent, SelectItem
}

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
    onOpenChange: Callable[[bool], None]
) -> JsxElement {
    return <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="sm:max-w-2xl">
            <DialogHeader>
                <DialogTitle>Browse GitHub repos</DialogTitle>
            </DialogHeader>
            <div className="grid gap-3">
                <div className="flex gap-2">
                    <Input
                        placeholder="Filter by name"
                        value={query}
                        onChange={lambda (e: ChangeEvent) { onQuery(e.target.value); }}
                        onKeyDown={lambda (e: KeyboardEvent) {
                            if e.key == "Enter" { onSearch(); }
                        }}
                    />
                    <Button variant="outline" onClick={onSearch} disabled={loading}>
                        {"Asking…" if loading else "Search"}
                    </Button>
                </div>
                <div className="grid gap-2">
                    <Label>Attach to project</Label>
                    <Select value={projectId} onValueChange={onProject}>
                        <SelectTrigger><SelectValue placeholder="Project" /></SelectTrigger>
                        <SelectContent>
                            <SelectItem value="none">No project</SelectItem>
                            {for p in projects {
                                <SelectItem key={jid(p)} value={jid(p)}>{p.name}</SelectItem>
                            }}
                        </SelectContent>
                    </Select>
                </div>
            </div>

            <div className="max-h-80 space-y-2 overflow-y-auto">
                {if loading {
                    <p key="loading" className="py-8 text-center text-sm text-muted-foreground">
                        Asking GitHub…
                    </p>
                } else {
                    <div key="list" className="space-y-2">
                        {if len(rows) == 0 {
                            <div key="empty" className="space-y-2 py-8 text-center text-sm text-muted-foreground">
                                <p>Nothing here to attach.</p>
                                <p className="text-xs">
                                    Only repositories granted to the installation show up.
                                    Grant more from your
                                    {" "}
                                    <a
                                        href="https://github.com/settings/installations"
                                        target="_blank"
                                        rel="noreferrer"
                                        className="font-medium text-primary underline-offset-2 hover:underline"
                                    >
                                        GitHub installation settings
                                    </a>.
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
                                        <span className="truncate text-sm font-medium">
                                            {r.full_name}
                                        </span>
                                        {if r.private {
                                            <Badge key="priv" variant="outline" className="font-normal">
                                                Private
                                            </Badge>
                                        }}
                                    </div>
                                    <p className="line-clamp-2 text-xs text-muted-foreground">
                                        {r.description if r.description else "No description on GitHub."}
                                    </p>
                                </div>
                                {if r.attached {
                                    <span key="on" className="shrink-0 text-xs text-muted-foreground">
                                        Attached
                                    </span>
                                } else {
                                    <Button
                                        key="add"
                                        variant="outline"
                                        size="sm"
                                        className="shrink-0"
                                        onClick={lambda { onAttach(r.full_name); }}
                                        disabled={bool(attaching)}
                                    >
                                        {"Attaching…" if attaching == r.full_name else "Attach"}
                                    </Button>
                                }}
                            </div>
                        }}
                    </div>
                }}
            </div>
        </DialogContent>
    </Dialog>;
}
