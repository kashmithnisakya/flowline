"""App-wide keys on app pages other than the setup wizard: ⌘K / Ctrl+K opens
the palette and ⌘/ / Ctrl+/ toggles Ask (Ctrl+J is Chrome's downloads on
Windows). Renders nothing."""

import from "@jac/runtime" { jacIsLoggedIn }
import from "react" { useEffect }

glob QUIET_PATHS: list[str] = ["/", "/login", "/auth/callback", "/setup"];

def:pub Shortcuts(
    onPalette: Callable[[], None], onAsk: Callable[[], None]
) -> JsxElement {
    useEffect(
        lambda {
            onKey = lambda (e: any) {
                live = jacIsLoggedIn()
                    and str(window.location.pathname) not in QUIET_PATHS;
                if live and (e.metaKey or e.ctrlKey) {
                    key = str(e.key).lower();
                    if key == "k" {
                        e.preventDefault();
                        onPalette();
                    } elif key == "/" or e.code == "Slash" {
                        e.preventDefault();
                        onAsk();
                    }
                }
            };
            window.addEventListener("keydown", onKey);
            return lambda { window.removeEventListener("keydown", onKey); };
        },
        []
    );
    return <></>;
}
