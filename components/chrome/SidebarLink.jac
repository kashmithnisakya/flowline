"""One sidebar page link: its icon and label, on a selected fill when it is
the current page. Nav sits a notch dimmer than the content, so nothing here
is raised, ringed or accent coloured."""

import from "@jac/runtime" { Link }
import from ..common.CommandPalette { PageIcon }

glob:pub ITEM: str = "flex h-[30px] w-full items-center gap-2.5 rounded-md px-2 text-left text-[13px] transition-colors ",
     ITEM_ON: str = "bg-bg-selected font-medium text-text-primary",
     ITEM_OFF: str = "text-text-secondary hover:bg-bg-hover hover:text-text-primary";

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
            <PageIcon name={page["key"]} size={16}/>
            {page["label"]}
        </Link>;
}
