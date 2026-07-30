"""standup - root layout: top nav, WhoAmI picker, page outlet, toaster."""

import from "@jac/runtime" { Outlet, Link }
import from endpoints { Member, ListMembers }
import from ..components.WhoAmIPicker { WhoAmIPicker }
import from ..components.ui.sonner { Toaster }
import from "react" { useEffect }

def:pub Shell() -> JsxLayout {
    has members: list[Member] = [],
        whoAmI: str = "";

    async can with entry {
        stored = localStorage.getItem("standup_who") or "";
        if stored {
            whoAmI = stored;
        }
        loadMembers();
    }

    # Keep the picker in sync with roster edits made on other pages/tabs.
    useEffect(lambda {
        onFocus = lambda { loadMembers(); };
        window.addEventListener("focus", onFocus);
        return lambda {
            window.removeEventListener("focus", onFocus);
        };
    }, []);

    async def loadMembers -> None;
    def setWho(memberId: str) -> None;

    <div className="min-h-screen bg-background text-foreground">
        <header className="border-b">
            <nav className="mx-auto flex max-w-7xl items-center gap-6 px-6 py-3">
                <span className="text-lg font-semibold tracking-tight">standup</span>
                <Link to="/" className="text-sm text-muted-foreground transition-colors hover:text-foreground">
                    Board
                </Link>
                <Link to="/log" className="text-sm text-muted-foreground transition-colors hover:text-foreground">
                    Daily Log
                </Link>
                <Link to="/roster" className="text-sm text-muted-foreground transition-colors hover:text-foreground">
                    Roster
                </Link>
                <div className="ml-auto">
                    <WhoAmIPicker
                        members={[m for m in members if m.active]}
                        value={whoAmI}
                        onChange={setWho}
                    />
                </div>
            </nav>
        </header>
        <main className="mx-auto max-w-7xl px-6 py-6">
            <Outlet />
        </main>
        <Toaster />
    </div>
}
