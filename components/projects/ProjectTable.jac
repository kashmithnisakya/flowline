"""Project grid: one ProjectCard per active project."""

import from ...models { Project, RepoView }
import from ..ui.card { Card, CardContent }
import from .ProjectCard { ProjectCard }

def:pub ProjectTable(
    projects: list[Project],
    repos: list[RepoView],
    onEdit: Callable[[Project], None],
    onArchive: Callable[[str], None]
) -> JsxElement {
    if len(projects) == 0 {
        return <Card>
            <CardContent className="py-10 text-center text-sm text-muted-foreground">
                No projects yet. Create your first one.
            </CardContent>
        </Card>;
    }

    return <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
        {for p in projects {
            <ProjectCard
                key={jid(p)}
                project={p}
                repos={[r for r in repos if r.project_id == jid(p)]}
                onEdit={onEdit}
                onArchive={onArchive}
            />
        }}
    </div>;
}
