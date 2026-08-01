"""One project card: identity, its repos, edit/archive actions.

Display-only: repos are attached in the project dialog (creation has an
optional repo field; editing manages the list).
"""

import from ...models { Project, RepoView }
import from ..ui.button { Button }
import from ..ui.card {
    Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter
}
import from ..ui.badge { Badge }

# "jaseci-labs/standup" -> "standup"
def repoName(full_name: str) -> str {
    parts = full_name.split("/");
    return parts[-1] if parts else full_name;
}

def:pub ProjectCard(
    project: Project,
    repos: list[RepoView],
    onEdit: Callable[[Project], None],
    onArchive: Callable[[str], None]
) -> JsxElement {
    <Card className="gap-3 py-5 transition-shadow hover:shadow-md">
        <CardHeader className="gap-1">
            <CardTitle className="flex items-center gap-2 text-base">
                <span className="h-2 w-2 shrink-0 rounded-full bg-primary" />
                <span className="truncate">{project.name}</span>
            </CardTitle>
            <CardDescription className="min-h-5 text-sm">
                {project.description if project.description else "No description yet."}
            </CardDescription>
        </CardHeader>
        <CardContent className="space-y-2">
            <div className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                Repositories
            </div>
            {if len(repos) > 0 {
                <div key="repos" className="flex flex-wrap gap-1.5">
                    {for r in repos {
                        <Badge key={r.id} variant="secondary" className="font-normal" title={r.full_name}>
                            {repoName(r.full_name)}
                        </Badge>
                    }}
                </div>
            } else {
                <p key="none" className="text-xs text-muted-foreground">None yet. Add one via Edit.</p>
            }}
        </CardContent>
        <CardFooter className="justify-end gap-1 pt-0">
            <Button variant="ghost" size="sm" onClick={lambda { onEdit(project); }}>
                Edit
            </Button>
            <Button
                variant="ghost"
                size="sm"
                className="text-destructive"
                onClick={lambda { onArchive(jid(project)); }}
            >
                Archive
            </Button>
        </CardFooter>
    </Card>
}
