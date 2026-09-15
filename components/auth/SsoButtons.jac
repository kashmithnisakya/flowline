"""Google and GitHub sign-in over jac-scale's /sso/{platform}/{operation}. A
button renders only for a provider the server holds credentials for. The probe
follows /sso/{platform}/callback, which redirects to our callback page with
?error=SSO_NOT_CONFIGURED when it has none: no 4xx or 5xx, and nothing written."""

import from ..common.glyphs { Spinner }

glob PROVIDERS: list[dict[str, str]] = [
         {"key": "google", "label": "Google"},
         {"key": "github", "label": "GitHub"}
     ],
     # Both mounts of a full page load share the one in-flight probe.
     PROBE: dict[str, any] = {"promise": None},
     # The last answer ("none" for no providers), so a return visit draws the
     # buttons at once; the session flag skips re-probing within one tab.
     SSO_CACHE: str = "flowline-sso",
     SSO_PROBED: str = "flowline-sso-probed";

# The last probe's answer, or None when this browser never probed.
def cachedAnswer -> list[str] | None {
    try {
        raw: any = localStorage.getItem(SSO_CACHE);
        if raw == "none" {
            return [];
        }
        if raw {
            return str(raw).split(",");
        }
    } except Exception {
        return None;
    }
    return None;
}

def cachedProviders -> list[str] {
    answer = cachedAnswer();
    return answer or [];
}

def probedThisSession -> bool {
    try {
        return sessionStorage.getItem(SSO_PROBED) == "1" and cachedAnswer() is not None;
    } except Exception {
        return False;
    }
}

def rememberProviders(found: list[str]) -> None {
    try {
        localStorage.setItem(SSO_CACHE, ",".join(found) if len(found) > 0 else "none");
        sessionStorage.setItem(SSO_PROBED, "1");
    } except Exception {
        return;
    }
}

# True when the callback redirect carries any error but "not configured" (a
# configured provider rejects the missing state instead). No redirect means
# the answer is unknown, which hides the button.
async def probeProvider(platform: str) -> bool {
    try {
        res: any = await fetch(
            window.location.origin + "/sso/" + platform + "/callback",
            {"cache": "no-store"}
        );
        landed = str(res.url);
        return bool(res.redirected)
            and "error=" in landed
            and "SSO_NOT_CONFIGURED" not in landed;
    } except Exception as e {
        return False;
    }
}

async def probeAll -> list[str] {
    started: list[any] = [probeProvider(p["key"]) for p in PROVIDERS];
    found: list[str] = [];
    for (i, p) in enumerate(PROVIDERS) {
        ok = await started[i];
        if ok {
            found = found + [p["key"]];
        }
    }
    rememberProviders(found);
    return found;
}

def configuredProviders -> any {
    if not PROBE["promise"] {
        PROBE["promise"] = probeAll();
    }
    return PROBE["promise"];
}

# Joins provider labels for a sentence: "Google", "Google or GitHub".
def providerPhrase(found: list[str]) -> str {
    names: list[str] = [
        p["label"]
        for p in PROVIDERS
        if p["key"] in found
    ];
    return " or ".join(names);
}

def:pub SsoButtons(operation: str, onFailure: Callable[[str], None]) -> JsxElement {
    has pending: str = "",
        found: list[str] = cachedProviders();

    async can with entry {
        if not probedThisSession() {
            fresh: list[str] = await configuredProviders();
            found = fresh;
        }
    }

    async def start(platform: str) -> None;

    btn = "flex h-10 w-full items-center justify-center gap-2 rounded-md border border-input bg-card px-3 text-sm font-semibold transition-colors duration-150 hover:bg-accent disabled:pointer-events-none disabled:opacity-60";

    return
        <div className={"grid gap-2" if len(found) > 0 else "hidden"}>
            {for p in PROVIDERS {
                if p["key"] in found {
                    <button
                        key={p["key"]}
                        type="button"
                        disabled={pending != ""}
                        className={btn}
                        onClick={lambda { start(p["key"]); }}
                    >
                        {if pending == p["key"] {
                            <Spinner key="spin"/>
                        } elif p["key"] == "google" {
                            <svg
                                key="glogo"
                                width={16}
                                height={16}
                                viewBox="0 0 24 24"
                                aria-hidden="true"
                            >
                                <path
                                    fill="#4285F4"
                                    d="M22.5 12.2c0-.8-.1-1.4-.2-2H12v3.9h6c-.1 1-.8 2.5-2.2 3.5l3.4 2.6c2-1.9 3.3-4.6 3.3-8z"
                                />
                                <path
                                    fill="#34A853"
                                    d="M12 23c2.9 0 5.4-1 7.2-2.6l-3.4-2.6c-.9.6-2.1 1.1-3.8 1.1-2.9 0-5.3-1.9-6.2-4.5l-3.5 2.7C4.1 20.5 7.8 23 12 23z"
                                />
                                <path
                                    fill="#FBBC05"
                                    d="M5.8 14.4c-.2-.7-.4-1.4-.4-2.2s.1-1.5.4-2.2L2.3 7.3C1.5 8.7 1 10.3 1 12.2s.5 3.5 1.3 4.9z"
                                />
                                <path
                                    fill="#EA4335"
                                    d="M12 5.4c2 0 3.4.9 4.2 1.6l3-3C17.4 2.2 14.9 1 12 1 7.8 1 4.1 3.5 2.3 7.3l3.5 2.7C6.7 7.4 9.1 5.4 12 5.4z"
                                />
                            </svg>
                        } else {
                            <svg
                                key="hlogo"
                                width={16}
                                height={16}
                                viewBox="0 0 24 24"
                                aria-hidden="true"
                            >
                                <path
                                    fill="currentColor"
                                    d="M12 .5A11.5 11.5 0 0 0 8.4 22.9c.6.1.8-.2.8-.6v-2c-3.2.7-3.9-1.5-3.9-1.5-.5-1.3-1.3-1.7-1.3-1.7-1-.7.1-.7.1-.7 1.1.1 1.7 1.2 1.7 1.2 1 1.7 2.7 1.2 3.3.9.1-.7.4-1.2.7-1.5-2.6-.3-5.3-1.3-5.3-5.7 0-1.3.5-2.3 1.2-3.1-.1-.3-.5-1.5.1-3.1 0 0 1-.3 3.2 1.2a11 11 0 0 1 5.8 0c2.2-1.5 3.2-1.2 3.2-1.2.6 1.6.2 2.8.1 3.1.8.8 1.2 1.8 1.2 3.1 0 4.4-2.7 5.4-5.3 5.7.4.4.8 1.1.8 2.2v3.3c0 .4.2.7.8.6A11.5 11.5 0 0 0 12 .5z"
                                />
                            </svg>
                        }  }
                        {"Continue with " + p["label"]}
                    </button>
                }
            }}
            <div className="my-3 flex items-center gap-3" aria-hidden="true">
                <span className="h-px flex-1 bg-border"></span>
                <span className="text-[13px] text-muted-foreground">or</span>
                <span className="h-px flex-1 bg-border"></span>
            </div>
        </div>;
}

# The landing's sign-up sentence. It names providers only from an answer the
# sign-in page already got, so the landing itself sends no probe.
def:pub SignUpMethods -> JsxElement {
    has answer: list[str] | None = cachedAnswer();

    text = "Sign up with email, or with Google or GitHub where they are enabled.";
    if answer is not None and len(answer) == 0 {
        text = "Sign up with email.";
    } elif answer is not None {
        text = "Sign up with email, or with " + providerPhrase(answer) + ".";
    }
    return <span>{text}</span>;
}
