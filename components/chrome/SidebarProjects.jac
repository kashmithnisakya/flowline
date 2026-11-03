"""The sidebar's projects with their open counts, the scoped one marked while a
project page is open. Drawn from the workspace cache the page fills (never a
read of its own); a pick scopes every page, moving to the board from elsewhere."""

import from "@jac/runtime" { navigate }
import from "react" { useEffect }
import from ...models { Project }
import from ...lib.workspace { cachedProjects }
import from ...lib.project { currentProject, pickProject }
import from ...lib.filters { defaultProject }
import from ..common.ProjectDot { projectDot }
import from ..common.CommandPalette { PageIcon }
import from .SidebarLink { ITEM, ITEM_ON, ITEM_OFF }

glob SCOPED: list[str] = ["/board", "/flowlines", "/roadmap"];

def:pub SidebarProjects(path: str) -> JsxElement {
    has projects: list[Project] = cachedProjects(),
        picked: str = currentProject();

    useEffect(
        lambda {
            w: any = window;
            onView = lambda (e: any) { projects = cachedProjects(); };
            onPick = lambda (e: any) { picked = str(e.detail or ""); };
            w.addEventListener("flowline:workspace", onView);
            w.addEventListener("flowline:project", onPick);
            return lambda {
                w.removeEventListener("flowline:workspace", onView);
                w.removeEventListener("flowline:project", onPick);
            };
        },
        []
    );

    live = [
        p
        for p in projects
        if p.active
    ];
    ids = [jid(p) for p in live];
    current = picked if picked in ids else defaultProject(live);
    scoped = path in SCOPED;
    rows: list[dict[str, str]] = [];
    for p in live {
        rows.append(
            {
                "id": jid(p),
                "name": p.name,
                "open": str(p.task_total - p.done_total),
                "tile": projectDot(len(rows))
            }
        );
    }

    def choose(id: str) {
        pickProject(id);
        if not scoped {
            navigate("/board");
        }
    }

    return
        <div className="flex flex-col gap-0.5">
            <div
                className="flex h-6 items-center justify-between pr-1 pl-2 text-xs text-text-tertiary"
            >
                Projects
                <button
                    type="button"
                    aria-label="New project"
                    title="New project"
                    onClick={lambda { navigate("/workspace?tab=projects"); }}
                    className="inline-flex size-6 items-center justify-center rounded-md hover:bg-bg-hover hover:text-text-primary"
                >
                    <PageIcon name="new-task" size={14}/>
                </button>
            </div>
            {for r in rows {
                <button
                    key={r["id"]}
                    type="button"
                    aria-pressed={scoped and r["id"] == current}
                    onClick={lambda { choose(r["id"]); }}
                    className={ITEM
                        + (ITEM_ON if scoped and r["id"] == current else ITEM_OFF)}
                >
                    <span
                        aria-hidden="true"
                        className={"size-2.5 shrink-0 rounded-[3px] " + r["tile"]}
                    />
                    <span className="min-w-0 flex-1 truncate">{r["name"]}</span>
                    <span className="num text-[12px] text-text-tertiary">
                        {r["open"]}
                    </span>
                </button>
            }}
        </div>;
}
