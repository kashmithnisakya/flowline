"""flowline - SSO landing page. jac-scale's /sso/{platform}/callback finishes
the OAuth exchange and redirects here with ?token=<jwt> (or ?error=&message=);
this page stores the token like a password login would and hands off.
"""

import from "@jac/runtime" { jacSetToken }
import from ....lib.session { fetchProfile, forgetSession }
import from ....components.ui.button { Button }
import from ....components.common.glyphs { WarnIcon }
import from ....components.landing.Wordmark { Wordmark }

# Both mounts of the page load share one profile read.
glob LANDING: dict[str, any] = {"promise": None};

# A new account has no workspace name yet, so it goes straight to setup.
async def landingPath -> str {
    profile = await fetchProfile();
    named = str(profile["org_name"]).strip() if profile["org_name"] else "";
    return "/board" if named else "/setup";
}

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

    async can with entry {
        token = param("token");
        problem = param("message") or param("error");
        if token {
            jacSetToken(token);
            # A fresh session drops the cached workspace name, as a password
            # login does.
            forgetSession();
            # Same marker a password login sets, so a later 401 can tell
            # this apart from a cold arrival at /login.
            localStorage.setItem("flowline_session", "1");
            if not LANDING["promise"] {
                LANDING["promise"] = landingPath();
            }
            path: str = await LANDING["promise"];
            window.location.replace(path);
        } else {
            failure = problem or "Sign-in was cancelled or failed.";
        }
    }

    return
        <div className="min-h-svh bg-background px-4 text-foreground sm:px-6">
            <div className="landing-wrap flex h-14 items-center">
                <a href="/" aria-label="flowline home" className="rounded-sm">
                    <Wordmark/>
                </a>
            </div>
            <main className="mx-auto w-full max-w-[400px] pt-8 pb-16 sm:pt-16">
                {if failure {
                    <div key="failed" role="alert" className="grid gap-3">
                        <h1
                            className="flex items-center gap-2 text-[30px] leading-[1.12] font-bold tracking-[-0.025em]"
                        >
                            <WarnIcon size={22} className="shrink-0 text-destructive"/>
                            Could not sign you in
                        </h1>
                        <p className="text-sm text-muted-foreground">{failure}</p>
                        <Button
                            className="mt-2 h-10 w-full text-sm font-semibold"
                            onClick={lambda { window.location.href = "/login"; }}
                        >
                            Back to sign in
                        </Button>
                    </div>
                } else {
                    <div
                        key="working"
                        role="status"
                        className="flex items-center gap-3 text-sm text-muted-foreground"
                    >
                        <span
                            aria-hidden="true"
                            className="size-5 animate-spin rounded-full border-2 border-primary border-t-transparent"
                        ></span>
                        Signing you in…
                    </div>
                } }
            </main>
        </div>;
}
