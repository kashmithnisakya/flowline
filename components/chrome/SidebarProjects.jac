"""The sidebar's projects with their open counts, the scoped one marked.
Drawn from the workspace cache the page fills (never a read of its own); a
pick scopes every page, moving to the board from a page without a project."""

import from "@jac/runtime" { navigate }
import from "react" { useEffect }
import from ...models { Project }
import from ...lib.workspace { cachedProjects }
import from ...lib.project { currentProject, pickProject }
import from ...lib.filters { defaultProject }
import from ..common.ProjectDot { projectDot }

glob SCOPED: list[str] = ["/board", "/flowlines", "/roadmap"],
     TILES: list[str] = ["sky", "indigo", "amber", "rose", "emerald", "slate"];

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
        if path not in SCOPED {
            navigate("/board");
        }
    }

    return
        <div className="flex flex-col gap-0.5">
            <div className="px-3 pb-1.5 text-xs font-medium text-muted-foreground">
                Projects
            </div>
            {for r in rows {
                <button
                    key={r["id"]}
                    type="button"
                    aria-pressed={r["id"] == current}
                    onClick={lambda { choose(r["id"]); }}
                    className={"flex h-9 items-center gap-3 rounded-lg px-3 text-left text-sm transition-colors "
                        + (
                            "bg-sidebar-accent font-medium text-foreground"
                                if r["id"] == current
                                else "text-muted-foreground hover:bg-sidebar-accent hover:text-foreground"
                        )}
                >
                    <span
                        aria-hidden="true"
                        className={"size-2.5 shrink-0 rounded-[3px] " + r["tile"]}
                    />
                    <span className="min-w-0 flex-1 truncate">{r["name"]}</span>
                    <span className="num text-xs text-subtle">{r["open"]}</span>
                </button>
            }}
            <button
                type="button"
                onClick={lambda { navigate("/workspace?tab=projects"); }}
                className="mt-1 flex h-9 items-center gap-3 rounded-lg border border-sidebar-border px-3 text-[13px] text-muted-foreground transition-colors hover:bg-sidebar-accent hover:text-foreground"
            >
                + New project
            </button>
        </div>;
}
