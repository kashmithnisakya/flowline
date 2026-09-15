"""flowline - Workspace (/workspace): everything you configure, in one frame.
A rail of sections (organization, people, projects, roles, preferences) beside
one content column; /settings redirects here for preferences and GitHub lives
at /github, so old ?tab=github links forward there."""

import from "@jac/runtime" { useLocation }
import from "react" { useEffect }
import from ...models { Project, MemberView, RoleView }
import from ...lib.session { fetchOrgName }
import from ...services.roster.roster {
    ListMembers,
    SaveMember,
    ListRoles,
    SetMemberRoles,
    ArchiveMember
}
import from ...services.projects.projects {
    ListProjects,
    AssignToProject,
    UnassignFromProject
}
import from ...components.roster.MemberTable { MemberTable }
import from ...components.roster.MemberDialog { MemberDialog }
import from ...components.workspace.ConfirmDialog { ConfirmDialog }
import from ...components.workspace.OrganizationSection { OrganizationSection }
import from ...components.workspace.PreferencesSection { PreferencesSection }
import from ...components.workspace.ProjectsSection { ProjectsSection }
import from ...components.workspace.RolesSection { RolesSection }
import from ...components.workspace.SectionHeader { SectionHeader }
import from ...components.workspace.WorkspaceRail { WorkspaceRail }
import from ...components.workspace.icons { IconPlus, IconSearch }
import from ...components.ui.button { Button }
import from ...components.ui.input { Input }
import from ...components.ui.skeleton { Skeleton }
import from "sonner" { toast }

glob BLANK_MEMBER: dict[str, str] = {
         "first_name": "",
         "last_name": "",
         "email": "",
         "github": "",
         "color": "",
         "roleDraft": "",
         "tagDraft": ""
     },
     TABS: list[list[str]] = [
         ["organization", "Organization"],
         ["people", "People"],
         ["projects", "Projects"],
         ["roles", "Roles"],
         ["preferences", "Preferences"]
     ];

# The section a URL asks for, "" when it names none we know.
def tabFromSearch(search: str) -> str {
    w: any = window;
    params: any = new(w.URLSearchParams, search);
    wanted = params.get("tab") or "";
    for item in TABS {
        if item[0] == wanted {
            return wanted;
        }
    }
    return "";
}

def initialTab -> str {
    w: any = window;
    return tabFromSearch(str(w.location.search)) or "organization";
}

def:pub WorkspacePage -> JsxPage {
    has members: list[MemberView] = [],
        projects: list[Project] = [],
        roles: list[RoleView] = [],
        orgName: str = "",
        loading: bool = True,
        # Read during the first render, so the deep-linked section paints
        # straight away instead of flipping after an effect.
        tab: str = initialTab(),
        query: str = "",
        dialogOpen: bool = False,
        editingId: str = "",
        form: dict[str, str] = BLANK_MEMBER,
        mRoles: list[str] = [],
        mTags: list[str] = [],
        mProjects: list[str] = [],
        archiveId: str = "",
        archiveName: str = "",
        archiving: bool = False,
        saving: bool = False;

    location = useLocation();

    async can with entry {
        # GitHub lives at /github now, so github tab links and App-install
        # round trips forward there, query intact.
        w: any = window;
        params: any = new(w.URLSearchParams, w.location.search);
        if params.get("tab") == "github" or params.get("installation_id") {
            w.location.replace("/github" + str(w.location.search));
            return;
        }
        loadAll();
    }

    # A link from the account menu (or anywhere else) can ask for another
    # section without remounting the page; rail clicks only rewrite the URL,
    # so they never come back through here.
    useEffect(
        lambda {
            wanted = tabFromSearch(str(location.search));
            if wanted and wanted != tab {
                tab = wanted;
            }
        },
        [location.key]
    );

    async def loadAll -> None;
    async def saveMember -> None;
    async def archiveMember -> None;
    async def applyRoles(memberId: str, next: list[str], undoable: bool) -> None;
    async def applyProjects(memberId: str, next: list[str], undoable: bool) -> None;
    def setField(key: str, value: str) -> None;
    def addRole -> None;
    def addTag -> None;
    def toggleRoleOption(role: str) -> None;
    def removeRole(role: str) -> None;
    def toggleTag(tag: str) -> None;
    def toggleProject(projectId: str) -> None;
    def openCreate -> None;
    def openEdit(m: MemberView) -> None;
    def askArchive(m: MemberView) -> None;
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
    roleOptions: list[str] = [];
    for r in roles {
        roleOptions.append(r.name);
    }
    for m in active {
        for held in m.roles {
            if held not in roleOptions {
                roleOptions.append(held);
            }
        }
    }
    # Name, role or project, matched on the client: the roster is a whole
    # list already, so a search needs no round trip.
    needle = query.strip().lower();
    shown = active;
    if needle {
        hits: list[MemberView] = [];
        for m in active {
            hay = m.name + " " + " ".join(m.roles) + " " + " ".join(m.project_names);
            if needle in hay.lower() {
                hits.append(m);
            }
        }
        shown = hits;
    }
    counts: dict[str, str] = {
        "people": str(len(active)),
        "projects": str(len(activeProjects)),
        "roles": str(len(roleOptions))
    };
    items: list[dict[str, str]] = [];
    for item in TABS {
        items.append(
            {
                "key": item[0],
                "label": item[1],
                "count": (counts[item[0]] if item[0] in counts else "")
                    if not loading
                    else ""
            }
        );
    }

    return
        <div className="w-full">
            <div
                className="grid grid-cols-[minmax(0,1fr)] gap-4 md:grid-cols-[190px_minmax(0,1fr)] md:gap-0"
            >
                <div className="min-w-0 md:border-r md:pr-3">
                    <WorkspaceRail
                        orgName={orgName}
                        items={items}
                        current={tab}
                        onSelect={selectTab}
                    />
                </div>
                <div className="min-w-0 md:pl-8">
                    <div className="flex max-w-[880px] flex-col gap-4">
                        {if tab == "organization" {
                            <OrganizationSection
                                key="organization"
                                onRenamed={lambda (name: str) { orgName = name; }}
                            />
                        } elif tab == "people" {
                            <div key="people" className="flex flex-col gap-4">
                                <SectionHeader
                                    title="People"
                                    count={"" if loading else str(len(active))}
                                >
                                    {if len(active) > 0 {
                                        <div
                                            key="find"
                                            className="relative min-w-0 flex-1 sm:w-48 sm:flex-none"
                                        >
                                            <IconSearch
                                                className="pointer-events-none absolute top-1/2 left-2.5 -translate-y-1/2 text-subtle"
                                            />
                                            <Input
                                                className="h-8 pl-8"
                                                placeholder="Find a person"
                                                aria-label="Find a person"
                                                value={query}
                                                onChange={lambda (e: ChangeEvent) { query = e.target.value; }}
                                            />
                                        </div>
                                    }}
                                    <Button size="sm" onClick={openCreate}>
                                        <IconPlus/>
                                        Add person
                                    </Button>
                                </SectionHeader>
                                {if loading {
                                    <div
                                        key="sk"
                                        className="surface flex flex-col divide-y"
                                    >
                                        {for i in [0, 1, 2, 3] {
                                            <div
                                                key={"r" + str(i)}
                                                className="flex items-center gap-3 px-3 py-3"
                                            >
                                                <Skeleton
                                                    className="h-6 w-6 shrink-0 rounded-full"
                                                />
                                                <Skeleton
                                                    className="h-4 w-36 max-w-full"
                                                />
                                                <Skeleton
                                                    className="ml-auto h-4 w-24 max-w-full"
                                                />
                                            </div>
                                        }}
                                    </div>
                                } else {
                                    <MemberTable
                                        key="table"
                                        members={shown}
                                        projects={activeProjects}
                                        roleOptions={roleOptions}
                                        query={query.strip()}
                                        showTags={len(allTags) > 0}
                                        onEdit={openEdit}
                                        onArchive={askArchive}
                                        onCreate={openCreate}
                                        onRoles={lambda (
                                            memberId: str, next: list[str]
                                        ) { applyRoles(memberId, next, True); }}
                                        onProjects={lambda (
                                            memberId: str, next: list[str]
                                        ) { applyProjects(memberId, next, True); }}
                                        onManageRoles={lambda { selectTab("roles"); }}
                                        onManageProjects={lambda { selectTab(
                                            "projects"
                                        ); }}
                                    />
                                } }
                            </div>
                        } elif tab == "projects" {
                            <ProjectsSection
                                key="projects"
                                members={active}
                                onChanged={loadAll}
                            />
                        } elif tab == "roles" {
                            <RolesSection
                                key="roles"
                                onChanged={loadAll}
                                onPeople={lambda { selectTab("people"); }}
                            />
                        } else {
                            <PreferencesSection key="preferences"/>
                        }    }
                    </div>
                </div>
            </div>
            <MemberDialog
                open={dialogOpen}
                editing={bool(editingId)}
                form={form}
                roles={mRoles}
                roleOptions={roleOptions}
                memberTags={mTags}
                allTags={allTags}
                projects={activeProjects}
                selectedProjectIds={mProjects}
                saving={saving}
                onField={setField}
                onAddRole={addRole}
                onAddTag={addTag}
                onToggleRole={toggleRoleOption}
                onRemoveRole={removeRole}
                onToggleTag={toggleTag}
                onToggleProject={toggleProject}
                onOpenChange={lambda (o: bool) { dialogOpen = o; }}
                onSave={saveMember}
            />
            <ConfirmDialog
                open={bool(archiveId)}
                title={"Archive " + archiveName + "?"}
                body="They leave the roster and every open task they are on. Done tasks and log entries keep their name."
                confirmLabel="Archive person"
                busy={archiving}
                onConfirm={archiveMember}
                onOpenChange={lambda (o: bool) { if not o { archiveId = ""; }}}
            />
        </div>;
}
