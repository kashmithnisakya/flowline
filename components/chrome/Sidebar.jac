"""The app's left sidebar at md and up: the workspace name, search, the daily
pages, the projects, then Ask, Workspace and the account card at its foot.
It is sticky and full height; the page scrolls beside it."""

import from "@jac/runtime" { Link }
import from ..common.CommandPalette { PageIcon, NAV_PAGES }
import from .Mark { Mark }
import from .AccountMenu { AccountMenu }
import from .SidebarLink { SidebarLink, ITEM, ITEM_ON, ITEM_OFF }
import from .SidebarProjects { SidebarProjects }

glob WORKSPACE: dict[str, str] = {
         "key": "workspace",
         "label": "Workspace",
         "to": "/workspace"
     };

def:pub Sidebar(
    path: str,
    orgName: str,
    account: str,
    themeChoice: str,
    askOpen: bool,
    mod: str,
    onSearch: Callable[[], None],
    onAsk: Callable[[], None],
    onTheme: Callable[[str], None],
    onSignOut: Callable[[], None]
) -> JsxElement {
    pages = [
        p
        for p in NAV_PAGES
        if p["group"] == "daily"
    ];

    return
        <aside
            aria-label="Navigation"
            className="sticky top-0 hidden h-dvh w-60 shrink-0 flex-col gap-1 border-r border-sidebar-border bg-sidebar px-3 pt-4 pb-3 md:flex"
        >
            <Link
                to="/board"
                className="flex h-11 items-center gap-2.5 rounded-lg px-2.5 hover:bg-sidebar-accent"
            >
                <Mark/>
                <span className="truncate text-[15px] font-semibold tracking-[-0.01em]">
                    {orgName or "flowline"}
                </span>
            </Link>
            <button
                type="button"
                onClick={onSearch}
                className="mt-1.5 mb-3 flex h-[30px] items-center gap-2.5 rounded-md px-2 text-[13px] text-text-tertiary transition-colors hover:bg-bg-hover hover:text-text-primary"
            >
                <PageIcon name="search"/>
                <span className="flex-1 text-left">Search</span>
                <span className="kbd">{mod + "K"}</span>
            </button>
            <nav aria-label="Pages" className="flex flex-col gap-0.5">
                {for page in pages {
                    <SidebarLink key={page["key"]} page={page} path={path}/>
                }}
            </nav>
            <div className="mx-1 my-4 h-px bg-sidebar-border"/>
            <SidebarProjects path={path}/>
            <div className="flex-1"/>
            <button
                type="button"
                data-ask-trigger="true"
                aria-pressed={askOpen}
                title={"Ask about this workspace (" + mod + "/)"}
                onClick={onAsk}
                className={ITEM + (ITEM_ON if askOpen else ITEM_OFF)}
            >
                <PageIcon name="ask" size={18}/>
                Ask Flowline
            </button>
            <SidebarLink page={WORKSPACE} path={path}/>
            <div className="mt-2">
                <AccountMenu
                    orgName={orgName}
                    account={account}
                    themeChoice={themeChoice}
                    onTheme={onTheme}
                    onSignOut={onSignOut}
                    card={True}
                />
            </div>
        </aside>;
}
