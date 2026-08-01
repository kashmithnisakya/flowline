"""standup - People page: org roster, project assignment, GitHub repos."""

import from ...models { Project, MemberView, Repo }
import from ...walkers.roster {
    ListMembers, SaveMember, ArchiveMember, ListRepos, AddRepo, RemoveRepo
}
import from ...walkers.projects {
    ListProjects, AssignToProject, UnassignFromProject
}
import from ...components.roster.MemberTable { MemberTable }
import from ...components.roster.MemberDialog { MemberDialog }
import from ...components.roster.RepoManager { RepoManager }
import from ...components.ui.button { Button }
import from ...components.ui.skeleton { Skeleton }
import from "sonner" { toast }

glob BLANK_MEMBER: dict[str, str] = {
    "name": "", "role": "", "email": "", "github": "", "section": ""
};

def:pub RosterPage() -> JsxPage {
    has members: list[MemberView] = [],
        projects: list[Project] = [],
        repos: list[Repo] = [],
        loading: bool = True,
        dialogOpen: bool = False,
        editingId: str = "",
        form: dict[str, str] = BLANK_MEMBER,
        newRepo: str = "",
        saving: bool = False;

    async can with entry {
        loadAll();
    }

    async def loadAll -> None;
    async def saveMember -> None;
    async def archiveMember(memberId: str) -> None;
    async def assignTo(memberId: str, projectId: str) -> None;
    async def unassignFrom(memberId: str, projectName: str) -> None;
    async def addRepo -> None;
    async def removeRepo(repoId: str) -> None;
    def setField(key: str, value: str) -> None;
    def openCreate -> None;
    def openEdit(m: MemberView) -> None;

    active = [m for m in members if m.active];
    activeProjects = [p for p in projects if p.active];

    <div className="space-y-8">
        <div className="flex items-center justify-between">
            <div>
                <h1 className="text-2xl font-semibold tracking-tight">People</h1>
                <p className="text-sm text-muted-foreground">
                    {len(active)} members — assign them to projects here.
                </p>
            </div>
            <Button onClick={openCreate}>Add member</Button>
        </div>

        {if loading {
            <Skeleton key="sk" className="h-48 w-full" />
        } else {
            <MemberTable key="table"
                members={active}
                projects={activeProjects}
                onEdit={openEdit}
                onArchive={archiveMember}
                onAssign={assignTo}
                onUnassign={unassignFrom}
            />
        }}

        <RepoManager
            repos={repos}
            value={newRepo}
            onChange={lambda (v: str) { newRepo = v; }}
            onAdd={addRepo}
            onRemove={removeRepo}
        />

        <MemberDialog
            open={dialogOpen}
            editing={bool(editingId)}
            form={form}
            saving={saving}
            onField={setField}
            onOpenChange={lambda (o: bool) { dialogOpen = o; }}
            onSave={saveMember}
        />
    </div>
}
