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
import from "react" { useEffect }

def:pub ProjectsSection(openNonce: int = 0) -> JsxElement {
    has projects: list[Project] = [],
        repos: list[RepoView] = [],
        loading: bool = True,
        dialogOpen: bool = False,
        editingId: str = "",
        fName: str = "",
        fDescription: str = "",
        fRepoDraft: str = "",
        saving: bool = False,
        handled: Ref[any] = Ref();

    async can with entry {
        loadProjects();
    }



    async def loadProjects -> None;
    async def removeRepo(repoId: str) -> None;
    async def saveProject -> None;
    async def archiveProject(projectId: str) -> None;
    def openCreate -> None;
    def openEdit(p: Project) -> None;

    # The page header owns this tab's primary action and signals it by bumping
    # a counter. Switching tabs UNMOUNTS this panel, so the effect re-runs on
    # remount; `handled` stores (nonce + 1) so a fresh ref reads as 0 and a
    # remount records the current value instead of firing the action again.
    if not handled.current {
        handled.current = openNonce + 1;
    }

    useEffect(lambda {
        if openNonce + 1 != handled.current {
            handled.current = openNonce + 1;
            openCreate();
        }
    }, [openNonce]);

    active = [p for p in projects if p.active];

    return <div className="space-y-8">
        <p className="text-sm text-muted-foreground">
            {str(len(active)) + " active. Tasks, logs and repos are scoped to these."}
        </p>

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
