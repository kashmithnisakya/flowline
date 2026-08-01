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

    <div className="min-h-screen bg-background text-foreground">
        {if chrome {
            <header key="nav" className="border-b">
                <nav className="mx-auto flex max-w-[96rem] items-center gap-6 px-6 py-3">
                    <Link to="/board" className="flex items-center gap-2">
                        <img src="/static/brand/logo-mark.svg" alt="" width={28} height={28} />
                        <span className="font-display text-lg font-bold tracking-tight">
                            standup
                        </span>
                    </Link>
                    <Link to="/board" className="text-sm text-muted-foreground transition-colors hover:text-foreground">
                        Board
                    </Link>
                    <Link to="/log" className="text-sm text-muted-foreground transition-colors hover:text-foreground">
                        Daily Log
                    </Link>
                    <Link to="/projects" className="text-sm text-muted-foreground transition-colors hover:text-foreground">
                        Projects
                    </Link>
                    <Link to="/roster" className="text-sm text-muted-foreground transition-colors hover:text-foreground">
                        People
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
            <main key="app" className="mx-auto max-w-[96rem] px-6 py-6">
                <Outlet />
            </main>
        } else {
            <Outlet key="bare" />
        }}
        <Toaster />
    </div>
}
