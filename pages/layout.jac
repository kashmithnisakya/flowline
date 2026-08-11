"""standup - root layout.

App pages get the nav, org name and logout. Public pages (the landing page
and the auth screens) render bare, the landing brings its own header, and
a logged-in visitor browsing / should not see two navs stacked.

The header is sticky with a blur so the board still reads while scrolling;
below md the six links collapse into a dropdown menu because they do not
fit a phone row.
"""

import from "@jac/runtime" { Outlet, Link, useLocation, jacIsLoggedIn, jacLogout }
import from ..lib.session { fetchOrgName }
import from ..lib.theme { getThemePref, applyTheme, watchTheme }
import from ..components.ui.button { Button }
# Note: the wrapper lives in toaster.jac, not sonner.jac, a module named
# `sonner` makes the compiler resolve the npm import "sonner" to ITSELF,
# producing a self-rendering Toaster and an infinite React mount loop.
import from ..components.ui.toaster { Toaster }
import from ..components.ui.dropdown_menu {
    DropdownMenu,
    DropdownMenuTrigger,
    DropdownMenuContent,
    DropdownMenuItem
}
import from ..components.assistant.AssistantDock { AssistantDock }

glob PUBLIC_PATHS: list[str] = ["/", "/login", "/auth/callback"];

glob NAV_ITEMS: list[dict[str, str]] = [
         {"to": "/workflow", "label": "Workflow"},
         {"to": "/board", "label": "Board"},
         {"to": "/overview", "label": "Overview"},
         {"to": "/log", "label": "Log"},
         {"to": "/workspace", "label": "Workspace"},
         {"to": "/settings", "label": "Settings"}
     ];

def:pub Shell -> JsxLayout {
    has loggedIn: bool = False,
        orgName: str = "";

    async can with entry {
        applyTheme(getThemePref());
        watchTheme();
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
        base = "rounded-full px-3 py-1.5 text-sm font-medium transition-colors duration-200 ";
        if location.pathname == path {
            return base + "bg-primary/10 text-primary";
        }
        return base + "text-muted-foreground hover:bg-accent hover:text-foreground";
    }

    return
        <div className="min-h-screen bg-background text-foreground">
            {if chrome {
                <header
                    key="nav"
                    className="sticky top-0 z-40 border-b border-border/60 bg-background/80 backdrop-blur-xl"
                >
                    <nav className="flex h-14 w-full items-center gap-1 px-4 sm:px-6 lg:px-10">
                        <Link to="/board" className="mr-3 flex shrink-0 items-center gap-2">
                            <img
                                src="/static/brand/logo-mark.svg"
                                alt=""
                                width={28}
                                height={28}
                            />
                            <span
                                className="font-display text-xl font-bold tracking-tight"
                            >
                                standup
                                <span className="text-primary ml-0.5">.</span>
                            </span>
                        </Link>
                        <div className="hidden items-center gap-1 md:flex">
                            {for item in NAV_ITEMS {
                                <Link
                                    key={item["to"]}
                                    to={item["to"]}
                                    className={navClass(item["to"])}
                                >
                                    {item["label"]}
                                </Link>
                            }}
                        </div>
                        <div className="ml-auto flex items-center gap-2 sm:gap-3">
                            {if orgName {
                                <span
                                    key="org"
                                    className="hidden items-center rounded-full border border-border/70 bg-card px-3 py-1 text-xs font-medium text-muted-foreground sm:inline-flex"
                                >
                                    {orgName}
                                </span>
                            }}
                            <Button variant="outline" size="sm" onClick={logout}>
                                Log out
                            </Button>
                            <div className="md:hidden">
                                <DropdownMenu>
                                    <DropdownMenuTrigger asChild={True}>
                                        <Button
                                            variant="ghost"
                                            size="icon"
                                            aria-label="Open navigation"
                                        >
                                            <svg
                                                width={18}
                                                height={18}
                                                viewBox="0 0 24 24"
                                                fill="none"
                                                stroke="currentColor"
                                                strokeWidth={2}
                                                strokeLinecap="round"
                                            >
                                                <path d="M4 6h16"/>
                                                <path d="M4 12h16"/>
                                                <path d="M4 18h16"/>
                                            </svg>
                                        </Button>
                                    </DropdownMenuTrigger>
                                    <DropdownMenuContent align="end" className="w-44">
                                        {for item in NAV_ITEMS {
                                            <DropdownMenuItem
                                                key={item["to"]}
                                                asChild={True}
                                            >
                                                <Link to={item["to"]}>
                                                    {item["label"]}
                                                </Link>
                                            </DropdownMenuItem>
                                        }}
                                    </DropdownMenuContent>
                                </DropdownMenu>
                            </div>
                        </div>
                    </nav>
                </header>
            }}
            {if chrome {
                <main
                    key="app"
                    className="w-full px-4 py-6 sm:px-6 lg:px-10 lg:py-8"
                >
                    <Outlet/>
                </main>
            } else {
                <Outlet key="bare"/>
            } }
            {if chrome {
                <AssistantDock key="assistant"/>
            }}
            <Toaster/>
        </div>;
}
