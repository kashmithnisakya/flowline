"""standup - SSO landing page.

jac-scale's /sso/{platform}/callback finishes the OAuth exchange and then
redirects the browser here as `?token=<jwt>` (or `?error=CODE&message=...`),
using [scale.sso] client_auth_callback_url. All this page does is store the
token the same way a password login would and hand off to the app.
"""

import from "@jac/runtime" { jacSetToken }
import from ....components.ui.button { Button }

def:pub SsoCallbackPage() -> JsxPage {
    has failure: str = "";

    # Reads one query-string value. URLSearchParams is untyped here, so the
    # parse is done by hand to keep the checker happy.
    def param(name: str) -> str {
        search: str = window.location.search;
        if not search {
            return "";
        }
        for pair in search[1:].split("&") {
            bits: list[str] = pair.split("=");
            if len(bits) == 2 and bits[0] == name {
                return decodeURIComponent(bits[1].replace("+", " "));
            }
        }
        return "";
    }

    can with entry {
        token = param("token");
        problem = param("message") or param("error");
        if token {
            jacSetToken(token);
            # Same marker a password login sets, so a later 401 can tell
            # this apart from a cold arrival at /login.
            localStorage.setItem("standup_session", "1");
            window.location.href = "/board";
        } else {
            failure = problem if problem else "Sign-in was cancelled or failed.";
        }
    }

    <div className="flex min-h-[70svh] flex-col items-center justify-center gap-4 px-6 text-center">
        {if failure {
            <div key="failed" className="max-w-sm space-y-4">
                <h1 className="font-display text-2xl font-bold tracking-tight">
                    Could not sign you in
                </h1>
                <p className="text-sm text-muted-foreground">{failure}</p>
                <Button onClick={lambda { window.location.href = "/login"; }}>
                    Back to sign in
                </Button>
            </div>
        } else {
            <p key="working" className="text-sm text-muted-foreground">
                Signing you in…
            </p>
        }}
    </div>
}
