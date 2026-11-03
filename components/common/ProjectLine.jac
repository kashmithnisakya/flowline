"""A project page's title: the project's dot and name. With more than one
project it opens a menu that calls pickProject, so the sidebar and every page
follow the pick (phones have no sidebar)."""

import from ...models { Project }
import from ...lib.project { pickProject }
import from ..ui.dropdown_menu {
    DropdownMenu,
    DropdownMenuTrigger,
    DropdownMenuContent,
    DropdownMenuRadioGroup,
    DropdownMenuRadioItem
}
import from .Chevron { Chevron }
import from .ProjectDot { ProjectDot }

def:pub ProjectLine(projects: list[Project], project: str) -> JsxElement {
    name = "";
    at = 0;
    for (i, p) in enumerate(projects) {
        if jid(p) == project {
            name = p.name;
            at = i;
        }
    }
    if len(projects) < 2 {
        return
            <h1 className="page-title flex min-w-0 items-center gap-2">
                <ProjectDot i={at}/>
                <span className="truncate">{name or "No project yet"}</span>
            </h1>;
    }
    return
        <DropdownMenu>
            <h1 className="page-title min-w-0">
                <DropdownMenuTrigger
                    className="flex max-w-full items-center gap-2 rounded-md outline-none focus-visible:outline-2 focus-visible:outline-ring focus-visible:outline-solid"
                    aria-label={"Project: " + name + ". Change project"}
                >
                    <ProjectDot i={at}/>
                    <span className="truncate">{name or "Pick a project"}</span>
                    <Chevron/>
                </DropdownMenuTrigger>
            </h1>
            <DropdownMenuContent
                align="start"
                collisionPadding={16}
                className="max-h-80 w-64"
            >
                <DropdownMenuRadioGroup value={project} onValueChange={pickProject}>
                    {for p in projects {
                        <DropdownMenuRadioItem key={jid(p)} value={jid(p)}>
                            <span className="truncate">{p.name}</span>
                        </DropdownMenuRadioItem>
                    }}
                </DropdownMenuRadioGroup>
            </DropdownMenuContent>
        </DropdownMenu>;
}
