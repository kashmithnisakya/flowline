"""standup - Workspace (/workspace): everything you configure, in one place.

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
import from ...lib.session { fetchOrgName }
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

def:pub WorkspacePage() -> JsxPage {
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
        orgName: str = "",
        # The header owns each tab's primary action, but Projects and GitHub
        # keep their own state. Bumping a counter is how the header reaches
        # in without the page having to own their dialogs too.
        projectsNonce: int = 0,
        githubNonce: int = 0,
        saving: bool = False;

    async can with entry {
        # Deep links land on the right tab: /workspace?tab=github is where the
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
        loadOrgName();
    }

    async def loadAll -> None;
    async def loadOrgName -> None;
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

    # The header carries one primary action at a time, swapping with the tab.
    # The nav is a vertical rail: Tabs lays out as a row when orientation is
    # vertical, and the line variant moves the active indicator to the rail
    # edge rather than underlining a horizontal strip.
    return <div className="mx-auto flex max-w-6xl flex-col gap-8">
        <div className="flex items-start justify-between gap-6">
            <div className="flex flex-col gap-2">
                <h1 className="font-display text-3xl font-semibold tracking-tight">
                    Workspace
                </h1>
                <p className="text-sm text-muted-foreground">
                    {
                        (orgName + " — organization, projects, people, vocabulary and "
                            + "GitHub, configured in one place.")
                        if orgName
                        else "Organization, projects, people, vocabulary and GitHub, configured in one place."
                    }
                </p>
            </div>
            <div className="flex shrink-0 items-center gap-2">
                {if tab == "projects" {
                    <Button key="np" onClick={lambda { projectsNonce = projectsNonce + 1; }}>
                        New project
                    </Button>
                } elif tab == "people" {
                    <Button key="am" onClick={openCreate}>Add member</Button>
                } elif tab == "github" {
                    <Button key="br" onClick={lambda { githubNonce = githubNonce + 1; }}>
                        Browse GitHub repos
                    </Button>
                }}
            </div>
        </div>

        <Tabs value={tab} onValueChange={selectTab} orientation="vertical">
            <div className="w-44 shrink-0">
                <TabsList variant="line">
                    {for entry in TABS {
                        <TabsTrigger key={entry[0]} value={entry[0]}>{entry[1]}</TabsTrigger>
                    }}
                </TabsList>
            </div>

            <TabsContent value="organization">
                <div className="max-w-2xl">
                    <OrganizationSection />
                </div>
            </TabsContent>

            <TabsContent value="projects">
                <ProjectsSection openNonce={projectsNonce} />
            </TabsContent>

            <TabsContent value="people" className="flex flex-col gap-4">
                <p className="text-sm text-muted-foreground">
                    {str(len(active)) + " on the roster. They are records, not accounts."}
                </p>
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

            <TabsContent value="vocabulary" className="flex flex-col gap-4">
                <p className="text-sm text-muted-foreground">
                    Categories and tags are defined per organization. The board, the
                    log and the roster all pick from these two lists.
                </p>
                <div className="grid items-start gap-6 md:grid-cols-2">
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

            <TabsContent value="github">
                <GithubSection openNonce={githubNonce} />
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
