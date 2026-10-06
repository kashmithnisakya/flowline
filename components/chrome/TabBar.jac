"""The phone tab bar below md: every page in the sidebar's order, Workspace
last, each an icon over its label."""

import from "@jac/runtime" { Link }
import from ..common.CommandPalette { PageIcon, NAV_PAGES }
import from .SidebarLink { isCurrent }

def:pub TabBar(path: str) -> JsxElement {
    return
        <nav
            aria-label="Pages"
            className="fixed inset-x-0 bottom-0 z-40 grid grid-cols-5 border-t bg-card pb-[env(safe-area-inset-bottom)] lg:hidden"
        >
            {for p in NAV_PAGES {
                <Link
                    key={p["key"]}
                    to={p["to"]}
                    aria-current={"page" if isCurrent(path, p["to"]) else None}
                    className={"flex h-14 flex-col items-center justify-center gap-1 text-xs "
                        + (
                            "font-semibold text-primary"
                                if isCurrent(path, p["to"])
                                else "font-medium text-muted-foreground"
                        )}
                >
                    <PageIcon name={p["key"]} size={20}/>
                    {p["label"]}
                </Link>
            }}
        </nav>;
}
