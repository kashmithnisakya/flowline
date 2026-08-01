"""One project card: identity, its repos, edit/archive actions.

Repos belong to projects in v2.3; each card manages its own list. The
input accepts a pasted GitHub link or bare org/repo (the page normalizes
before saving).
"""

import from ...models { Project, RepoView }
import from ..ui.button { Button }
import from ..ui.card {
    Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter
}
import from ..ui.input { Input }
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
    onArchive: Callable[[str], None],
    onAddRepo: Callable[[str, str], None],
    onRemoveRepo: Callable[[str], None]
) -> JsxElement {
    has newRepo: str = "";

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
                        <Badge
                            key={r.id}
                            variant="secondary"
                            className="cursor-pointer font-normal"
                            title={r.full_name + " (click to remove)"}
                            onClick={lambda { onRemoveRepo(r.id); }}
                        >
                            {repoName(r.full_name)} ✕
                        </Badge>
                    }}
                </div>
            }}
            <div className="flex gap-2">
                <Input
                    placeholder="Paste a GitHub link or org/repo"
                    className="h-8 text-xs"
                    value={newRepo}
                    onChange={lambda (e: ChangeEvent) { newRepo = e.target.value; }}
                    onKeyDown={lambda (e: KeyboardEvent) {
                        if e.key == "Enter" and newRepo.strip() {
                            onAddRepo(jid(project), newRepo);
                            newRepo = "";
                        }
                    }}
                />
                <Button
                    variant="outline"
                    size="sm"
                    disabled={not newRepo.strip()}
                    onClick={lambda {
                        onAddRepo(jid(project), newRepo);
                        newRepo = "";
                    }}
                >
                    Add
                </Button>
            </div>
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
