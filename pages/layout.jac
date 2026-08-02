"""standup - root layout.

App pages get the nav, org name and logout. Public pages (the landing page
and the auth screens) render bare — the landing brings its own header, and
a logged-in visitor browsing / should not see two navs stacked.
"""

import from "@jac/runtime" { Outlet, Link, useLocation, jacIsLoggedIn, jacLogout }
import from ..lib.session { fetchOrgName }
import from ..components.ui.button { Button }
# Note: the wrapper lives in toaster.jac, not sonner.jac — a module named
# `sonner` makes the compiler resolve the npm import "sonner" to ITSELF,
# producing a self-rendering Toaster and an infinite React mount loop.
import from ..components.ui.toaster { Toaster }
import from ..components.assistant.AssistantDock { AssistantDock }

glob PUBLIC_PATHS: list[str] = ["/", "/login", "/auth/callback"];

def:pub Shell() -> JsxLayout {
    has loggedIn: bool = False,
        orgName: str = "";

    async can with entry {
        isIn = jacIsLoggedIn();
        loggedIn = isIn;
        if isIn {
            loadOrg();
        }
    }

    async def loadOrg -> None;
    def logout -> None;

    location = useLocation();
    chrome = loggedIn and location.pathname not in PUBLIC_PATHS;

    def navClass(path: str) -> str {
        base = "rounded-md px-2.5 py-1.5 text-[15px] font-medium transition-colors ";
        if location.pathname == path {
            return base + "bg-secondary text-foreground";
        }
        return base + "text-muted-foreground hover:bg-accent hover:text-foreground";
    }

    return <div className="min-h-screen bg-background text-foreground">
        {if chrome {
            <header key="nav" className="border-b">
                <nav className="flex items-center gap-4 px-6 py-3 lg:px-10">
                    <Link to="/board" className="mr-2 flex items-center gap-2">
                        <img src="/static/brand/logo-mark.svg" alt="" width={30} height={30} />
                        <span className="font-display text-xl font-bold tracking-tight">
                            standup<span className="text-primary ml-0.5">.</span>
                        </span>
                    </Link>
                    <Link to="/board" className={navClass("/board")}>
                        Board
                    </Link>
                    <Link to="/overview" className={navClass("/overview")}>
                        Overview
                    </Link>
                    <Link to="/log" className={navClass("/log")}>
                        Log
                    </Link>
                    <Link to="/projects" className={navClass("/projects")}>
                        Projects
                    </Link>
                    <Link to="/roster" className={navClass("/roster")}>
                        Workspace
                    </Link>
                    <div className="ml-auto flex items-center gap-3">
                        {if orgName {
                            <span key="org" className="text-sm font-medium text-muted-foreground">
                                {orgName}
                            </span>
                        }}
                        <Button variant="outline" size="sm" onClick={logout}>
                            Log out
                        </Button>
                    </div>
                </nav>
            </header>
        }}
        {if chrome {
            <main key="app" className="px-6 py-6 lg:px-10">
                <Outlet />
            </main>
        } else {
            <Outlet key="bare" />
        }}
        {if chrome {
            <AssistantDock key="assistant" />
        }}
        <Toaster />
    </div>;
}
