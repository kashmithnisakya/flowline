"""flowline - root layout. App pages get a grouped top bar (the setup group
folds into More below 1024px), the ⌘K palette, Ask (a docked column at 1280px
and up, a sheet below) and, on phones, a header over a bottom tab bar. /setup
gets the mark and Sign out only."""

import from "@jac/runtime" { Outlet, Link, useLocation, jacIsLoggedIn, jacLogout }
import from "react" { useEffect }
import from ..lib.theme { getThemePref, applyTheme, watchTheme, setThemePref }
import from ..components.common.Avatar { Avatar }
import from ..components.common.KindGlyph { KindGlyph }
import from ..components.common.glyphs { WarnIcon }
import from ..components.common.CommandPalette {
    CommandPalette,
    PageIcon,
    NAV_PAGES,
    modKey
}
# Note: the wrapper lives in toaster.jac, not sonner.jac, a module named
# `sonner` makes the compiler resolve the npm import "sonner" to ITSELF,
# producing a self-rendering Toaster and an infinite React mount loop.
import from ..components.ui.toaster { Toaster }
import from ..components.ui.sheet { Sheet, SheetContent, SheetHeader, SheetTitle }
import from ..components.ui.dropdown_menu {
    DropdownMenu,
    DropdownMenuTrigger,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuLabel,
    DropdownMenuSeparator,
    DropdownMenuSub,
    DropdownMenuSubTrigger,
    DropdownMenuSubContent,
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
     TAB_KEYS: list[str] = ["board", "tasks", "log", "overview"],
     # Titles for the phone header on pages the nav does not list.
     EXTRA_TITLES: dict[str, str] = {"/settings": "Preferences", "/setup": "Setup"},
     # Sonner places toasts this far above a phone's tab bar.
     TAB_CLEAR: str = "calc(4.5rem + env(safe-area-inset-bottom))";

# The brand mark drawn inline in currentColor: a start node, a bend, an end node.
def Mark(size: int = 20, className: str = "") -> JsxElement {
    return
        <svg
            className={"shrink-0 text-mark " + className}
            width={size}
            height={size}
            viewBox="0 0 24 24"
            fill="none"
            aria-hidden="true"
        >
            <circle cx={5} cy={17} r={3} stroke="currentColor" strokeWidth={2.2}/>
            <path
                d="M8 17h3.5a3 3 0 0 0 3-3v-4a3 3 0 0 1 1.5-2.6"
                stroke="currentColor"
                strokeWidth={2.2}
                strokeLinecap="round"
            />
            <circle cx={19} cy={7} r={3} fill="currentColor"/>
        </svg>;
}

# The account menu behind the avatar: who is signed in, workspace settings,
# preferences, a theme submenu and Sign out.
def AccountMenu(
    orgName: str,
    account: str,
    themeChoice: str,
    onTheme: Callable[[str], None],
    onSignOut: Callable[[], None]
) -> JsxElement {
    themeLabel = "System";
    for c in THEME_CHOICES {
        if c["value"] == themeChoice {
            themeLabel = c["label"];
        }
    }
    return
        <DropdownMenu>
            <DropdownMenuTrigger asChild={True}>
                <button
                    type="button"
                    aria-label="Account menu"
                    className="inline-flex size-10 shrink-0 items-center justify-center rounded-full transition-colors hover:bg-accent sm:size-8"
                >
                    {if orgName {
                        <Avatar key="av" name={orgName} size="sm"/>
                    } else {
                        <span
                            key="blank"
                            className="size-6 rounded-full border border-input bg-muted"
                        />
                    } }
                </button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" sideOffset={6} className="w-64">
                <DropdownMenuLabel className="flex flex-col gap-0.5 px-2 py-1.5">
                    <span className="truncate text-sm font-semibold text-foreground">
                        {orgName or "Your workspace"}
                    </span>
                    {if account {
                        <span
                            key="who"
                            className="truncate text-xs font-normal text-muted-foreground"
                        >
                            {account}
                        </span>
                    }}
                </DropdownMenuLabel>
                <DropdownMenuSeparator/>
                <DropdownMenuItem asChild={True}>
                    <Link to="/workspace" className="gap-2 px-2 py-1.5">
                        <PageIcon name="workspace" className="text-muted-foreground"/>
                        Workspace settings
                    </Link>
                </DropdownMenuItem>
                <DropdownMenuItem asChild={True}>
                    <Link to="/workspace?tab=preferences" className="gap-2 px-2 py-1.5">
                        <PageIcon name="preferences" className="text-muted-foreground"/>
                        Preferences
                    </Link>
                </DropdownMenuItem>
                <DropdownMenuSub>
                    <DropdownMenuSubTrigger className="gap-2 px-2 py-1.5">
                        <PageIcon name="theme" className="text-muted-foreground"/>
                        Theme
                        <span className="ml-auto text-xs text-muted-foreground">
                            {themeLabel}
                        </span>
                    </DropdownMenuSubTrigger>
                    <DropdownMenuSubContent className="w-36">
                        <DropdownMenuRadioGroup
                            value={themeChoice}
                            onValueChange={onTheme}
                        >
                            {for choice in THEME_CHOICES {
                                <DropdownMenuRadioItem
                                    key={choice["value"]}
                                    value={choice["value"]}
                                    className="px-2 py-1.5"
                                >
                                    {choice["label"]}
                                </DropdownMenuRadioItem>
                            }}
                        </DropdownMenuRadioGroup>
                    </DropdownMenuSubContent>
                </DropdownMenuSub>
                <DropdownMenuSeparator/>
                <DropdownMenuItem
                    className="gap-2 px-2 py-1.5"
                    onSelect={lambda { onSignOut(); }}
                >
                    <PageIcon name="signout" className="text-muted-foreground"/>
                    Sign out
                </DropdownMenuItem>
            </DropdownMenuContent>
        </DropdownMenu>;
}

def:pub Shell -> JsxLayout {
    has loggedIn: bool = False,
        orgName: str = "",
        # The signed-in email (or login) for the account menu.
        account: str = "",
        # Not `themePref`: its generated setter would shadow the imported
        # setThemePref, silently breaking the toggle (issue #131).
        themeChoice: str = "system",
        paletteOpen: bool = False,
        askOpen: bool = False,
        moreOpen: bool = False,
        # Viewport bands: Ask docks at 1280px and up; the tab bar is below 640px.
        wide: bool = False,
        narrow: bool = False,
        prevPath: Ref[any] = Ref();

    async can with entry {
        applyTheme(getThemePref());
        watchTheme();
        themeChoice = getThemePref();
        w: any = window;
        wide = bool(w.matchMedia("(min-width: 1280px)").matches);
        narrow = not bool(w.matchMedia("(min-width: 640px)").matches);
        isIn = jacIsLoggedIn();
        loggedIn = isIn;
        if isIn {
            loadMe();
        }
    }

    # ⌘K / Ctrl+K opens the palette and ⌘/ / Ctrl+/ toggles Ask, on app pages
    # other than the setup wizard (Ctrl+J is Chrome's downloads on Windows).
    useEffect(
        lambda {
            onKey = lambda (e: any) {
                path = str(window.location.pathname);
                live = jacIsLoggedIn()
                    and path not in PUBLIC_PATHS
                    and path != "/setup";
                if live and (e.metaKey or e.ctrlKey) {
                    key = str(e.key).lower();
                    if key == "k" {
                        e.preventDefault();
                        paletteOpen = True;
                    } elif key == "/" or e.code == "Slash" {
                        e.preventDefault();
                        askOpen = not askOpen;
                    }
                }
            };
            window.addEventListener("keydown", onKey);
            return lambda { window.removeEventListener("keydown", onKey); };
        },
        []
    );

    # Window events and viewport bands: the workspace rename (C3), a theme
    # change made elsewhere, the palette's Ask action, and the two breakpoints.
    useEffect(
        lambda {
            w: any = window;
            onRenamed = lambda (e: any) {
                name = str(e.detail.name or "") if e.detail else "";
                if name {
                    orgName = name;
                }
            };
            onTheme = lambda (e: any) { themeChoice = getThemePref(); };
            onAsk = lambda (e: any) { askOpen = True; };
            wideQ: any = w.matchMedia("(min-width: 1280px)");
            smQ: any = w.matchMedia("(min-width: 640px)");
            onWide = lambda (e: any) { wide = bool(e.matches); };
            onSm = lambda (e: any) { narrow = not bool(e.matches); };
            w.addEventListener("flowline:org-renamed", onRenamed);
            w.addEventListener("flowline:theme", onTheme);
            w.addEventListener("flowline:ask", onAsk);
            wideQ.addEventListener("change", onWide);
            smQ.addEventListener("change", onSm);
            return lambda {
                w.removeEventListener("flowline:org-renamed", onRenamed);
                w.removeEventListener("flowline:theme", onTheme);
                w.removeEventListener("flowline:ask", onAsk);
                wideQ.removeEventListener("change", onWide);
                smQ.removeEventListener("change", onSm);
            };
        },
        []
    );

    async def loadMe -> None;
    def logout -> None;
    def pickTheme(pref: str) -> None;

    location = useLocation();
    path = str(location.pathname);

    # A route change closes the More sheet; leaving /setup rereads the name
    # the wizard just saved.
    useEffect(
        lambda {
            moreOpen = False;
            if prevPath.current == "/setup" and path != "/setup" {
                loadMe();
            }
            prevPath.current = path;
        },
        [path]
    );

    chrome = loggedIn and path not in PUBLIC_PATHS;
    setup = path == "/setup";
    mod = modKey();

    def isActive(to: str) -> bool {
        return path == to or path.startswith(to + "/");
    }

    def linkClass(to: str, quiet: bool) -> str {
        size = "text-[13px] " if quiet else "text-[13.5px] ";
        base = "inline-flex h-8 shrink-0 items-center whitespace-nowrap px-2.5 transition-colors ";
        if isActive(to) {
            return base
                + size
                + "font-semibold text-foreground shadow-[inset_0_-2px_0_var(--primary)]";
        }
        return base
            + size
            + "rounded-md text-muted-foreground hover:bg-accent hover:text-foreground";
    }

    daily = [
        p
        for p in NAV_PAGES
        if p["group"] == "daily"
    ];
    setupPages = [
        p
        for p in NAV_PAGES
        if p["group"] == "setup"
    ];
    tabs = [
        p
        for p in NAV_PAGES
        if p["key"] in TAB_KEYS
    ];
    morePages = [
        p
        for p in NAV_PAGES
        if p["key"] not in TAB_KEYS
    ];
    setupActive = False;
    for p in setupPages {
        if isActive(p["to"]) {
            setupActive = True;
        }
    }
    moreActive = False;
    title = EXTRA_TITLES[path] if path in EXTRA_TITLES else "";
    for p in morePages {
        if isActive(p["to"]) {
            moreActive = True;
        }
    }
    for p in NAV_PAGES {
        if isActive(p["to"]) {
            title = p["label"];
        }
    }

    dockOpen = askOpen and wide and chrome and not setup;
    tabBar = chrome and not setup;
    # Toasts sit bottom right, left of the docked column. While the Ask sheet is
    # open they move to the top, off its composer (top left beside a side sheet).
    sheetOpen = askOpen and not wide and tabBar;
    toastPosition = ("top-center" if narrow else "top-left")
        if sheetOpen
        else "bottom-right";
    toastOffset: dict[str, str] = {
        "top": "24px",
        "left": "24px",
        "right": "376px" if dockOpen else "24px",
        "bottom": TAB_CLEAR if narrow and tabBar else "24px"
    };
    toastMobile: dict[str, str] = {
        "top": "calc(12px + env(safe-area-inset-top))",
        "bottom": TAB_CLEAR if tabBar else "16px"
    };
    toastIcons: dict[str, any] = {
        "success": <KindGlyph kind="done" size={16} className="text-success"/>,
        "error": <KindGlyph kind="blocked" size={16} className="text-destructive"/>,
        "warning": <WarnIcon size={16} className="text-warning"/>
    };
    toastOptions: dict[str, any] = {
        "classNames": {
            "toast": "rounded-xl! border-border! font-sans! text-[13.5px]! shadow-xl!",
            "title": "font-medium!",
            "description": "text-muted-foreground!",
            "error": "border-l-2! border-l-destructive!"
        }
    };

    return
        <div className="min-h-screen bg-background text-foreground">
            {if chrome and setup {
                <header
                    key="setupbar"
                    className="sticky top-0 z-40 h-12 border-b bg-card"
                >
                    <div className="flex h-full items-center gap-2 px-4 sm:px-6">
                        <Mark/>
                        <span
                            className="min-w-0 truncate text-sm font-bold [font-stretch:108%]"
                        >
                            {orgName or "flowline"}
                        </span>
                        <button
                            type="button"
                            className="ml-auto inline-flex h-8 items-center gap-2 rounded-md px-2.5 text-[13px] font-medium text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
                            onClick={logout}
                        >
                            <PageIcon name="signout"/>
                            Sign out
                        </button>
                    </div>
                </header>
            } elif chrome {
                <header key="nav" className="sticky top-0 z-40 h-12 border-b bg-card">
                    <nav
                        aria-label="Pages"
                        className="hidden h-full items-center gap-0.5 px-4 sm:flex lg:px-5"
                    >
                        <Link
                            to="/board"
                            className="mr-2 flex min-w-6 shrink items-center gap-2 rounded-md py-1 pr-1 lg:mr-3"
                            aria-label={(orgName or "flowline") + " home"}
                        >
                            <Mark/>
                            <span
                                className="hidden min-w-0 max-w-[11rem] truncate text-sm font-bold [font-stretch:108%] lg:inline xl:max-w-[16rem]"
                            >
                                {orgName or "flowline"}
                            </span>
                        </Link>
                        {for p in daily {
                            <Link
                                key={p["key"]}
                                to={p["to"]}
                                aria-current={"page" if isActive(p["to"]) else None}
                                className={linkClass(p["to"], False)}
                            >
                                {p["label"]}
                            </Link>
                        }}
                        <span
                            aria-hidden="true"
                            className="mx-2 hidden h-5 w-px shrink-0 bg-border lg:block"
                        />
                        <div className="hidden items-center gap-0.5 lg:flex">
                            {for p in setupPages {
                                <Link
                                    key={p["key"]}
                                    to={p["to"]}
                                    aria-current={"page" if isActive(p["to"]) else None}
                                    className={linkClass(p["to"], True)}
                                >
                                    {p["label"]}
                                </Link>
                            }}
                        </div>
                        <div className="lg:hidden">
                            <DropdownMenu>
                                <DropdownMenuTrigger asChild={True}>
                                    <button
                                        type="button"
                                        className={"inline-flex h-8 items-center gap-1 whitespace-nowrap px-2.5 text-[13px] transition-colors "
                                            + (
                                                "font-semibold text-foreground shadow-[inset_0_-2px_0_var(--primary)]"
                                                    if setupActive
                                                    else "rounded-md text-muted-foreground hover:bg-accent hover:text-foreground"
                                            )}
                                    >
                                        More
                                        <PageIcon name="chevron" size={14}/>
                                    </button>
                                </DropdownMenuTrigger>
                                <DropdownMenuContent align="start" className="w-48">
                                    {for p in setupPages {
                                        <DropdownMenuItem key={p["key"]} asChild={True}>
                                            <Link
                                                to={p["to"]}
                                                aria-current={"page"
                                                    if isActive(p["to"])
                                                    else None}
                                                className={"gap-2 px-2 py-1.5 "
                                                    + (
                                                        "font-semibold"
                                                            if isActive(p["to"])
                                                            else ""
                                                    )}
                                            >
                                                <PageIcon
                                                    name={p["key"]}
                                                    className="text-muted-foreground"
                                                />
                                                {p["label"]}
                                            </Link>
                                        </DropdownMenuItem>
                                    }}
                                </DropdownMenuContent>
                            </DropdownMenu>
                        </div>
                        <div
                            className="ml-auto flex shrink-0 items-center gap-1.5 pl-3"
                        >
                            <button
                                type="button"
                                aria-label="Search or jump"
                                title={"Search or jump (" + mod + "K)"}
                                className="inline-flex h-[30px] items-center gap-2 rounded-md border bg-background px-2 text-[13px] text-subtle transition-colors hover:bg-accent hover:text-foreground"
                                onClick={lambda { paletteOpen = True; }}
                            >
                                <PageIcon name="search"/>
                                <span className="kbd hidden md:inline-flex">
                                    {mod + "K"}
                                </span>
                            </button>
                            <button
                                type="button"
                                data-ask-trigger="true"
                                aria-pressed={askOpen}
                                title={"Ask about this workspace (" + mod + "/)"}
                                className={"inline-flex h-[30px] items-center gap-1.5 rounded-md px-2 text-[13px] font-medium transition-colors hover:bg-accent hover:text-foreground "
                                    + (
                                        "bg-accent text-foreground"
                                            if askOpen
                                            else "text-muted-foreground"
                                    )}
                                onClick={lambda { askOpen = not askOpen; }}
                            >
                                <PageIcon name="ask"/>
                                Ask
                                <span className="kbd hidden md:inline-flex">
                                    {mod + "/"}
                                </span>
                            </button>
                            <AccountMenu
                                orgName={orgName}
                                account={account}
                                themeChoice={themeChoice}
                                onTheme={pickTheme}
                                onSignOut={logout}
                            />
                        </div>
                    </nav>
                    <div className="flex h-full items-center gap-2 pr-2 pl-4 sm:hidden">
                        <Link
                            to="/board"
                            aria-label={(orgName or "flowline") + " home"}
                            className="-m-1 rounded-md p-1"
                        >
                            <Mark/>
                        </Link>
                        <span
                            className="min-w-0 truncate text-[15px] font-bold [font-stretch:108%]"
                        >
                            {title}
                        </span>
                        <button
                            type="button"
                            aria-label="Search or jump"
                            className="ml-auto inline-flex size-10 items-center justify-center rounded-md text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
                            onClick={lambda { paletteOpen = True; }}
                        >
                            <PageIcon name="search" size={18}/>
                        </button>
                        <AccountMenu
                            orgName={orgName}
                            account={account}
                            themeChoice={themeChoice}
                            onTheme={pickTheme}
                            onSignOut={logout}
                        />
                    </div>
                </header>
            } }
            {if chrome {
                <div key="app" className="flex w-full items-start">
                    <main
                        className={"min-w-0 flex-1 px-4 pt-6 sm:px-6 sm:pb-6 lg:px-10 lg:pt-8 lg:pb-8 "
                            + (
                                "pb-6"
                                    if setup
                                    else "pb-[calc(5rem+env(safe-area-inset-bottom))]"
                            )}
                    >
                        <Outlet/>
                    </main>
                    {if not setup {
                        <AssistantDock
                            key="assistant"
                            open={askOpen}
                            onOpenChange={lambda (o: bool) { askOpen = o; }}
                            docked={wide}
                            narrow={narrow}
                        />
                    }}
                </div>
            } else {
                <Outlet key="bare"/>
            } }
            {if tabBar {
                <nav
                    key="tabs"
                    aria-label="Pages"
                    className="fixed inset-x-0 bottom-0 z-40 grid grid-cols-5 border-t bg-card pb-[env(safe-area-inset-bottom)] sm:hidden"
                >
                    {for p in tabs {
                        <Link
                            key={p["key"]}
                            to={p["to"]}
                            aria-current={"page" if isActive(p["to"]) else None}
                            className={"flex h-14 flex-col items-center justify-center gap-1 text-xs "
                                + (
                                    "font-semibold text-primary"
                                        if isActive(p["to"])
                                        else "font-medium text-muted-foreground"
                                )}
                        >
                            <PageIcon name={p["key"]} size={20}/>
                            {p["label"]}
                        </Link>
                    }}
                    <button
                        type="button"
                        aria-haspopup="dialog"
                        aria-expanded={moreOpen}
                        className={"flex h-14 flex-col items-center justify-center gap-1 text-xs "
                            + (
                                "font-semibold text-primary"
                                    if moreActive
                                    else "font-medium text-muted-foreground"
                            )}
                        onClick={lambda { moreOpen = True; }}
                    >
                        <PageIcon name="more" size={20}/>
                        More
                    </button>
                </nav>
            }}
            {if tabBar {
                <Sheet
                    key="more"
                    open={moreOpen}
                    onOpenChange={lambda (o: bool) { moreOpen = o; }}
                >
                    <SheetContent
                        side="bottom"
                        className="max-h-[88dvh] gap-0 overflow-y-auto rounded-t-xl p-0 pb-[env(safe-area-inset-bottom)]"
                    >
                        <SheetHeader className="px-4 pt-4 pb-2">
                            <SheetTitle className="text-[15px] font-semibold">
                                More
                            </SheetTitle>
                        </SheetHeader>
                        <div className="grid px-2 pb-2">
                            {for p in morePages {
                                <Link
                                    key={p["key"]}
                                    to={p["to"]}
                                    aria-current={"page" if isActive(p["to"]) else None}
                                    onClick={lambda { moreOpen = False; }}
                                    className={"flex h-12 items-center gap-3 rounded-md px-3 text-[15px] "
                                        + (
                                            "bg-accent font-semibold text-foreground"
                                                if isActive(p["to"])
                                                else "text-foreground"
                                        )}
                                >
                                    <PageIcon
                                        name={p["key"]}
                                        size={18}
                                        className="text-muted-foreground"
                                    />
                                    {p["label"]}
                                </Link>
                            }}
                            <button
                                type="button"
                                className="flex h-12 items-center gap-3 rounded-md px-3 text-left text-[15px] text-foreground"
                                onClick={lambda {
                                    moreOpen = False;
                                    askOpen = True;
                                }}
                            >
                                <PageIcon
                                    name="ask"
                                    size={18}
                                    className="text-muted-foreground"
                                />
                                Ask about this workspace
                            </button>
                        </div>
                        <div
                            className="flex items-center justify-between gap-3 border-t px-5 py-3"
                        >
                            <span className="text-sm text-muted-foreground">Theme</span>
                            <div
                                className="inline-flex rounded-md bg-muted p-0.5"
                                role="group"
                                aria-label="Theme"
                            >
                                {for choice in THEME_CHOICES {
                                    <button
                                        key={choice["value"]}
                                        type="button"
                                        aria-pressed={themeChoice == choice["value"]}
                                        onClick={lambda { pickTheme(choice["value"]); }}
                                        className={"h-8 rounded-sm border px-3 text-[13px] "
                                            + (
                                                "bg-card font-semibold text-foreground"
                                                    if themeChoice == choice["value"]
                                                    else "border-transparent font-medium text-muted-foreground"
                                            )}
                                    >
                                        {choice["label"]}
                                    </button>
                                }}
                            </div>
                        </div>
                        <div className="grid border-t px-2 py-2">
                            <div className="px-3 py-2">
                                <div className="truncate text-sm font-semibold">
                                    {orgName or "Your workspace"}
                                </div>
                                {if account {
                                    <div
                                        key="who"
                                        className="truncate text-xs text-muted-foreground"
                                    >
                                        {account}
                                    </div>
                                }}
                            </div>
                            <Link
                                to="/workspace?tab=preferences"
                                onClick={lambda { moreOpen = False; }}
                                className="flex h-12 items-center gap-3 rounded-md px-3 text-[15px]"
                            >
                                <PageIcon
                                    name="preferences"
                                    size={18}
                                    className="text-muted-foreground"
                                />
                                Preferences
                            </Link>
                            <button
                                type="button"
                                onClick={logout}
                                className="flex h-12 items-center gap-3 rounded-md px-3 text-left text-[15px]"
                            >
                                <PageIcon
                                    name="signout"
                                    size={18}
                                    className="text-muted-foreground"
                                />
                                Sign out
                            </button>
                        </div>
                    </SheetContent>
                </Sheet>
            }}
            {if chrome and not setup {
                <CommandPalette
                    key="palette"
                    open={paletteOpen}
                    onOpenChange={lambda (o: bool) { paletteOpen = o; }}
                />
            }}
            <Toaster
                position={toastPosition}
                offset={toastOffset}
                mobileOffset={toastMobile}
                icons={toastIcons}
                toastOptions={toastOptions}
            />
        </div>;
}
