"""flowline - sign in and sign up, one quiet column. Signup asks for credentials
only; the setup wizard names the workspace. jacSignup does NOT create a
session: sign up, check success, then log in. The submit button stays enabled
and validation shows inline under the field it is about.
"""

import from "@jac/runtime" { jacIsLoggedIn, jacLogin, jacSignup }
import from ...components.auth.SsoButtons { SsoButtons }
import from ...components.landing.Wordmark { Wordmark }
import from ...components.ui.button { Button }
import from ...components.ui.input { Input }
import from ...components.ui.label { Label }
import from ...components.common.glyphs { Spinner, WarnIcon }

glob MIN_PASSWORD: int = 8,
     MODE_TAB: str = "h-8 rounded-[3px] px-3 text-[13px] transition-colors";

def:pub LoginPage -> JsxPage {
    has mode: str = "login",
        email: str = "",
        password: str = "",
        showPassword: bool = False,
        expired: bool = False,
        busy: bool = False,
        emailError: str = "",
        passwordError: str = "",
        error: str = "";

    can with entry {
        if jacIsLoggedIn() {
            window.location.href = "/board";
            return;
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
    def tabKey(e: KeyboardEvent) -> None;

    signup = mode == "signup";
    longEnough = len(password) >= MIN_PASSWORD;

    return
        <div className="min-h-svh bg-background px-4 text-foreground sm:px-6">
            <div className="mx-auto flex h-14 max-w-[1180px] items-center">
                <a href="/" aria-label="flowline home" className="rounded-sm">
                    <Wordmark/>
                </a>
            </div>
            <main className="mx-auto w-full max-w-[400px] pt-8 pb-16 sm:pt-16">
                <div
                    role="tablist"
                    aria-label="Sign in or create a workspace"
                    className="inline-flex gap-0.5 rounded-md border bg-card p-0.5"
                    onKeyDown={tabKey}
                >
                    <button
                        type="button"
                        role="tab"
                        id="tab-login"
                        aria-selected={not signup}
                        aria-controls="auth-panel"
                        tabIndex={-1 if signup else 0}
                        className={MODE_TAB
                            + (
                                " bg-muted font-semibold text-foreground"
                                    if not signup
                                    else " font-medium text-muted-foreground hover:text-foreground"
                            )}
                        onClick={lambda { switchMode("login"); }}
                    >
                        Sign in
                    </button>
                    <button
                        type="button"
                        role="tab"
                        id="tab-signup"
                        aria-selected={signup}
                        aria-controls="auth-panel"
                        tabIndex={0 if signup else -1}
                        className={MODE_TAB
                            + (
                                " bg-muted font-semibold text-foreground"
                                    if signup
                                    else " font-medium text-muted-foreground hover:text-foreground"
                            )}
                        onClick={lambda { switchMode("signup"); }}
                    >
                        Create workspace
                    </button>
                </div>
                <div
                    id="auth-panel"
                    role="tabpanel"
                    aria-labelledby={"tab-signup" if signup else "tab-login"}
                >
                    <h1
                        className="mt-7 text-[28px] leading-[1.15] font-bold tracking-[-0.01em] [font-stretch:112%]"
                    >
                        {"Start your first flow line."
                            if signup
                            else "Sign in to Flowline"}
                    </h1>
                    <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
                        {"Next you name your workspace, add your people and choose how work moves."
                            if signup
                            else "Your board and log are where you left them."}
                    </p>
                    {if expired {
                        <p
                            key="expired"
                            className="mt-4 flex items-start gap-2 rounded-md border bg-card px-3 py-2 text-sm text-muted-foreground"
                        >
                            <svg
                                className="mt-0.5 shrink-0"
                                width={14}
                                height={14}
                                viewBox="0 0 24 24"
                                fill="none"
                                stroke="currentColor"
                                strokeWidth={2}
                                strokeLinecap="round"
                                strokeLinejoin="round"
                                aria-hidden="true"
                            >
                                <circle cx={12} cy={12} r={10}/>
                                <path d="M12 6v6l4 2"/>
                            </svg>
                            Your session expired. Sign in again to pick up where you were.
                        </p>
                    }}
                    <div className="mt-6">
                        <SsoButtons
                            operation={"register" if signup else "login"}
                            onFailure={lambda (msg: str) { error = msg; }}
                        />
                    </div>
                    <form onSubmit={submit} noValidate={True} className="grid gap-4">
                        <div className="grid gap-1.5">
                            <Label
                                htmlFor="auth-email"
                                className="text-[13px] font-semibold"
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
                        <div className="grid gap-1.5">
                            <Label
                                htmlFor="auth-password"
                                className="text-[13px] font-semibold"
                            >
                                Password
                            </Label>
                            <div className="relative flex items-center">
                                <Input
                                    id="auth-password"
                                    type={"text" if showPassword else "password"}
                                    name="password"
                                    autoComplete={"new-password"
                                        if signup
                                        else "current-password"}
                                    value={password}
                                    aria-invalid={passwordError != ""}
                                    aria-describedby={"auth-password-note"
                                        if signup or passwordError
                                        else None}
                                    onChange={lambda (ev: ChangeEvent) {
                                        password = ev.target.value;
                                        passwordError = "";
                                    }}
                                    placeholder="••••••••••"
                                    className="h-10 pr-11"
                                />
                                <button
                                    type="button"
                                    aria-label={"Hide password"
                                        if showPassword
                                        else "Show password"}
                                    aria-pressed={showPassword}
                                    className="absolute right-1 inline-flex size-8 items-center justify-center rounded-md text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
                                    onClick={lambda { showPassword = not showPassword; }}
                                >
                                    <svg
                                        width={16}
                                        height={16}
                                        viewBox="0 0 24 24"
                                        fill="none"
                                        stroke="currentColor"
                                        strokeWidth={2}
                                        strokeLinecap="round"
                                        strokeLinejoin="round"
                                        aria-hidden="true"
                                    >
                                        <path
                                            d="M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0"
                                        />
                                        <circle cx={12} cy={12} r={3}/>
                                        {if showPassword {
                                            <path key="slash" d="m3 3 18 18"/>
                                        }}
                                    </svg>
                                </button>
                            </div>
                            {if passwordError {
                                <p
                                    key="password-error"
                                    id="auth-password-note"
                                    className="text-xs text-destructive"
                                >
                                    {passwordError}
                                </p>
                            } elif signup {
                                <p
                                    key="rule"
                                    id="auth-password-note"
                                    className={"flex items-center gap-1.5 text-xs "
                                        + (
                                            "text-success"
                                                if longEnough
                                                else "text-muted-foreground"
                                        )}
                                >
                                    <svg
                                        width={12}
                                        height={12}
                                        viewBox="0 0 24 24"
                                        fill="none"
                                        stroke="currentColor"
                                        strokeWidth={2.5}
                                        strokeLinecap="round"
                                        strokeLinejoin="round"
                                        aria-hidden="true"
                                    >
                                        <path
                                            d={"m5 12 5 5L20 7"
                                                if longEnough
                                                else "M8 12h8"}
                                        />
                                    </svg>
                                    {"At least " + str(MIN_PASSWORD) + " characters"}
                                </p>
                            } }
                        </div>
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
                            className="h-10 w-full text-sm font-semibold"
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
                    <p className="mt-6 text-[13px] text-muted-foreground">
                        Your workspace is private to your account.
                    </p>
                </div>
            </main>
        </div>;
}
