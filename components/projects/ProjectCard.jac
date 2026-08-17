"""One project card: identity, its repos, edit/archive actions. Display-only;
repos are attached in the project dialog.
"""

import from ...models { Project, RepoView }
import from ..ui.button { Button }
import from ..ui.card {
    Card,
    CardHeader,
    CardTitle,
    CardDescription,
    CardContent,
    CardFooter
}
import from ..ui.badge { Badge }

# Identity dot hues picked by name hash; whole literal strings so Tailwind
# scans them.
glob DOT_HUES: list[str] = [
         "bg-chart-1",
         "bg-chart-2",
         "bg-chart-3",
         "bg-chart-4",
         "bg-chart-5"
     ];

# "jaseci-labs/standup" -> "standup"
def repoName(full_name: str) -> str {
    parts = full_name.split("/");
    return parts[-1] if parts else full_name;
}

# Deterministic dot hue: sum of character codes into the hue table.
def dotHueFor(name: any) -> str {
    total = 0;
    for i in range(len(name)) {
        total = total + name.charCodeAt(i);
    }
    return DOT_HUES[total % 5];
}

def:pub ProjectCard(
    project: Project,
    repos: list[RepoView],
    onEdit: Callable[[Project], None],
    onArchive: Callable[[str], None]
) -> JsxElement {
    # Archive is a two-step: the first click arms, the second fires.
    has armed: bool = False;

    return
        <Card className="card-hover gap-3 py-5 hover:ring-foreground/20">
            <CardHeader className="gap-1">
                <CardTitle className="flex items-center gap-2 text-base">
                    <span
                        className={"h-2 w-2 shrink-0 rounded-full " + dotHueFor(
                            project.name
                        )}
                    />
                    <span className="truncate">{project.name}</span>
                </CardTitle>
                <CardDescription className="min-h-5 text-sm">
                    {project.description or "No description yet."}
                </CardDescription>
            </CardHeader>
            <CardContent className="space-y-2">
                <div
                    className="text-xs font-medium uppercase tracking-wide text-muted-foreground"
                >
                    Repositories
                </div>
                {if len(repos) > 0 {
                    <div key="repos" className="flex flex-wrap gap-1.5">
                        {for r in repos {
                            <Badge
                                key={r.id}
                                variant="secondary"
                                className="font-normal"
                                title={r.full_name}
                            >
                                {repoName(r.full_name)}
                            </Badge>
                        }}
                    </div>
                } else {
                    <p key="none" className="text-xs text-muted-foreground">
                        None yet. Add one via Edit.
                    </p>
                } }
            </CardContent>
            <CardFooter className="justify-end gap-1 pt-0">
                <Button variant="ghost" size="sm" onClick={lambda { onEdit(project); }}>
                    Edit
                </Button>
                <Button
                    variant={"destructive" if armed else "ghost"}
                    size="sm"
                    className={"" if armed else "text-destructive"}
                    title={"Click again to archive" if armed else "Archive"}
                    onClick={lambda { if armed {
                        armed = False;
                        onArchive(jid(project));
                    } else {
                        armed = True;
                    } }}
                >
                    {"Confirm?" if armed else "Archive"}
                </Button>
            </CardFooter>
        </Card>;
}
