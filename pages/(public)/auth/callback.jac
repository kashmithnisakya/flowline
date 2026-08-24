"""flowline - SSO landing page. jac-scale's /sso/{platform}/callback finishes
the OAuth exchange and redirects here with ?token=<jwt> (or ?error=&message=);
this page stores the token like a password login would and hands off.
"""

import from "@jac/runtime" { jacSetToken }
import from ....components.ui.button { Button }
import from ....components.common.glyphs { WarnIcon }

def:pub SsoCallbackPage -> JsxPage {
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
            failure = problem or "Sign-in was cancelled or failed.";
        }
    }

    return
        <div
            className="flex min-h-[70svh] flex-col items-center justify-center gap-4 px-6 text-center"
        >
            {if failure {
                <div
                    key="failed"
                    className="w-full max-w-sm rounded-2xl border border-border bg-card p-8 shadow-sm animate-in fade-in slide-in-from-bottom-2 duration-300"
                >
                    <div
                        className="mx-auto flex size-12 items-center justify-center rounded-full bg-destructive/10 text-destructive"
                    >
                        <WarnIcon size={20}/>
                    </div>
                    <h1 className="font-display mt-4 text-2xl font-bold tracking-tight">
                        Could not sign you in
                    </h1>
                    <p className="mt-2 text-sm text-muted-foreground">{failure}</p>
                    <Button
                        className="mt-5 h-11 w-full"
                        onClick={lambda { window.location.href = "/login"; }}
                    >
                        Back to sign in
                    </Button>
                </div>
            } else {
                <div
                    key="working"
                    className="flex flex-col items-center gap-5 animate-in fade-in duration-500"
                >
                    <img
                        src="/static/brand/logo-full.svg"
                        alt="flowline"
                        width={150}
                        height={40}
                        className="dark:hidden"
                    />
                    <img
                        src="/static/brand/logo-full-dark.svg"
                        alt="flowline"
                        width={150}
                        height={40}
                        className="hidden dark:block"
                    />
                    <span
                        aria-hidden="true"
                        className="size-8 animate-spin rounded-full border-2 border-primary border-t-transparent"
                    ></span>
                    <p className="text-sm text-muted-foreground">Signing you in…</p>
                </div>
            } }
        </div>;
}
