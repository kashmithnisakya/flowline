"""The GitHub repo list feeding the daily-log repo dropdown."""

import from ...models { Repo }
import from ..ui.button { Button }
import from ..ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from ..ui.input { Input }

def:pub RepoManager(
    repos: list[Repo],
    value: str,
    onChange: Callable[[str], None],
    onAdd: Callable[[], None],
    onRemove: Callable[[str], None]
) -> JsxElement {
    <Card>
        <CardHeader>
            <CardTitle>GitHub Repos</CardTitle>
            <CardDescription>The repo dropdown on daily-log entries.</CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
            <div className="flex gap-2">
                <Input
                    placeholder="org/repo"
                    className="max-w-sm"
                    value={value}
                    onChange={lambda (e: ChangeEvent) { onChange(e.target.value); }}
                />
                <Button variant="outline" onClick={onAdd} disabled={not value.strip()}>
                    Add
                </Button>
            </div>
            {for r in repos {
                <div
                    key={jid(r)}
                    className="flex items-center justify-between rounded-md border px-3 py-2 text-sm"
                >
                    <span className="font-mono">{r.full_name}</span>
                    <Button variant="ghost" size="sm" onClick={lambda { onRemove(jid(r)); }}>
                        Remove
                    </Button>
                </div>
            }}
        </CardContent>
    </Card>
}
