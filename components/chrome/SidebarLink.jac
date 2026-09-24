"""One sidebar page link: its icon and label, raised on a card fill when it
is the current page."""

import from "@jac/runtime" { Link }
import from ..common.CommandPalette { PageIcon }

glob:pub ITEM: str = "flex h-10 w-full items-center gap-3 rounded-lg px-3 text-left text-sm transition-colors ",
     ITEM_ON: str = "bg-card font-medium text-foreground shadow-xs ring-1 ring-sidebar-border",
     ITEM_OFF: str = "text-muted-foreground hover:bg-sidebar-accent hover:text-foreground";

# A page is current on its own path and below it; /github is Workspace.
def:pub isCurrent(path: str, to: str) -> bool {
    if to == "/workspace" and path == "/github" {
        return True;
    }
    return path == to or path.startswith(to + "/");
}

def:pub SidebarLink(page: dict[str, str], path: str) -> JsxElement {
    on = isCurrent(path, page["to"]);
    return
        <Link
            to={page["to"]}
            aria-current={"page" if on else None}
            className={ITEM + (ITEM_ON if on else ITEM_OFF)}
        >
            <PageIcon name={page["key"]} size={18}/>
            {page["label"]}
        </Link>;
}
