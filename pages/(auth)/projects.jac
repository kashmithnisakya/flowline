"""standup - Projects page: create, rename, archive."""

import from ...models { Project }
import from ...walkers.projects { ListProjects, SaveProject, ArchiveProject }
import from ...components.projects.ProjectTable { ProjectTable }
import from ...components.projects.ProjectDialog { ProjectDialog }
import from ...components.ui.button { Button }
import from ...components.ui.skeleton { Skeleton }
import from "sonner" { toast }

def:pub ProjectsPage() -> JsxPage {
    has projects: list[Project] = [],
        loading: bool = True,
        dialogOpen: bool = False,
        editingId: str = "",
        fName: str = "",
        fDescription: str = "",
        saving: bool = False;

    async can with entry {
        loadProjects();
    }

    async def loadProjects -> None;
    async def saveProject -> None;
    async def archiveProject(projectId: str) -> None;
    def openCreate -> None;
    def openEdit(p: Project) -> None;

    active = [p for p in projects if p.active];

    <div className="space-y-8">
        <div className="flex items-center justify-between">
            <div>
                <h1 className="font-display text-2xl font-bold tracking-tight">Projects</h1>
                <p className="text-sm text-muted-foreground">
                    {len(active)} active — tasks and daily logs are scoped to these.
                </p>
            </div>
            <Button onClick={openCreate}>New project</Button>
        </div>

        {if loading {
            <Skeleton key="sk" className="h-48 w-full" />
        } else {
            <ProjectTable key="table"
                projects={active}
                onEdit={openEdit}
                onArchive={archiveProject}
            />
        }}

        <ProjectDialog
            open={dialogOpen}
            editing={bool(editingId)}
            name={fName}
            description={fDescription}
            saving={saving}
            onName={lambda (v: str) { fName = v; }}
            onDescription={lambda (v: str) { fDescription = v; }}
            onOpenChange={lambda (o: bool) { dialogOpen = o; }}
            onSave={saveProject}
        />
    </div>
}
