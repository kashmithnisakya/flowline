"""flowline - root layout. App pages get the nav, an account menu (org name,
settings, theme, log out) and the ⌘K palette; public pages render bare (the
landing brings its own header). The header is sticky with a blur; below md
the six links collapse into a dropdown menu.
"""

import from "@jac/runtime" { Outlet, Link, useLocation, jacIsLoggedIn, jacLogout }
import from "react" { useEffect }
# jac 0.34.x compiler pin, not a nav dependency: the last-scanned page must
# import constants directly or the client copy is emitted empty once a
# component in a later page's closure imports it (see CLAUDE.md gotchas).
import from ..constants { STATUSES }
# kinds.jac and models.jac need the same pin: their exports drop the same way
# (CARRY_LABEL / WIRE_TINT killed FlowCanvas, the tally objs killed _entry).
import from ..components.flowlines.kinds { CARRY_LABEL, WIRE_TINT }
import from ..models { LogTotals, MemberDays, ProjectTally, TaskTotals }
import from ..lib.session { fetchProfile }
import from ..lib.theme { getThemePref, applyTheme, watchTheme, setThemePref }
import from ..components.ui.button { Button }
import from ..components.common.Avatar { Avatar }
import from ..components.common.CommandPalette { CommandPalette }
# Note: the wrapper lives in toaster.jac, not sonner.jac, a module named
# `sonner` makes the compiler resolve the npm import "sonner" to ITSELF,
# producing a self-rendering Toaster and an infinite React mount loop.
import from ..components.ui.toaster { Toaster }
import from ..components.ui.dropdown_menu {
    DropdownMenu,
    DropdownMenuTrigger,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuLabel,
    DropdownMenuSeparator,
    DropdownMenuRadioGroup,
    DropdownMenuRadioItem
}
import from ..components.assistant.AssistantDock { AssistantDock }

glob PUBLIC_PATHS: list[str] = ["/", "/login", "/auth/callback"],
     THEME_CHOICES: list[dict[str, str]] = [
         {"value": "light", "label": "Light"},
         {"value": "dark", "label": "Dark"},
         {"value": "system", "label": "System"}
     ],
     NAV_ITEMS: list[dict[str, str]] = [
         {"to": "/flowlines", "label": "Flow line"},
         {"to": "/board", "label": "Board"},
         {"to": "/overview", "label": "Overview"},
         {"to": "/log", "label": "Log"},
         {"to": "/github", "label": "GitHub"},
         {"to": "/workspace", "label": "Workspace"}
     ];

# Settings lives in the account menu on the right, next to the theme toggle
# and the palette button; the text row is pages only.
def:pub Shell -> JsxLayout {
    has loggedIn: bool = False,
        # Only referenced so the pins above count as client code. len() on a
        # dict is broken client-side, so the kinds pin indexes instead.
        vocabPin: int = len(STATUSES),
        kindsPin: str = CARRY_LABEL["issue"] + WIRE_TINT["sky"],
        modelsPin: list[any] = [LogTotals, MemberDays, ProjectTally, TaskTotals],
        orgName: str = "",
        fullName: str = "",
        # Mirrors the html.dark class for the toggle icon. Read after
        # applyTheme so "system" resolves to what is actually showing.
        themeDark: bool = False,
        # Not `themePref`: its generated setter would shadow the imported
        # setThemePref, silently breaking the toggle (issue #131).
        themeChoice: str = "system",
        paletteOpen: bool = False;

    async can with entry {
        applyTheme(getThemePref());
        watchTheme();
        doc: any = document;
        themeDark = bool(doc.documentElement.classList.contains("dark"));
        themeChoice = getThemePref();
        isIn = jacIsLoggedIn();
        loggedIn = isIn;
        if isIn {
            loadOrg();
        }
    }

    # ⌘K / Ctrl+K anywhere in the app opens the palette.
    useEffect(
        lambda {
            onKey = lambda (e: any) { if (e.metaKey or e.ctrlKey)
                and str(e.key).lower() == "k" {
                e.preventDefault();
                paletteOpen = True;
            }};
            window.addEventListener("keydown", onKey);
            return lambda { window.removeEventListener("keydown", onKey); };
        },
        []
    );

    async def loadOrg -> None;
    def logout -> None;
    def toggleTheme -> None;
    def pickTheme(pref: str) -> None;

    location = useLocation();
    chrome = loggedIn and location.pathname not in PUBLIC_PATHS;
    # The wizard has nothing to link to yet: every page would be empty.
    navItems: list[dict[str, str]] = [] if location.pathname == "/setup" else NAV_ITEMS;

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
                    <nav
                        className="flex h-14 w-full items-center gap-1 px-4 sm:px-6 lg:px-10"
                    >
                        <Link
                            to="/board"
                            className="mr-3 flex shrink-0 items-center gap-2"
                        >
                            <img
                                src="/static/brand/logo-mark.svg"
                                alt=""
                                width={28}
                                height={28}
                            />
                            <span
                                className="font-display text-xl font-bold tracking-tight"
                            >
                                flowline
                                <span className="text-primary ml-0.5">.</span>
                            </span>
                        </Link>
                        <div className="hidden items-center gap-1 md:flex">
                            {for item in navItems {
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
                            <button
                                type="button"
                                aria-label="Open command palette"
                                title="Command palette (⌘K)"
                                className="inline-flex items-center gap-2 rounded-full p-2 text-muted-foreground transition-colors duration-200 hover:bg-accent hover:text-foreground sm:rounded-lg sm:border sm:border-border/70 sm:bg-card sm:py-1 sm:pr-1.5 sm:pl-2.5"
                                onClick={lambda { paletteOpen = True; }}
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
                                    aria-hidden="true"
                                >
                                    <circle cx={11} cy={11} r={8}/>
                                    <path d="m21 21-4.3-4.3"/>
                                </svg>
                                <kbd
                                    className="hidden rounded border border-border bg-muted px-1 font-mono text-[10px] sm:inline"
                                >
                                    ⌘K
                                </kbd>
                            </button>
                            <button
                                type="button"
                                aria-label={"Switch to light mode"
                                    if themeDark
                                    else "Switch to dark mode"}
                                title={"Switch to light mode"
                                    if themeDark
                                    else "Switch to dark mode"}
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
                                } }
                            </button>
                            <DropdownMenu>
                                <DropdownMenuTrigger asChild={True}>
                                    <button
                                        type="button"
                                        aria-label="Account menu"
                                        className="inline-flex items-center gap-2 rounded-full border border-border/70 bg-card py-0.5 pr-2 pl-0.5 text-xs font-medium text-foreground transition-colors duration-200 hover:bg-accent"
                                    >
                                        <Avatar name={orgName or "flowline"} size="sm"/>
                                        <span
                                            className="hidden max-w-40 truncate sm:inline"
                                        >
                                            {orgName or "Account"}
                                        </span>
                                        <svg
                                            width={12}
                                            height={12}
                                            viewBox="0 0 24 24"
                                            fill="none"
                                            stroke="currentColor"
                                            strokeWidth={2}
                                            strokeLinecap="round"
                                            strokeLinejoin="round"
                                            className="text-muted-foreground"
                                            aria-hidden="true"
                                        >
                                            <path d="m6 9 6 6 6-6"/>
                                        </svg>
                                    </button>
                                </DropdownMenuTrigger>
                                <DropdownMenuContent align="end" className="w-56">
                                    <DropdownMenuLabel
                                        className="flex flex-col gap-0.5"
                                    >
                                        <span
                                            className="truncate text-sm font-semibold"
                                        >
                                            {orgName or "Your workspace"}
                                        </span>
                                        {if fullName {
                                            <span
                                                key="who"
                                                className="truncate text-xs font-normal text-muted-foreground"
                                            >
                                                {fullName}
                                            </span>
                                        }}
                                    </DropdownMenuLabel>
                                    <DropdownMenuSeparator/>
                                    <DropdownMenuItem asChild={True}>
                                        <Link to="/settings">Settings</Link>
                                    </DropdownMenuItem>
                                    <DropdownMenuItem asChild={True}>
                                        <Link to="/workspace">Workspace</Link>
                                    </DropdownMenuItem>
                                    <DropdownMenuSeparator/>
                                    <DropdownMenuLabel
                                        className="text-xs font-medium text-muted-foreground"
                                    >
                                        Theme
                                    </DropdownMenuLabel>
                                    <DropdownMenuRadioGroup
                                        value={themeChoice}
                                        onValueChange={pickTheme}
                                    >
                                        {for choice in THEME_CHOICES {
                                            <DropdownMenuRadioItem
                                                key={choice["value"]}
                                                value={choice["value"]}
                                            >
                                                {choice["label"]}
                                            </DropdownMenuRadioItem>
                                        }}
                                    </DropdownMenuRadioGroup>
                                    <DropdownMenuSeparator/>
                                    <DropdownMenuItem
                                        variant="destructive"
                                        onSelect={lambda { logout(); }}
                                    >
                                        Log out
                                    </DropdownMenuItem>
                                </DropdownMenuContent>
                            </DropdownMenu>
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
                <main key="app" className="w-full px-4 py-6 sm:px-6 lg:px-10 lg:py-8">
                    <Outlet/>
                </main>
            } else {
                <Outlet key="bare"/>
            } }
            {if chrome {
                <AssistantDock key="assistant"/>
            }}
            {if chrome {
                <CommandPalette
                    key="palette"
                    open={paletteOpen}
                    onOpenChange={lambda (o: bool) { paletteOpen = o; }}
                />
            }}
            <Toaster/>
        </div>;
}
