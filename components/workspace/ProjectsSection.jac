"""flowline - Projects section of the workspace: create, rename, link a repo,
archive. The lists are the page's (one workspace read), and the open count
is the tallies a project carries (total minus done), so a row says how much
work is still standing without a count call.
"""

import from ...models { Project, RepoView, MemberView }
import from ...lib.workspace { forgetWorkspace }
import from ...services.projects.projects { SaveProject, ArchiveProject }
import from ...services.roster.roster { AddRepo, RemoveRepo }
import from ...components.projects.ProjectTable { ProjectTable }
import from ...components.projects.ProjectDialog { ProjectDialog }
import from ...components.ui.button { Button }
import from ...components.ui.skeleton { Skeleton }
import from ..common.Reveal { Reveal }
import from .SectionHeader { SectionHeader }
import from .ConfirmDialog { ConfirmDialog }
import from .icons { IconPlus }
import from "sonner" { toast }

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
    parts = [
        p
        for p in cleaned.split("/")
        if p
    ];
    if len(parts) >= 2 {
        return parts[0] + "/" + parts[1];
    }
    return cleaned;
}

def:pub ProjectsSection(
    members: list[MemberView] = [],
    projects: list[Project] = [],
    repos: list[RepoView] = [],
    loading: bool = False,
    onChanged: Callable[[], any] = None
) -> JsxElement {
    has dialogOpen: bool = False,
        editingId: str = "",
        fName: str = "",
        fDescription: str = "",
        fRepoDraft: str = "",
        archiveId: str = "",
        archiveName: str = "",
        busy: bool = False,
        saving: bool = False;

    async def refresh -> None;
    async def removeRepo(repoId: str) -> None;
    async def saveProject -> None;
    async def archiveProject -> None;
    def openCreate -> None;
    def openEdit(p: Project) -> None;
    def askArchive(p: Project) -> None;

    active = [
        p
        for p in projects
        if p.active
    ];
    # Open work per project from the tallies kept on every task write.
    openCounts: dict[str, int] = {};
    for p in projects {
        openCounts[jid(p)] = p.task_total - p.done_total;
    }
    # The GitHub sync never checks `active`, so an archived project with a
    # linked repository still receives issues; the confirm says so.
    linkedRepos: list[str] = [];
    autoRepos: list[str] = [];
    for r in repos {
        if archiveId and r.project_id == archiveId {
            linkedRepos.append(r.full_name);
            if r.auto_sync {
                autoRepos.append(r.full_name);
            }
        }
    }
    archiveBody = "It leaves the project pickers, so no one can pick it for a new task. Its tasks, log entries and repositories keep pointing at it.";
    if len(autoRepos) > 0 {
        archiveBody = archiveBody
            + " Import issues is on for "
            + ", ".join(autoRepos)
            + ", so GitHub keeps adding new issues to it until you turn that off.";
    } elif len(linkedRepos) > 0 {
        archiveBody = archiveBody
            + " Issues you import from "
            + ", ".join(linkedRepos)
            + " still land in it.";
    }

    def loadFrame -> JsxElement {
        return
            <ProjectTable
                projects={[]}
                repos={[]}
                members={[]}
                openCounts={{}}
                countsReady={False}
                onEdit={openEdit}
                onArchive={askArchive}
                placeholder={3}
            />;
    }

    return
        <div className="flex flex-col gap-4">
            <SectionHeader title="Projects" count={"" if loading else str(len(active))}>
                <Button size="sm" onClick={openCreate}>
                    <IconPlus/>
                    New project
                </Button>
            </SectionHeader>
            <Reveal ready={not loading} frame={loadFrame()}>
                <div key="rows">
                    <ProjectTable
                        projects={active}
                        repos={repos}
                        members={members}
                        openCounts={openCounts}
                        countsReady={not loading}
                        onEdit={openEdit}
                        onArchive={askArchive}
                        onCreate={openCreate}
                    />
                </div>
            </Reveal>
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
                repos={[
                    r
                    for r in repos
                    if editingId and r.project_id == editingId
                ]}
                repoDraft={fRepoDraft}
                onRepoDraft={lambda (v: str) { fRepoDraft = v; }}
                onRemoveRepo={removeRepo}
            />
            <ConfirmDialog
                open={bool(archiveId)}
                title={"Archive " + archiveName + "?"}
                body={archiveBody}
                confirmLabel="Archive project"
                busy={busy}
                onConfirm={archiveProject}
                onOpenChange={lambda (o: bool) { if not o { archiveId = ""; }}}
            />
        </div>;
}
