"""standup - Projects page: create, rename, archive."""

import from ...models { Project, RepoView }
import from ...walkers.projects { ListProjects, SaveProject, ArchiveProject }
import from ...walkers.roster { ListRepos, AddRepo, RemoveRepo }
import from ...lib.utils { normalizeRepoInput }
import from ...components.projects.ProjectTable { ProjectTable }
import from ...components.projects.ProjectDialog { ProjectDialog }
import from ...components.ui.button { Button }
import from ...components.ui.skeleton { Skeleton }
import from "sonner" { toast }

def:pub ProjectsPage() -> JsxPage {
    has projects: list[Project] = [],
        repos: list[RepoView] = [],
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
    async def addRepo(projectId: str, raw: str) -> None;
    async def removeRepo(repoId: str) -> None;
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
                    {len(active)} active. Tasks, logs and repos are scoped to these.
                </p>
            </div>
            <Button onClick={openCreate}>New project</Button>
        </div>

        {if loading {
            <Skeleton key="sk" className="h-48 w-full" />
        } else {
            <ProjectTable key="table"
                projects={active}
                repos={repos}
                onEdit={openEdit}
                onArchive={archiveProject}
                onAddRepo={addRepo}
                onRemoveRepo={removeRepo}
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
