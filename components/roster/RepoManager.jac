"""The GitHub repo list feeding the daily-log repo dropdown.

Accepts a pasted GitHub URL or a bare org/repo; the page normalizes it
to org/repo before saving, and rows show the repo name first so picking
one is a read, not a parse.
"""

import from ...models { Repo }
import from ..ui.button { Button }
import from ..ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from ..ui.input { Input }

# "jaseci-labs/standup" -> ("standup", "jaseci-labs")
def splitRepo(full_name: str) -> tuple {
    parts = full_name.split("/");
    if len(parts) >= 2 {
        return (parts[-1], parts[0]);
    }
    return (full_name, "");
}

def:pub RepoManager(
    repos: list[Repo],
    value: str,
    onChange: Callable[[str], None],
    onAdd: Callable[[], None],
    onRemove: Callable[[str], None]
) -> JsxElement {
    <Card>
        <CardHeader>
            <CardTitle>Repositories</CardTitle>
            <CardDescription>The repo dropdown on daily-log entries.</CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
            <div className="flex gap-2">
                <Input
                    placeholder="Paste a GitHub link or org/repo"
                    value={value}
                    onChange={lambda (e: ChangeEvent) { onChange(e.target.value); }}
                    onKeyDown={lambda (e: KeyboardEvent) {
                        if e.key == "Enter" { onAdd(); }
                    }}
                />
                <Button variant="outline" onClick={onAdd} disabled={not value.strip()}>
                    Add
                </Button>
            </div>
            {for r in repos {
                <div
                    key={jid(r)}
                    className="flex items-center justify-between gap-2 rounded-md border px-3 py-2 text-sm"
                >
                    <div className="min-w-0">
                        <div className="truncate font-medium">{splitRepo(r.full_name)[0]}</div>
                        {if splitRepo(r.full_name)[1] {
                            <div className="truncate text-xs text-muted-foreground">{splitRepo(r.full_name)[1]}</div>
                        }}
                    </div>
                    <Button
                        variant="ghost"
                        size="sm"
                        className="shrink-0 text-muted-foreground hover:text-destructive"
                        onClick={lambda { onRemove(jid(r)); }}
                    >
                        ✕
                    </Button>
                </div>
            }}
            {if len(repos) == 0 {
                <div key="empty" className="rounded-md border border-dashed p-3 text-center text-xs text-muted-foreground">
                    No repos yet. Paste a GitHub link above.
                </div>
            }}
        </CardContent>
    </Card>
}
