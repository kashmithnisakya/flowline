"""standup - Workspace (/roster): everything you configure, in one place.

Five tabs, all of them CRUD over settings rather than daily work: the
organization's own name, the projects work is scoped to, the people on the
roster, the vocabulary the board and logs use, and the GitHub connection.
Projects and GitHub used to be their own routes; they are sections here now,
which is what keeps the nav to the five things you actually do each day.

The page is a thin shell: each tab is a self-contained section component
that loads and saves its own data, so switching tabs costs nothing and no
section can break another. The People and Vocabulary tabs are the exception,
because they share the member/vocabulary loads.
"""

import from ...models { Project, MemberView, VocabTerm }
import from ...walkers.roster { ListMembers, SaveMember, ArchiveMember }
import from ...walkers.projects {
    ListProjects, AssignToProject, UnassignFromProject
}
import from ...walkers.vocab { ListVocab, AddVocab, RemoveVocab }
import from ...components.roster.MemberTable { MemberTable }
import from ...components.roster.MemberDialog { MemberDialog }
import from ...components.roster.VocabPanel { VocabPanel }
import from ...components.workspace.OrganizationSection { OrganizationSection }
import from ...components.workspace.ProjectsSection { ProjectsSection }
import from ...components.workspace.GithubSection { GithubSection }
import from ...components.ui.button { Button }
import from ...components.ui.skeleton { Skeleton }
import from ...components.ui.tabs { Tabs, TabsList, TabsTrigger, TabsContent }
import from "sonner" { toast }

glob BLANK_MEMBER: dict[str, str] = {
    "name": "", "email": "", "github": "", "roleDraft": ""
};

glob TABS: list[list[str]] = [
    ["organization", "Organization"],
    ["projects", "Projects"],
    ["people", "People"],
    ["vocabulary", "Vocabulary"],
    ["github", "GitHub"]
];

def:pub RosterPage() -> JsxPage {
    has members: list[MemberView] = [],
        projects: list[Project] = [],
        vocab: list[VocabTerm] = [],
        loading: bool = True,
        tab: str = "organization",
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
        # Deep links land on the right tab: /roster?tab=github is where the
        # GitHub App's install round trip comes back to, and the old
        # /projects route redirects here with ?tab=projects.
        w: any = window;
        params: any = new(w.URLSearchParams, w.location.search);
        wanted = params.get("tab") or "";
        known: list[str] = [];
        for entry in TABS {
            known.append(entry[0]);
        }
        if wanted in known {
            tab = wanted;
        } elif params.get("installation_id") {
            tab = "github";
        }
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
    def selectTab(value: str) -> None;

    active = [m for m in members if m.active];
    activeProjects = [p for p in projects if p.active];
    customCategories = [t for t in vocab if t.kind == "category"];
    customTags = [t for t in vocab if t.kind == "tag"];
    allTags = [t.value for t in customTags];

    return <div className="space-y-6">
        <div>
            <h1 className="font-display text-2xl font-bold tracking-tight">Workspace</h1>
            <p className="text-sm text-muted-foreground">
                Everything you configure: your organization, projects, people, the
                vocabulary your board and logs use, and GitHub.
            </p>
        </div>

        <Tabs value={tab} onValueChange={selectTab}>
            <TabsList>
                {for entry in TABS {
                    <TabsTrigger key={entry[0]} value={entry[0]}>{entry[1]}</TabsTrigger>
                }}
            </TabsList>

            <TabsContent value="organization" className="pt-4">
                <OrganizationSection />
            </TabsContent>

            <TabsContent value="projects" className="pt-4">
                <ProjectsSection />
            </TabsContent>

            <TabsContent value="people" className="space-y-4 pt-4">
                <div className="flex items-center justify-between">
                    <p className="text-sm text-muted-foreground">
                        {str(len(active)) + " on the roster. They are records, not accounts."}
                    </p>
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
            </TabsContent>

            <TabsContent value="vocabulary" className="pt-4">
                <div className="grid gap-6 lg:grid-cols-2 lg:items-start">
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
            </TabsContent>

            <TabsContent value="github" className="pt-4">
                <GithubSection />
            </TabsContent>
        </Tabs>

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
    </div>;
}
