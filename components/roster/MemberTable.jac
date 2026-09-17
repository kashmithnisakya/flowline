"""The roster: one row per person, with roles and projects assigned in the row
through checkbox menus. A fixed-layout table at md and up, so a long list of
picks truncates instead of widening the column; a two-line list on a phone.
"""

import from ...models { Project, MemberView }
import from ..common.Avatar { Avatar }
import from ..workspace.RowActions { RowActions }
import from ..ui.skeleton { Skeleton }
import from .AssignMenu { AssignMenu }

def:pub MemberTable(
    members: list[MemberView],
    projects: list[Project],
    roleOptions: list[str],
    onEdit: Callable[[MemberView], None],
    onArchive: Callable[[MemberView], None],
    onRoles: Callable[[str, list[str]], any],
    onProjects: Callable[[str, list[str]], any],
    onManageRoles: Callable[[], None],
    onManageProjects: Callable[[], None],
    onCreate: Callable[[], None] = None,
    showTags: bool = False,
    query: str = "",
    # The first load: this many skeleton rows under the real header, at the
    # real row height, instead of the empty state.
    placeholder: int = 0
) -> JsxElement {
    projectIds: list[str] = [];
    projectNames: list[str] = [];
    for p in projects {
        projectIds.append(jid(p));
        projectNames.append(p.name);
    }

    if len(members) == 0 and placeholder == 0 {
        return
            <div
                className="surface flex flex-col items-center gap-2 px-6 py-12 text-center"
            >
                <p className="text-sm font-semibold">
                    {"No one matches that search" if query else "No people yet"}
                </p>
                <p className="max-w-sm text-sm text-muted-foreground">
                    {"Try another name, role or project."
                        if query
                        else "People do not need an account. Add them to assign work and sign log entries."}
                </p>
            </div>;
    }

    return
        <div className="flex flex-col gap-3" aria-busy={placeholder > 0}>
            <div className="surface hidden md:block">
                <table className="data-table table-fixed">
                    <thead>
                        <tr>
                            <th className={"w-[28%]" if showTags else "w-[34%]"}>
                                Name
                            </th>
                            <th className={"w-[24%]" if showTags else "w-[28%]"}>
                                Roles
                            </th>
                            <th className={"w-[22%]" if showTags else ""}>Projects</th>
                            {if showTags {
                                <th key="tags" className="hidden lg:table-cell">
                                    Tags
                                </th>
                            }}
                            <th className="relative w-12">
                                <span className="sr-only">Actions</span>
                            </th>
                        </tr>
                    </thead>
                    <tbody>
                        {for i in range(placeholder) {
                            <tr key={"ph" + str(i)}>
                                <td>
                                    <div className="flex min-w-0 items-center gap-2.5">
                                        <Skeleton
                                            className="size-6 shrink-0 rounded-full"
                                        />
                                        <div className="min-w-0">
                                            <div className="flex h-5 items-center">
                                                <Skeleton
                                                    className={"h-3.5 "
                                                        + ("w-24" if i % 2 else "w-32")}
                                                />
                                            </div>
                                            <div className="flex h-4 items-center">
                                                <Skeleton className="h-3 w-44"/>
                                            </div>
                                        </div>
                                    </div>
                                </td>
                                <td>
                                    <Skeleton className="h-3.5 w-28"/>
                                </td>
                                <td>
                                    <Skeleton className="h-3.5 w-36"/>
                                </td>
                                {if showTags {
                                    <td key="tags" className="hidden lg:table-cell">
                                        <Skeleton className="h-3.5 w-20"/>
                                    </td>
                                }}
                                <td className="text-right"/>
                            </tr>
                        }}
                        {for m in members {
                            <tr key={m.id}>
                                <td>
                                    <div className="flex min-w-0 items-center gap-2.5">
                                        <Avatar
                                            name={m.name}
                                            size="sm"
                                            color={m.color}
                                        />
                                        <div className="min-w-0">
                                            <div className="truncate font-medium">
                                                {m.name}
                                            </div>
                                            {if m.email or m.github_username {
                                                <div
                                                    key="contact"
                                                    className="truncate text-xs text-muted-foreground"
                                                    title={m.email}
                                                >
                                                    {m.email}
                                                    {" · "
                                                        if (
                                                            m.email
                                                            and m.github_username
                                                        )
                                                        else ""}
                                                    {if m.github_username {
                                                        <span key="gh" className="num">
                                                            {"@" + m.github_username}
                                                        </span>
                                                    }}
                                                </div>
                                            }}
                                        </div>
                                    </div>
                                </td>
                                <td>
                                    <AssignMenu
                                        label={"Roles for " + m.name}
                                        values={roleOptions}
                                        names={roleOptions}
                                        selected={m.roles}
                                        emptyText="Add role"
                                        noneText="No roles in this workspace yet"
                                        footerLabel="Manage roles"
                                        onFooter={onManageRoles}
                                        onCommit={lambda (next: list[str]) { onRoles(
                                            m.id, next
                                        ); }}
                                    />
                                </td>
                                <td>
                                    <AssignMenu
                                        label={"Projects for " + m.name}
                                        values={projectIds}
                                        names={projectNames}
                                        selected={m.project_ids}
                                        emptyText="Add project"
                                        noneText="No projects yet"
                                        footerLabel="Manage projects"
                                        onFooter={onManageProjects}
                                        onCommit={lambda (next: list[str]) { onProjects(
                                            m.id, next
                                        ); }}
                                    />
                                </td>
                                {if showTags {
                                    <td
                                        key="tags"
                                        className="hidden truncate text-muted-foreground lg:table-cell"
                                    >
                                        {", ".join(m.tags)}
                                    </td>
                                }}
                                <td className="text-right">
                                    <RowActions
                                        label={"Actions for " + m.name}
                                        onEdit={lambda { onEdit(m); }}
                                        onDanger={lambda { onArchive(m); }}
                                    />
                                </td>
                            </tr>
                        }}
                    </tbody>
                </table>
            </div>
            <ul className="surface divide-y md:hidden">
                {for i in range(placeholder) {
                    <li
                        key={"ph" + str(i)}
                        className="flex items-start gap-3 px-3 py-2.5"
                    >
                        <Skeleton className="size-8 shrink-0 rounded-full"/>
                        <div className="flex min-w-0 flex-1 flex-col gap-0.5">
                            <div className="flex h-5 items-center">
                                <Skeleton className="h-3.5 w-32"/>
                            </div>
                            <div className="flex h-5 items-center gap-3">
                                <Skeleton className="h-3 w-20"/>
                                <Skeleton className="h-3 w-24"/>
                            </div>
                        </div>
                    </li>
                }}
                {for m in members {
                    <li key={m.id} className="flex items-start gap-3 px-3 py-2.5">
                        <Avatar name={m.name} size="md" color={m.color}/>
                        <div className="flex min-w-0 flex-1 flex-col gap-0.5">
                            <div className="truncate text-sm font-medium">{m.name}</div>
                            <div
                                className="flex min-w-0 flex-wrap items-center gap-x-3"
                            >
                                <AssignMenu
                                    label={"Roles for " + m.name}
                                    values={roleOptions}
                                    names={roleOptions}
                                    selected={m.roles}
                                    emptyText="Add role"
                                    noneText="No roles in this workspace yet"
                                    footerLabel="Manage roles"
                                    onFooter={onManageRoles}
                                    onCommit={lambda (next: list[str]) { onRoles(
                                        m.id, next
                                    ); }}
                                />
                                <AssignMenu
                                    label={"Projects for " + m.name}
                                    values={projectIds}
                                    names={projectNames}
                                    selected={m.project_ids}
                                    emptyText="Add project"
                                    noneText="No projects yet"
                                    footerLabel="Manage projects"
                                    onFooter={onManageProjects}
                                    onCommit={lambda (next: list[str]) { onProjects(
                                        m.id, next
                                    ); }}
                                />
                            </div>
                        </div>
                        <RowActions
                            label={"Actions for " + m.name}
                            onEdit={lambda { onEdit(m); }}
                            onDanger={lambda { onArchive(m); }}
                        />
                    </li>
                }}
            </ul>
        </div>;
}
