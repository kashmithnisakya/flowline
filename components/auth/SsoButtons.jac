"""Google / GitHub sign-in over jac-scale's /sso/{platform}/{operation}
endpoints; the exchange bounces back to client_auth_callback_url with
?token=<jwt>, stored by pages/(public)/auth/callback.jac. Credentials live in
jac.toml [scale.sso.*]; until set the server answers SSO_NOT_CONFIGURED (501)."""

import from "@jac/runtime" { jacSsoLogin }
import from ..common.glyphs { Spinner }

def:pub SsoButtons(operation: str, onFailure: Callable[[str], None]) -> JsxElement {
    has pending: str = "";

    async def start(platform: str) -> None;

    btn = "flex h-11 items-center justify-center gap-2 rounded-lg border border-border bg-card px-3 text-sm font-semibold transition-all duration-150 hover:border-foreground hover:bg-accent/50 active:scale-[0.98] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/50 disabled:pointer-events-none disabled:opacity-60";

    return
        <div className="grid grid-cols-2 gap-2.5">
            <button
                type="button"
                disabled={pending != ""}
                className={btn}
                onClick={lambda { start("google"); }}
            >
                {if pending == "google" {
                    <Spinner key="gspin"/>
                } else {
                    <svg
                        key="glogo"
                        width={15}
                        height={15}
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
                } }
                Google
            </button>
            <button
                type="button"
                disabled={pending != ""}
                className={btn}
                onClick={lambda { start("github"); }}
            >
                {if pending == "github" {
                    <Spinner key="hspin"/>
                } else {
                    <svg
                        key="hlogo"
                        width={15}
                        height={15}
                        viewBox="0 0 24 24"
                        aria-hidden="true"
                    >
                        <path
                            fill="currentColor"
                            d="M12 .5A11.5 11.5 0 0 0 8.4 22.9c.6.1.8-.2.8-.6v-2c-3.2.7-3.9-1.5-3.9-1.5-.5-1.3-1.3-1.7-1.3-1.7-1-.7.1-.7.1-.7 1.1.1 1.7 1.2 1.7 1.2 1 1.7 2.7 1.2 3.3.9.1-.7.4-1.2.7-1.5-2.6-.3-5.3-1.3-5.3-5.7 0-1.3.5-2.3 1.2-3.1-.1-.3-.5-1.5.1-3.1 0 0 1-.3 3.2 1.2a11 11 0 0 1 5.8 0c2.2-1.5 3.2-1.2 3.2-1.2.6 1.6.2 2.8.1 3.1.8.8 1.2 1.8 1.2 3.1 0 4.4-2.7 5.4-5.3 5.7.4.4.8 1.1.8 2.2v3.3c0 .4.2.7.8.6A11.5 11.5 0 0 0 12 .5z"
                        />
                    </svg>
                } }
                GitHub
            </button>
        </div>;
}
