"""standup - Workspace page: roster, project assignment, vocabulary."""

import from ...models { Project, MemberView, VocabTerm }
import from ...walkers.roster { ListMembers, SaveMember, ArchiveMember }
import from ...walkers.projects {
    ListProjects, AssignToProject, UnassignFromProject
}
import from ...walkers.vocab { ListVocab, AddVocab, RemoveVocab }
import from ...components.roster.MemberTable { MemberTable }
import from ...components.roster.MemberDialog { MemberDialog }
import from ...components.roster.VocabPanel { VocabPanel }
import from ...components.ui.button { Button }
import from ...components.ui.skeleton { Skeleton }
import from "sonner" { toast }

glob BLANK_MEMBER: dict[str, str] = {
    "name": "", "email": "", "github": "", "roleDraft": ""
};

def:pub RosterPage() -> JsxPage {
    has members: list[MemberView] = [],
        projects: list[Project] = [],
        vocab: list[VocabTerm] = [],
        loading: bool = True,
        dialogOpen: bool = False,
        editingId: str = "",
        form: dict[str, str] = BLANK_MEMBER,
        mRoles: list[str] = [],
        mTags: list[str] = [],
        mProjects: list[str] = [],
        newCategory: str = "",
        newTag: str = "",
        saving: bool = False;

    async can with entry {
        loadAll();
    }

    async def loadAll -> None;
    async def saveMember -> None;
    async def archiveMember(memberId: str) -> None;
    async def assignTo(memberId: str, projectId: str) -> None;
    async def unassignFrom(memberId: str, projectName: str) -> None;
    async def addVocab(kind: str) -> None;
    async def removeVocab(termId: str) -> None;
    def setField(key: str, value: str) -> None;
    def addRole -> None;
    def removeRole(role: str) -> None;
    def toggleTag(tag: str) -> None;
    def toggleProject(projectId: str) -> None;
    def openCreate -> None;
    def openEdit(m: MemberView) -> None;

    active = [m for m in members if m.active];
    activeProjects = [p for p in projects if p.active];
    customCategories = [t for t in vocab if t.kind == "category"];
    customTags = [t for t in vocab if t.kind == "tag"];
    allTags = [t.value for t in customTags];

    <div className="space-y-8">
        <div className="flex items-center justify-between">
            <div>
                <h1 className="font-display text-2xl font-bold tracking-tight">Workspace</h1>
                <p className="text-sm text-muted-foreground">
                    {len(active)} team members, plus the vocabulary your board and logs use.
                </p>
            </div>
            <Button onClick={openCreate}>Add member</Button>
        </div>

        <div className="grid gap-6 lg:grid-cols-3 lg:items-start">
            <div className="lg:col-span-2">
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
            </div>
            <VocabPanel
                customCategories={customCategories}
                customTags={customTags}
                newCategory={newCategory}
                newTag={newTag}
                onNewCategory={lambda (v: str) { newCategory = v; }}
                onNewTag={lambda (v: str) { newTag = v; }}
                onAdd={addVocab}
                onRemove={removeVocab}
            />
        </div>

        <MemberDialog
            open={dialogOpen}
            editing={bool(editingId)}
            form={form}
            roles={mRoles}
            memberTags={mTags}
            allTags={allTags}
            projects={activeProjects}
            selectedProjectIds={mProjects}
            saving={saving}
            onField={setField}
            onAddRole={addRole}
            onRemoveRole={removeRole}
            onToggleTag={toggleTag}
            onToggleProject={toggleProject}
            onOpenChange={lambda (o: bool) { dialogOpen = o; }}
            onSave={saveMember}
        />
    </div>
}
