"""standup - root layout.

Logged in: app nav + org name + logout. Logged out: bare shell (the
(public)/login page centers itself; (auth)/ pages are guarded anyway).
"""

import from "@jac/runtime" { Outlet, Link, jacIsLoggedIn, jacLogout }
import from ..walkers.org { GetMe }
import from ..components.ui.button { Button }
# Note: the wrapper lives in toaster.jac, not sonner.jac — a module named
# `sonner` makes the compiler resolve the npm import "sonner" to ITSELF,
# producing a self-rendering Toaster and an infinite React mount loop.
import from ..components.ui.toaster { Toaster }

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

    <div className="min-h-screen bg-background text-foreground">
        {if loggedIn {
            <header key="nav" className="border-b">
                <nav className="mx-auto flex max-w-[96rem] items-center gap-6 px-6 py-3">
                    <span className="text-lg font-semibold tracking-tight">standup</span>
                    <Link to="/" className="text-sm text-muted-foreground transition-colors hover:text-foreground">
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
        <main className="mx-auto max-w-[96rem] px-6 py-6">
            <Outlet />
        </main>
        <Toaster />
    </div>
}
