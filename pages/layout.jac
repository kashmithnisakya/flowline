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
import from ..lib.theme { getThemePref, applyTheme, watchTheme, setThemePref }
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

# Settings is not in the text row: it collapses to the gear icon on the
# right, next to the theme toggle.
glob NAV_ITEMS: list[dict[str, str]] = [
         {"to": "/workflow", "label": "Workflow"},
         {"to": "/board", "label": "Board"},
         {"to": "/overview", "label": "Overview"},
         {"to": "/log", "label": "Log"},
         {"to": "/github", "label": "GitHub"},
         {"to": "/workspace", "label": "Workspace"}
     ];

def:pub Shell -> JsxLayout {
    has loggedIn: bool = False,
        orgName: str = "",
        # Mirrors the html.dark class for the toggle icon. Read after
        # applyTheme so "system" resolves to what is actually showing.
        themeDark: bool = False;

    async can with entry {
        applyTheme(getThemePref());
        watchTheme();
        doc: any = document;
        themeDark = bool(doc.documentElement.classList.contains("dark"));
        isIn = jacIsLoggedIn();
        loggedIn = isIn;
        if isIn {
            loadOrg();
        }
    }

    async def loadOrg -> None;
    def logout -> None;
    def toggleTheme -> None;

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
                        <div className="ml-auto flex items-center gap-1 sm:gap-2">
                            {if orgName {
                                <span
                                    key="org"
                                    className="mr-1 hidden items-center rounded-full border border-border/70 bg-card px-3 py-1 text-xs font-medium text-muted-foreground sm:inline-flex"
                                >
                                    {orgName}
                                </span>
                            }}
                            <button
                                type="button"
                                aria-label={"Switch to light mode" if themeDark else "Switch to dark mode"}
                                title={"Switch to light mode" if themeDark else "Switch to dark mode"}
                                className="rounded-full p-2 text-muted-foreground transition-colors duration-200 hover:bg-accent hover:text-foreground"
                                onClick={toggleTheme}
                            >
                                {if themeDark {
                                    <svg
                                        key="sun"
                                        width={16}
                                        height={16}
                                        viewBox="0 0 24 24"
                                        fill="none"
                                        stroke="currentColor"
                                        strokeWidth={2}
                                        strokeLinecap="round"
                                        strokeLinejoin="round"
                                    >
                                        <circle cx={12} cy={12} r={4}/>
                                        <path d="M12 2v2"/>
                                        <path d="M12 20v2"/>
                                        <path d="m4.93 4.93 1.41 1.41"/>
                                        <path d="m17.66 17.66 1.41 1.41"/>
                                        <path d="M2 12h2"/>
                                        <path d="M20 12h2"/>
                                        <path d="m6.34 17.66-1.41 1.41"/>
                                        <path d="m19.07 4.93-1.41 1.41"/>
                                    </svg>
                                } else {
                                    <svg
                                        key="moon"
                                        width={16}
                                        height={16}
                                        viewBox="0 0 24 24"
                                        fill="none"
                                        stroke="currentColor"
                                        strokeWidth={2}
                                        strokeLinecap="round"
                                        strokeLinejoin="round"
                                    >
                                        <path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/>
                                    </svg>
                                }}
                            </button>
                            <Link
                                to="/settings"
                                aria-label="Settings"
                                title="Settings"
                                className={
                                    "hidden rounded-full p-2 transition-colors duration-200 md:inline-flex "
                                    + (
                                        "bg-primary/10 text-primary"
                                            if location.pathname == "/settings"
                                            else "text-muted-foreground hover:bg-accent hover:text-foreground"
                                    )
                                }
                            >
                                <svg
                                    width={16}
                                    height={16}
                                    viewBox="0 0 24 24"
                                    fill="none"
                                    stroke="currentColor"
                                    strokeWidth={2}
                                    strokeLinecap="round"
                                    strokeLinejoin="round"
                                >
                                    <path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/>
                                    <circle cx={12} cy={12} r={3}/>
                                </svg>
                            </Link>
                            <Button
                                variant="outline"
                                size="sm"
                                className="ml-1"
                                onClick={logout}
                            >
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
                                        <DropdownMenuItem asChild={True}>
                                            <Link to="/settings">Settings</Link>
                                        </DropdownMenuItem>
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
