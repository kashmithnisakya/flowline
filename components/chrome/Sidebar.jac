"""The app's left sidebar at lg and up: the workspace name, search, Overview and
AI, the projects, then Ask, Workspace and the account card at its foot. A
project's own views are tabs on its pages. Sticky and full height."""

import from "@jac/runtime" { Link }
import from ..common.CommandPalette { PageIcon }
import from ..common.AiMark { AiMark }
import from .Mark { Mark }
import from .AccountMenu { AccountMenu }
import from .SidebarLink { SidebarLink, ITEM, ITEM_ON }
import from .SidebarAi { SidebarAi }
import from .SidebarProjects { SidebarProjects }

glob WORKSPACE: dict[str, str] = {
         "key": "workspace",
         "label": "Workspace",
         "to": "/workspace"
     },
     OVERVIEW: dict[str, str] = {
         "key": "overview",
         "label": "Overview",
         "to": "/overview"
     },
     PROCESSES: dict[str, str] = {
         "key": "processes",
         "label": "Processes",
         "to": "/processes"
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
    return
        <aside
            aria-label="Navigation"
            className="sticky top-0 hidden h-dvh w-56 shrink-0 flex-col gap-1 border-r border-sidebar-border bg-sidebar px-3 pt-4 pb-3 lg:flex"
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
                <SidebarLink page={OVERVIEW} path={path}/>
                <SidebarAi path={path}/>
                <SidebarLink page={PROCESSES} path={path}/>
            </nav>
            <div className="mt-3">
                <SidebarProjects path={path}/>
            </div>
            <div className="flex-1"/>
            <button
                type="button"
                data-ask-trigger="true"
                aria-pressed={askOpen}
                title={"Ask about this workspace (" + mod + "/)"}
                onClick={onAsk}
                className={ITEM
                    + (ITEM_ON if askOpen else "font-medium text-ai hover:bg-bg-hover")}
            >
                <AiMark/>
                <span className="flex-1">Ask</span>
                <span className="kbd">{mod + "/"}</span>
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
