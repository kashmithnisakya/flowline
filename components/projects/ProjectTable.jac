"""Project grid: one ProjectCard per active project."""

import from ...models { Project, RepoView }
import from ..ui.button { Button }
import from ..ui.card { Card, CardContent }
import from .ProjectCard { ProjectCard }

def:pub ProjectTable(
    projects: list[Project],
    repos: list[RepoView],
    onEdit: Callable[[Project], None],
    onArchive: Callable[[str], None],
    onCreate: Callable[[], None] = None
) -> JsxElement {
    if len(projects) == 0 {
        return <Card>
            <CardContent className="flex flex-col items-center gap-2 py-10 text-center">
                <svg
                    className="text-muted-foreground/60"
                    width={28}
                    height={28}
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={2}
                    strokeLinecap="round"
                    strokeLinejoin="round"
                >
                    <path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/>
                </svg>
                <p className="text-sm font-semibold">No projects yet</p>
                <p className="text-sm text-muted-foreground">
                    Tasks, logs and repos are all scoped to a project.
                </p>
                {if onCreate {
                    <Button
                        key="cta"
                        size="sm"
                        className="mt-2"
                        onClick={lambda { onCreate(); }}
                    >
                        <svg
                            width={14}
                            height={14}
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth={2}
                            strokeLinecap="round"
                            strokeLinejoin="round"
                        >
                            <path d="M5 12h14"/>
                            <path d="M12 5v14"/>
                        </svg>
                        New project
                    </Button>
                }}
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
