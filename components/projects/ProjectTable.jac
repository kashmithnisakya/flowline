"""Project grid: one card per project with edit/archive actions."""

import from ...models { Project }
import from ..ui.button { Button }
import from ..ui.card {
    Card, CardHeader, CardTitle, CardDescription, CardContent
}

def:pub ProjectTable(
    projects: list[Project],
    onEdit: Callable[[Project], None],
    onArchive: Callable[[str], None]
) -> JsxElement {
    if len(projects) == 0 {
        return <Card>
            <CardContent className="py-10 text-center text-sm text-muted-foreground">
                No projects yet — create your first one.
            </CardContent>
        </Card>;
    }

    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
        {for p in projects {
            <Card key={jid(p)} className="gap-3 py-5 transition-shadow hover:shadow-md">
                <CardHeader className="gap-1">
                    <CardTitle className="flex items-center gap-2 text-base">
                        <span className="h-2 w-2 shrink-0 rounded-full bg-primary" />
                        <span className="truncate">{p.name}</span>
                    </CardTitle>
                    <CardDescription className="min-h-10 text-sm">
                        {p.description if p.description else "No description yet."}
                    </CardDescription>
                </CardHeader>
                <CardContent className="flex items-center justify-end gap-1 pt-0">
                    <Button variant="ghost" size="sm" onClick={lambda { onEdit(p); }}>
                        Edit
                    </Button>
                    <Button
                        variant="ghost"
                        size="sm"
                        className="text-destructive"
                        onClick={lambda { onArchive(jid(p)); }}
                    >
                        Archive
                    </Button>
                </CardContent>
            </Card>
        }}
    </div>
}
