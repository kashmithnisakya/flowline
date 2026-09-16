"""Projects as rows: what the project is, the repository its issues come from,
who is on it and how much work is still open. One markup for every width; the
columns fold into a meta line on a phone.
"""

import from ...models { Project, RepoView, MemberView }
import from ..common.Avatar { AvatarStack }
import from ..workspace.RowActions { RowActions }

def:pub ProjectTable(
    projects: list[Project],
    repos: list[RepoView],
    members: list[MemberView],
    openCounts: dict[str, int],
    countsReady: bool,
    onEdit: Callable[[Project], None],
    onArchive: Callable[[Project], None],
    onCreate: Callable[[], None] = None
) -> JsxElement {
    if len(projects) == 0 {
        return
            <div
                className="surface flex flex-col items-center gap-2 px-6 py-12 text-center"
            >
                <p className="text-sm font-semibold">No projects yet</p>
                <p className="max-w-sm text-sm text-muted-foreground">
                    Tasks, log entries and repositories all belong to a project.
                </p>
            </div>;
    }

    return
        <div className="surface">
            <div
                className="hidden grid-cols-[minmax(0,1.5fr)_minmax(0,1fr)_96px_72px_40px] items-center gap-x-4 border-b px-3 py-2 text-[12.5px] text-muted-foreground md:grid"
            >
                <span>Project</span>
                <span>Repository</span>
                <span>People</span>
                <span className="text-right">Open</span>
                <span/>
            </div>
            <ul className="divide-y">
                {for p in projects {
                    <li
                        key={jid(p)}
                        className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-x-4 gap-y-1 px-3 py-2.5 transition-colors duration-150 hover:bg-accent md:grid-cols-[minmax(0,1.5fr)_minmax(0,1fr)_96px_72px_40px] md:py-2"
                    >
                        <div className="col-start-1 row-start-1 min-w-0">
                            <div
                                className="truncate text-sm font-medium md:text-[13.5px]"
                            >
                                {p.name}
                            </div>
                            {if p.description {
                                <div
                                    key="desc"
                                    className="truncate text-xs text-muted-foreground"
                                >
                                    {p.description}
                                </div>
                            }}
                        </div>
                        <div
                            className="col-start-1 row-start-2 flex min-w-0 flex-wrap items-center gap-x-3 gap-y-1 md:contents"
                        >
                            <div className="min-w-0 md:col-start-2">
                                {for r in [
                                    x
                                    for x in repos
                                    if x.project_id == jid(p)
                                ] {
                                    <a
                                        key={r.id}
                                        href={"https://github.com/" + r.full_name}
                                        target="_blank"
                                        rel="noreferrer"
                                        className="num block truncate text-[12.5px] text-muted-foreground underline-offset-2 hover:text-foreground hover:underline"
                                    >
                                        {r.full_name}
                                    </a>
                                }}
                                {if len(
                                    [
                                        x
                                        for x in repos
                                        if x.project_id == jid(p)
                                    ]
                                )
                                    == 0 {
                                    <button
                                        key="link"
                                        type="button"
                                        className="text-[12.5px] text-muted-foreground underline-offset-2 hover:text-foreground hover:underline"
                                        onClick={lambda { onEdit(p); }}
                                    >
                                        Link a repository
                                    </button>
                                }}
                            </div>
                            <div className="md:col-start-3">
                                <AvatarStack
                                    names={[
                                        m.name
                                        for m in members
                                        if jid(p) in m.project_ids
                                    ]}
                                    max={3}
                                />
                            </div>
                            <div
                                className="num text-[12.5px] text-muted-foreground md:col-start-4 md:text-right md:text-[13px]"
                            >
                                {(
                                    str(
                                        openCounts[jid(p)]
                                            if jid(p) in openCounts
                                            else 0
                                    )
                                    + " open"
                                )
                                    if countsReady
                                    else ""}
                            </div>
                        </div>
                        <div
                            className="col-start-2 row-span-2 row-start-1 justify-self-end md:col-start-5 md:row-span-1"
                        >
                            <RowActions
                                label={"Actions for " + p.name}
                                onEdit={lambda { onEdit(p); }}
                                onDanger={lambda { onArchive(p); }}
                            />
                        </div>
                    </li>
                }}
            </ul>
        </div>;
}
