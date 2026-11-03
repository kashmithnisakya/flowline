"""flowline - Workspace (/workspace): every setting on one scrolling page. A rail
of anchors beside the sections as panels, and `?tab=<section>` scrolls to one.
/github renders this page too, since the GitHub App sends its install round trip
there; the GitHub section mounts lazily unless the address asks for it."""

import from "@jac/runtime" { useLocation }
import from "react" { useEffect }
import from ...models {
    Project,
    MemberView,
    RoleView,
    RepoView,
    StepView,
    ResponsibilityView
}
import from ...services.roster.roster {
    ListMembers,
    SaveMember,
    ListRoles,
    SetMemberRoles,
    ArchiveMember
}
import from ...services.projects.projects { AssignToProject, UnassignFromProject }
import from ...services.agents.agents { ListResponsibilities }
import from ...lib.workspace { loadWorkspace, forgetWorkspace }
import from ...components.roster.MemberDialog { MemberDialog }
import from ...components.workspace.ConfirmDialog { ConfirmDialog }
import from ...components.workspace.GithubSlot { GithubSlot }
import from ...components.workspace.OrganizationSection { OrganizationSection }
import from ...components.workspace.PeopleSection { PeopleSection }
import from ...components.workspace.PreferencesSection { PreferencesSection }
import from ...components.workspace.ProjectsSection { ProjectsSection }
import from ...components.workspace.RolesSection { RolesSection }
import from ...components.workspace.SectionSpy { SectionSpy }
import from ...components.workspace.WorkspaceRail { WorkspaceRail }
import from ...components.workspace.sections {
    SECTIONS,
    askedSection,
    asksForGithub,
    currentFromAddress,
    holdSection
}
import from "sonner" { toast }

glob COLUMN_ID: str = "workspace-sections",
     BLANK_MEMBER: dict[str, str] = {
         "first_name": "",
         "last_name": "",
         "email": "",
         "github": "",
         "color": "",
         "roleDraft": "",
         "tagDraft": ""
     };

def:pub WorkspacePage -> JsxPage {
    has members: list[MemberView] = [],
        projects: list[Project] = [],
        roles: list[RoleView] = [],
        # Projects and Roles render from these too: one workspace read on
        # mount, whichever sections the reader scrolls to.
        repos: list[RepoView] = [],
        steps: list[StepView] = [],
        loading: bool = True,
        # Every role's responsibilities, read beside the workspace for the
        # Roles section's chips; only this page shows them here.
        aiItems: list[ResponsibilityView] = [],
        # Moves when a read lands, so the GitHub section's own lists can follow.
        readRound: int = 0,
        # Read during the first render, so the rail and the deep link are right
        # from the first paint.
        current: str = currentFromAddress(),
        githubAsked: bool = asksForGithub(),
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
        loadAll();
    }

    # An address that names a section scrolls to it: on the first load, and
    # when a link elsewhere on this page (the sidebar, the palette) asks for
    # another. Rail clicks only rewrite the URL, so they never come through here.
    useEffect(
        lambda {
            wanted = askedSection(str(location.pathname), str(location.search));
            if wanted {
                current = wanted;
                if wanted == "github" {
                    githubAsked = True;
                }
                holdSection(wanted);
            }
        },
        [location.key]
    );

    async def loadAll -> None;
    async def loadRoster -> None;
    async def loadAi -> None;
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
    def selectSection(value: str) -> None;

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
    for m in active {
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
    memberHandlers: dict[str, any] = {
        "onEdit": openEdit,
        "onArchive": askArchive,
        "onRoles": lambda (memberId: str, next: list[str]) { applyRoles(
            memberId, next, True
        ); },
        "onProjects": lambda (memberId: str, next: list[str]) { applyProjects(
            memberId, next, True
        ); },
        "onManageRoles": lambda { selectSection("roles"); },
        "onManageProjects": lambda { selectSection("projects"); }
    };

    return
        <div className="w-full">
            <div className="flex flex-col gap-4 md:flex-row md:gap-6">
                <WorkspaceRail
                    items={SECTIONS}
                    current={current}
                    onSelect={selectSection}
                />
                <div
                    id={COLUMN_ID}
                    className="flex max-w-[920px] min-w-0 flex-1 flex-col gap-6"
                >
                    <OrganizationSection/>
                    <PeopleSection
                        members={active}
                        projects={activeProjects}
                        roleOptions={roleOptions}
                        showTags={len(allTags) > 0}
                        loading={loading}
                        handlers={memberHandlers}
                        onCreate={openCreate}
                    />
                    <ProjectsSection
                        members={active}
                        projects={projects}
                        repos={repos}
                        loading={loading}
                        onChanged={loadAll}
                    />
                    <RolesSection
                        members={active}
                        roles={roles}
                        steps={steps}
                        loading={loading}
                        onChanged={loadAll}
                        onPeople={lambda { selectSection("people"); }}
                        responsibilities={aiItems}
                    />
                    <GithubSlot
                        wake={githubAsked}
                        syncKey={readRound}
                        onChanged={loadAll}
                    />
                    <PreferencesSection/>
                </div>
            </div>
            <SectionSpy
                column={COLUMN_ID}
                onCurrent={lambda (key: str) { if key != current { current = key; }}}
            />
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
