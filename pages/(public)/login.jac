"""flowline - sign in and sign up: the form on the left, a dark band with the flow
line on the right. Signup asks for credentials only; the setup wizard names the
workspace. jacSignup does NOT create a session: sign up, check success, then log
in. The submit button stays enabled and validation shows under its field.
"""

import from "@jac/runtime" { jacIsLoggedIn, jacLogin, jacSignup }
import from ...lib.session { forgetSession, checkSession }
import from ...lib.signup { signupProblem }
import from ...components.auth.AuthBand { AuthBand }
import from ...components.auth.AuthGlyphs { ClockGlyph }
import from ...components.auth.PasswordField { PasswordField }
import from ...components.auth.SsoButtons { SsoButtons }
import from ...components.landing.Wordmark { Wordmark }
import from ...components.ui.button { Button }
import from ...components.ui.input { Input }
import from ...components.ui.label { Label }
import from ...components.common.glyphs { Spinner, WarnIcon }

glob MIN_PASSWORD: int = 8;

def:pub LoginPage -> JsxPage {
    has mode: str = "login",
        email: str = "",
        password: str = "",
        expired: bool = False,
        busy: bool = False,
        emailError: str = "",
        passwordError: str = "",
        error: str = "",
        # A stored token is checked before the page redirects on it, and the
        # form waits for the answer, so a dead token never bounces through
        # the board and a live one never flashes the form.
        checking: bool = jacIsLoggedIn();

    async can with entry {
        if checking {
            live = await checkSession();
            if live {
                window.location.href = "/board";
                return;
            }
            checking = False;
        }
        # The landing page links here as /login?mode=signup.
        if "mode=signup" in str(window.location.search) {
            mode = "signup";
        }
        # A 401 wipes the token and hard-reloads; this marker is what tells
        # us the visitor was signed in a moment ago rather than arriving cold.
        if localStorage.getItem("flowline_session") {
            expired = True;
            localStorage.removeItem("flowline_session");
        }
    }

    async def submit(e: FormEvent) -> None;
    def switchMode(next: str) -> None;

    signup = mode == "signup";
    if checking {
        return <div className="min-h-svh bg-background" aria-busy="true"/>;
    }

    return
        <div className="flex min-h-svh bg-background text-foreground">
            <div className="flex min-w-0 flex-1 flex-col px-4 py-6 sm:px-8">
                <a
                    href="/"
                    aria-label="flowline home"
                    className="self-start rounded-sm"
                >
                    <Wordmark/>
                </a>
                <main className="m-auto flex w-full max-w-[380px] flex-col gap-4 py-8">
                    <div>
                        <h1
                            className="text-[32px] leading-[1.04] font-bold tracking-[-0.03em] text-balance"
                        >
                            {"Start your first flow line."
                                if signup
                                else "Sign in to Flowline"}
                        </h1>
                        <p className="mt-1.5 text-sm text-text-secondary">
                            {"Next you name your workspace, add your people and choose how work moves."
                                if signup
                                else "Your board and log are where you left them."}
                        </p>
                    </div>
                    {if expired {
                        <p
                            key="expired"
                            className="flex items-start gap-2 rounded-md border bg-card px-3 py-2 text-sm text-muted-foreground"
                        >
                            <ClockGlyph/>
                            Your session expired. Sign in again to pick up where you were.
                        </p>
                    }}
                    <SsoButtons
                        operation={"register" if signup else "login"}
                        onFailure={lambda (msg: str) { error = msg; }}
                    />
                    <form onSubmit={submit} noValidate={True} className="grid gap-4">
                        <div className="grid gap-1.5">
                            <Label
                                htmlFor="auth-email"
                                className="text-[13px] font-medium"
                            >
                                Email
                            </Label>
                            <Input
                                id="auth-email"
                                type="email"
                                name="email"
                                autoComplete="email"
                                value={email}
                                aria-invalid={emailError != ""}
                                aria-describedby={"auth-email-error"
                                    if emailError
                                    else None}
                                onChange={lambda (ev: ChangeEvent) {
                                    email = ev.target.value;
                                    emailError = "";
                                }}
                                placeholder="you@company.com"
                                className="h-10"
                            />
                            {if emailError {
                                <p
                                    key="email-error"
                                    id="auth-email-error"
                                    className="text-xs text-destructive"
                                >
                                    {emailError}
                                </p>
                            }}
                        </div>
                        <PasswordField
                            value={password}
                            error={passwordError}
                            signup={signup}
                            minLength={MIN_PASSWORD}
                            onValue={lambda (v: str) {
                                password = v;
                                passwordError = "";
                            }}
                        />
                        {if error {
                            <p
                                key="err"
                                role="alert"
                                className="flex items-start gap-2 text-sm text-destructive"
                            >
                                <WarnIcon className="mt-0.5 shrink-0"/>
                                <span>{error}</span>
                            </p>
                        }}
                        <Button
                            type="submit"
                            className="h-11 w-full text-sm font-semibold"
                            disabled={busy}
                            aria-busy={busy}
                        >
                            {if busy {
                                <Spinner key="sp"/>
                            }}
                            {("Creating workspace…" if signup else "Signing in…")
                                if busy
                                else ("Create workspace" if signup else "Sign in")}
                        </Button>
                    </form>
                    <p className="meta text-center">
                        {"Already have one? " if signup else "New here? "}
                        <button
                            type="button"
                            className="text-text-primary underline underline-offset-[3px]"
                            onClick={lambda { switchMode(
                                "login" if signup else "signup"
                            ); }}
                        >
                            {"Sign in" if signup else "Create a workspace"}
                        </button>
                    </p>
                </main>
                <p className="meta">Your workspace is private to your account.</p>
            </div>
            <AuthBand/>
        </div>;
}
