"""The header every project page shares: the project's name, its three views as
tabs (a tab is a route, so a view keeps its own address), the page's actions on
the right and, under them, whatever the page passes as children (the line bar)."""

import from "@jac/runtime" { Link }
import from ...models { Project }
import from .ProjectLine { ProjectLine }

glob VIEWS: list[dict[str, str]] = [
         {"key": "board", "label": "Board", "to": "/board"},
         {"key": "flowline", "label": "Flow line", "to": "/flowlines"},
         {"key": "roadmap", "label": "Roadmap", "to": "/roadmap"}
     ];

def:pub ProjectHead(
    projects: list[Project],
    project: str,
    view: str,
    actions: any = None,
    children: any = None
) -> JsxElement {
    return
        <header className="flex flex-col gap-2.5 border-b pb-2.5">
            <div className="flex flex-wrap items-center gap-x-5 gap-y-2">
                <ProjectLine projects={projects} project={project}/>
                <nav aria-label="Project views" className="flex gap-0.5">
                    {for v in VIEWS {
                        <Link
                            key={v["key"]}
                            to={v["to"]}
                            aria-current={"page" if v["key"] == view else None}
                            className={"inline-flex h-[30px] items-center rounded-md px-2.5 text-[13px] transition-colors "
                                + (
                                    "bg-bg-selected font-medium text-text-primary"
                                        if v["key"] == view
                                        else "text-text-secondary hover:bg-bg-hover hover:text-text-primary"
                                )}
                        >
                            {v["label"]}
                        </Link>
                    }}
                </nav>
                {if actions {
                    <div
                        key="acts"
                        className="ml-auto flex flex-wrap items-center gap-2"
                    >
                        {actions}
                    </div>
                }}
            </div>
            {children}
        </header>;
}
