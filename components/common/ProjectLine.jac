"""The small muted line above a scoped page's title: the project it shows.
With more than one project it opens a menu that calls pickProject, so the
sidebar and every page follow the pick (phones have no sidebar)."""

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

def:pub ProjectLine(projects: list[Project], project: str) -> JsxElement {
    name = "";
    for p in projects {
        if jid(p) == project {
            name = p.name;
        }
    }
    if len(projects) < 2 {
        return <p className="meta truncate">{name or "No project yet"}</p>;
    }
    return
        <DropdownMenu>
            <DropdownMenuTrigger
                className="meta inline-flex max-w-full items-center gap-1 self-start rounded-full outline-none hover:text-foreground focus-visible:outline-2 focus-visible:outline-ring focus-visible:outline-solid"
                aria-label={"Project: " + name + ". Change project"}
            >
                <span className="truncate">{name or "Pick a project"}</span>
                <Chevron/>
            </DropdownMenuTrigger>
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
