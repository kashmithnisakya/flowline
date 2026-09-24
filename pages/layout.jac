"""flowline - root layout. App pages get the left sidebar at md and up, and a
header over a bottom tab bar below it; the ⌘K palette and Ask (docked at
1280px and up, a sheet below) sit over both. /setup gets the setup bar only.
Login state and the cached workspace name are read at render, so the first
render is the real chrome and a page mounts once."""

import from "@jac/runtime" { Outlet, useLocation, jacIsLoggedIn, jacLogout }
import from "react" { useEffect }
import from ..lib.theme { getThemePref, applyTheme, watchTheme, setThemePref }
import from ..lib.session {
    cachedOrgName,
    cachedAccount,
    rememberOrgName,
    rememberAccount,
    forgetSession,
    fetchMe
}
import from ..components.common.CommandPalette { CommandPalette, NAV_PAGES, modKey }
import from ..components.chrome.Sidebar { Sidebar }
import from ..components.chrome.SidebarLink { isCurrent }
import from ..components.chrome.PhoneHeader { PhoneHeader }
import from ..components.chrome.TabBar { TabBar }
import from ..components.chrome.SetupBar { SetupBar }
import from ..components.chrome.Shortcuts { Shortcuts }
import from ..components.chrome.ChromeEvents { ChromeEvents }
import from ..components.chrome.Toasts { Toasts }
import from ..components.assistant.AssistantDock { AssistantDock }

glob PUBLIC_PATHS: list[str] = ["/", "/login", "/auth/callback"];

def:pub Shell -> JsxLayout {
    # Not `themePref`: its generated setter would shadow the imported
    # setThemePref (issue #131). `wide` docks Ask; `narrow` is below md.
    has loggedIn: bool = jacIsLoggedIn(),
        orgName: str = cachedOrgName(),
        account: str = cachedAccount(),
        themeChoice: str = "system",
        paletteOpen: bool = False,
        askOpen: bool = False,
        wide: bool = False,
        narrow: bool = False,
        prevPath: Ref[any] = Ref();

    async can with entry {
        applyTheme(getThemePref());
        watchTheme();
        themeChoice = getThemePref();
        if loggedIn {
            loadMe();
        }
    }

    async def loadMe -> None;
    def logout -> None;
    def pickTheme(pref: str) -> None;

    path = str(useLocation().pathname);
    # Leaving /setup rereads the name the wizard just saved.
    useEffect(
        lambda {
            if prevPath.current == "/setup" and path != "/setup" {
                loadMe();
            }
            prevPath.current = path;
        },
        [path]
    );

    chrome = loggedIn and path not in PUBLIC_PATHS;
    app = chrome and path != "/setup";
    title = "Setup" if path == "/setup" else "";
    for p in NAV_PAGES {
        if isCurrent(path, p["to"]) {
            title = p["label"];
        }
    }
    mod = modKey();
    openPalette = lambda { paletteOpen = True; };
    toggleAsk = lambda { askOpen = not askOpen; };

    if not chrome {
        return
            <div className="min-h-screen bg-background text-foreground">
                <Outlet/>
                <Toasts narrow={narrow} askSheet={False} docked={False} tabBar={False}/>
            </div>;
    }
    if not app {
        return
            <div className="min-h-screen bg-background text-foreground">
                <SetupBar orgName={orgName} onSignOut={logout}/>
                <main className="px-4 pt-6 pb-6 sm:px-6 lg:px-10 lg:pt-8">
                    <Outlet/>
                </main>
                <Toasts narrow={narrow} askSheet={False} docked={False} tabBar={False}/>
            </div>;
    }
    return
        <div className="flex min-h-screen items-start bg-background text-foreground">
            <Sidebar
                path={path}
                orgName={orgName}
                account={account}
                themeChoice={themeChoice}
                askOpen={askOpen}
                mod={mod}
                onSearch={openPalette}
                onAsk={toggleAsk}
                onTheme={pickTheme}
                onSignOut={logout}
            />
            <div className="min-w-0 flex-1">
                <PhoneHeader
                    title={title}
                    orgName={orgName}
                    account={account}
                    themeChoice={themeChoice}
                    onSearch={openPalette}
                    onAsk={toggleAsk}
                    onTheme={pickTheme}
                    onSignOut={logout}
                />
                <main
                    className="px-4 pt-5 pb-[calc(5rem+env(safe-area-inset-bottom))] sm:px-6 md:px-10 md:pt-8 md:pb-10"
                >
                    <Outlet/>
                </main>
            </div>
            <AssistantDock
                open={askOpen}
                onOpenChange={lambda (o: bool) { askOpen = o; }}
                docked={wide}
                narrow={narrow}
            />
            <TabBar path={path}/>
            <CommandPalette
                open={paletteOpen}
                onOpenChange={lambda (o: bool) { paletteOpen = o; }}
            />
            <Shortcuts onPalette={openPalette} onAsk={toggleAsk}/>
            <ChromeEvents
                onRenamed={lambda (name: str) {
                    orgName = name;
                    rememberOrgName(name);
                }}
                onTheme={lambda { themeChoice = getThemePref(); }}
                onAsk={lambda { askOpen = True; }}
                onWide={lambda (v: bool) { wide = v; }}
                onNarrow={lambda (v: bool) { narrow = v; }}
            />
            <Toasts
                narrow={narrow}
                askSheet={askOpen and not wide}
                docked={askOpen and wide}
                tabBar={True}
            />
        </div>;
}
