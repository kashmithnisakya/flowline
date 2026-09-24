"""The board's header: the project line (a picker on phones), the title,
one line of counts, and Sync GitHub and New task on the right."""

import from ...models { Project }
import from ..ui.button { Button }
import from ..common.ProjectLine { ProjectLine }
import from ..common.glyphs { Spinner }

def:pub BoardHeader(
    projects: list[Project],
    project: str,
    counts: list[list[str]],
    ghConnected: bool,
    syncing: bool,
    syncNote: str,
    busy: bool,
    onSync: Callable[[], None],
    onNew: Callable[[], None]
) -> JsxElement {
    return
        <div className="flex flex-wrap items-end gap-x-3 gap-y-4">
            <div className="flex min-w-0 flex-col gap-1.5">
                <ProjectLine projects={projects} project={project}/>
                <h1 className="page-title">Board</h1>
                <p className="flex flex-wrap gap-x-4 text-[13px] text-muted-foreground">
                    {for c in counts {
                        <span key={c[1]}>
                            <b
                                className={"font-semibold "
                                    + (
                                        "text-destructive"
                                            if c[2] == "alarm"
                                            else "text-foreground"
                                    )}
                            >
                                {c[0]}
                            </b>
                            {" " + c[1]}
                        </span>
                    }}
                </p>
            </div>
            <div className="ml-auto flex items-center gap-2">
                {if ghConnected {
                    <Button
                        key="sync"
                        variant="secondary"
                        className="rounded-full"
                        disabled={syncing}
                        onClick={onSync}
                    >
                        {if syncing {
                            <Spinner key="sp"/>
                        }}
                        <span className="max-sm:hidden">
                            {(syncNote or "Syncing…") if syncing else "Sync GitHub"}
                        </span>
                        {if not syncing {
                            <span key="short" className="sm:hidden">Sync</span>
                        }}
                    </Button>
                }}
                <Button className="rounded-full" disabled={busy} onClick={onNew}>
                    <svg width={14} height={14} viewBox="0 0 16 16" aria-hidden="true">
                        <path
                            d="M8 3v10M3 8h10"
                            stroke="currentColor"
                            strokeWidth={1.8}
                            strokeLinecap="round"
                        />
                    </svg>
                    New task
                    <span aria-hidden="true" className="kbd ml-0.5 max-md:hidden">
                        N
                    </span>
                </Button>
            </div>
        </div>;
}
