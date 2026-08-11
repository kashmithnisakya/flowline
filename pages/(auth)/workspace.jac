"""standup - Workspace (/workspace): everything you configure, in one place.

Five tabs, all of them CRUD over settings rather than daily work: the
organization's own name, the projects work is scoped to, the people on the
roster, and the GitHub connection.
Projects and GitHub used to be their own routes; they are sections here now,
which is what keeps the nav to the five things you actually do each day.

The page is a thin shell: each tab is a self-contained section component
that loads and saves its own data, so switching tabs costs nothing and no
section can break another.
"""

import from ...models { Project, MemberView }
import from ...walkers.roster { ListMembers, SaveMember, ArchiveMember }
import from ...walkers.projects { ListProjects, AssignToProject, UnassignFromProject }
import from ...components.roster.MemberTable { MemberTable }
import from ...components.roster.MemberDialog { MemberDialog }
import from ...components.workspace.OrganizationSection { OrganizationSection }
import from ...components.workspace.ProjectsSection { ProjectsSection }
import from ...components.workspace.GithubSection { GithubSection }
import from ...components.ui.button { Button }
import from ...components.ui.skeleton { Skeleton }
import from ...components.ui.tabs { Tabs, TabsList, TabsTrigger, TabsContent }
import from "sonner" { toast }

glob BLANK_MEMBER: dict[str, str] = {
         "name": "",
         "email": "",
         "github": "",
         "roleDraft": "",
         "tagDraft": ""
     },
     TABS: list[list[str]] = [
         ["organization", "Organization"],
         ["projects", "Projects"],
         ["people", "People"],
         ["github", "GitHub"]
     ];

def:pub WorkspacePage -> JsxPage {
    has members: list[MemberView] = [],
        projects: list[Project] = [],
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
    }

    async def loadAll -> None;
    async def saveMember -> None;
    async def archiveMember(memberId: str) -> None;
    async def assignTo(memberId: str, projectId: str) -> None;
    async def unassignFrom(memberId: str, projectName: str) -> None;
    def setField(key: str, value: str) -> None;
    def addRole -> None;
    def addTag -> None;
    def removeRole(role: str) -> None;
    def toggleTag(tag: str) -> None;
    def toggleProject(projectId: str) -> None;
    def openCreate -> None;
    def openEdit(m: MemberView) -> None;
    def selectTab(value: str) -> None;

    active = [
        m
        for m in members
        if m.active
    ];
    activeProjects = [
        p
        for p in projects
        if p.active
    ];
    allTags: list[str] = [];
    for m in members {
        for tag in m.tags {
            if tag not in allTags {
                allTags.append(tag);
            }
        }
    }

    # The header carries one primary action at a time, swapping with the tab.
    # The action slot keeps a fixed height so the h1 row never shifts when a
    # tab without an action (Organization) is selected. The nav is a vertical
    # rail at sm+ (line variant puts the indicator on the rail edge); below sm
    # it collapses to a horizontal segmented strip driven by the same state.
    return
        <div className="flex w-full flex-col gap-8">
            <div className="flex items-center justify-between gap-6">
                <h1 className="page-title">
                    Workspace
                </h1>
                <div className="flex h-9 shrink-0 items-center justify-end gap-2">
                    {if tab == "projects" {
                        <Button
                            key="np"
                            className="animate-in fade-in zoom-in-95 duration-200"
                            onClick={lambda { projectsNonce = projectsNonce + 1; }}
                        >
                            New project
                        </Button>
                    } elif tab == "people" {
                        <Button
                            key="am"
                            className="animate-in fade-in zoom-in-95 duration-200"
                            onClick={openCreate}
                        >
                            Add member
                        </Button>
                    } elif tab == "github" {
                        <Button
                            key="br"
                            className="animate-in fade-in zoom-in-95 duration-200"
                            onClick={lambda { githubNonce = githubNonce + 1; }}
                        >
                            Browse GitHub repos
                        </Button>
                    }  }
                </div>
            </div>
            <Tabs
                value={tab}
                onValueChange={selectTab}
                orientation="vertical"
                className="flex-col gap-6 sm:flex-row sm:gap-8"
            >
                <div className="flex w-full items-center gap-0.5 overflow-x-auto rounded-lg border border-border/70 bg-muted p-0.5 sm:hidden">
                    {for entry in TABS {
                        <button
                            key={"m-" + entry[0]}
                            type="button"
                            className={"flex-1 whitespace-nowrap rounded-md px-2.5 py-1 text-sm font-medium "
                                + (
                                    "bg-background text-foreground shadow-sm"
                                        if tab == entry[0]
                                        else "text-muted-foreground transition-colors hover:text-foreground"
                                )}
                            onClick={lambda { selectTab(entry[0]); }}
                        >
                            {entry[1]}
                        </button>
                    }}
                </div>
                <div className="hidden w-44 shrink-0 sm:block">
                    <TabsList variant="line">
                        {for entry in TABS {
                            <TabsTrigger key={entry[0]} value={entry[0]}>
                                {entry[1]}
                            </TabsTrigger>
                        }}
                    </TabsList>
                </div>
                <TabsContent
                    value="organization"
                    className="animate-in fade-in slide-in-from-bottom-1 duration-200"
                >
                    <div className="max-w-2xl">
                        <OrganizationSection/>
                    </div>
                </TabsContent>
                <TabsContent
                    value="projects"
                    className="animate-in fade-in slide-in-from-bottom-1 duration-200"
                >
                    <ProjectsSection openNonce={projectsNonce}/>
                </TabsContent>
                <TabsContent
                    value="people"
                    className="flex flex-col gap-4 animate-in fade-in slide-in-from-bottom-1 duration-200"
                >
                    <p className="text-sm text-muted-foreground">
                        <span className="tabular-nums">{str(len(active))}</span>
                        {" on the roster. They are records, not accounts."}
                    </p>
                    {if loading {
                        <div
                            key="sk"
                            className="flex flex-col gap-4 rounded-xl border bg-card p-6"
                        >
                            <div className="flex items-center gap-3">
                                <Skeleton className="h-4 w-24"/>
                                <Skeleton className="h-4 w-16"/>
                                <Skeleton className="ml-auto h-4 w-14"/>
                            </div>
                            {for i in [0, 1, 2, 3] {
                                <div
                                    key={"r" + str(i)}
                                    className="flex items-center gap-3"
                                >
                                    <Skeleton className="h-9 w-9 shrink-0 rounded-full"/>
                                    <div className="flex min-w-0 flex-1 flex-col gap-1.5">
                                        <Skeleton className="h-4 w-36 max-w-full"/>
                                        <Skeleton className="h-3 w-24"/>
                                    </div>
                                    <Skeleton className="hidden h-5 w-16 rounded-full sm:block"/>
                                    <Skeleton className="hidden h-5 w-20 rounded-full sm:block"/>
                                </div>
                            }}
                        </div>
                    } else {
                        <MemberTable
                            key="table"
                            members={active}
                            projects={activeProjects}
                            onEdit={openEdit}
                            onArchive={archiveMember}
                            onAssign={assignTo}
                            onUnassign={unassignFrom}
                            onCreate={openCreate}
                        />
                    } }
                </TabsContent>
                <TabsContent
                    value="github"
                    className="animate-in fade-in slide-in-from-bottom-1 duration-200"
                >
                    <GithubSection openNonce={githubNonce}/>
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
                onAddTag={addTag}
                onRemoveRole={removeRole}
                onToggleTag={toggleTag}
                onToggleProject={toggleProject}
                onOpenChange={lambda (o: bool) { dialogOpen = o; }}
                onSave={saveMember}
            />
        </div>;
}
