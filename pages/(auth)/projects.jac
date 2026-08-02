"""standup - Projects page: create, rename, archive."""

import from ...models { Project, RepoView }
import from ...walkers.projects { ListProjects, SaveProject, ArchiveProject }
import from ...walkers.roster { ListRepos, AddRepo, RemoveRepo }
import from ...components.projects.ProjectTable { ProjectTable }

def normalizeRepoInput(raw: str) -> str {
    cleaned = raw.strip();
    cleaned = cleaned.replace("https://github.com/", "");
    cleaned = cleaned.replace("http://github.com/", "");
    cleaned = cleaned.replace("git@github.com:", "");
    cleaned = cleaned.replace("www.github.com/", "");
    if cleaned.endswith(".git") {
        cleaned = cleaned[:-4];
    }
    cleaned = cleaned.strip("/");
    parts = [p for p in cleaned.split("/") if p];
    if len(parts) >= 2 {
        return parts[0] + "/" + parts[1];
    }
    return cleaned;
}
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
        fRepoDraft: str = "",
        saving: bool = False;

    async can with entry {
        loadProjects();
    }

    async def loadProjects -> None;
    async def removeRepo(repoId: str) -> None;
    async def saveProject -> None;
    async def archiveProject(projectId: str) -> None;
    def openCreate -> None;
    def openEdit(p: Project) -> None;

    active = [p for p in projects if p.active];

    return <div className="space-y-8">
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
            repos={[r for r in repos if editingId and r.project_id == editingId]}
            repoDraft={fRepoDraft}
            onRepoDraft={lambda (v: str) { fRepoDraft = v; }}
            onRemoveRepo={removeRepo}
        />
    </div>;
}
