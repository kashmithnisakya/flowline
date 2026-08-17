"""standup - Login / Signup, the public front door. Signup asks for credentials
only; naming the org and yourself belongs to the setup wizard. jacSignup does
NOT create a session: signup, check success, then login. Brand panel beside a
tabbed card with Google/GitHub SSO; no "Forgot?" link because there is no flow."""

import from "@jac/runtime" { jacIsLoggedIn, jacLogin, jacSignup }
import from ...components.auth.AuthAside { AuthAside }
import from ...components.auth.SsoButtons { SsoButtons }
import from ...components.common.KineticGrid { KineticGrid }
import from ...components.ui.button { Button }
import from ...components.ui.input { Input }
import from ...components.ui.label { Label }
import from ...lib.utils { cn }
import from ...components.common.glyphs { Spinner }
import from ...components.common.ErrorNote { ErrorNote }

glob MIN_PASSWORD: int = 8;

def:pub LoginPage -> JsxPage {
    has mode: str = "login",
        email: str = "",
        password: str = "",
        showPassword: bool = False,
        expired: bool = False,
        busy: bool = False,
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
        if localStorage.getItem("standup_session") {
            expired = True;
            localStorage.removeItem("standup_session");
        }
    }

    async def submit(e: FormEvent) -> None;
    def switchMode(next: str) -> None;

    signup = mode == "signup";
    # Sign-up asks for eight characters; sign-in accepts whatever was set.
    longEnough = len(password) >= MIN_PASSWORD or not signup;
    ready = not busy and bool(email.strip()) and bool(password) and longEnough;
    tabBase = "relative z-10 rounded-lg py-2 text-sm font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/50";
    tabOn = "text-foreground";
    tabOff = "text-muted-foreground hover:text-foreground";

    # items-start on purpose: the two modes differ slightly in height, and
    # centering would let that push the card upward so the tabs and heading
    # jumped on every switch. Anchored at the top, the form only grows down.
    return
        <div className="relative overflow-hidden">
            <KineticGrid
                className="[mask-image:linear-gradient(to_bottom,black_55%,transparent)]"
            />
            <div
                className="relative z-10 mx-auto grid max-w-6xl items-start gap-10 px-6 py-14 lg:grid-cols-[1.05fr_1fr] lg:py-20"
            >
                <AuthAside/>
                <div className="anim-fade-up anim-d2 mx-auto w-full max-w-md">
                    <div className="mb-6 flex justify-center lg:hidden">
                        <img
                            src="/static/brand/logo-full.svg"
                            alt="standup"
                            width={132}
                            height={35}
                            className="dark:hidden"
                        />
                        <img
                            src="/static/brand/logo-full-dark.svg"
                            alt="standup"
                            width={132}
                            height={35}
                            className="hidden dark:block"
                        />
                    </div>
                    <div
                        className="relative grid grid-cols-2 rounded-xl bg-foreground/[0.06] p-1"
                    >
                        <span
                            aria-hidden="true"
                            className={cn(
                                "pointer-events-none absolute inset-y-1 left-1 w-[calc(50%_-_4px)] rounded-lg bg-card shadow-sm transition-transform duration-200",
                                "translate-x-full" if signup else "translate-x-0"
                            )}
                        ></span>
                        <button
                            type="button"
                            className={cn(tabBase, tabOff if signup else tabOn)}
                            onClick={lambda { switchMode("login"); }}
                        >
                            Log in
                        </button>
                        <button
                            type="button"
                            className={cn(tabBase, tabOn if signup else tabOff)}
                            onClick={lambda { switchMode("signup"); }}
                        >
                            Sign up
                        </button>
                    </div>
                    <div
                        key={mode}
                        className="mt-7 animate-in fade-in slide-in-from-bottom-1 duration-300"
                    >
                        <h1
                            className="font-display text-3xl font-bold leading-none tracking-tight"
                        >
                            {"Start your first standup." if signup else "Welcome back."}
                        </h1>
                        <p
                            className="mt-2 text-sm leading-relaxed text-muted-foreground"
                        >
                            {"Email and a password is all it takes. You'll name your organization next."
                                if signup
                                else "Your team's log is waiting in the archive."}
                        </p>
                    </div>
                    {if expired {
                        <div
                            key="expired"
                            className="mt-4 flex items-start gap-2 rounded-lg border border-border bg-accent px-3 py-2 text-sm text-muted-foreground animate-in fade-in slide-in-from-top-1"
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
                            Your session expired. Please sign in again.
                        </div>
                    }}
                    <div className="mt-6">
                        <SsoButtons
                            operation={"register" if signup else "login"}
                            onFailure={lambda (msg: str) { error = msg; }}
                        />
                    </div>
                    <div className="my-5 flex items-center gap-3">
                        <span className="h-px flex-1 bg-border"></span>
                        <span
                            className="text-xs font-medium uppercase tracking-wide text-muted-foreground"
                        >
                            or with email
                        </span>
                        <span className="h-px flex-1 bg-border"></span>
                    </div>
                    <form onSubmit={submit} className="flex flex-col gap-3.5">
                        <div className="grid gap-1.5">
                            <Label className="text-xs">Work email</Label>
                            <Input
                                type="email"
                                value={email}
                                onChange={lambda (ev: ChangeEvent) { email = ev.target.value; }}
                                placeholder="you@company.com"
                                className="h-11"
                            />
                        </div>
                        <div className="grid gap-1.5">
                            <Label className="text-xs">Password</Label>
                            <div className="relative flex items-center">
                                <Input
                                    type={"text" if showPassword else "password"}
                                    value={password}
                                    onChange={lambda (ev: ChangeEvent) { password = ev.target.value; }}
                                    placeholder="••••••••••"
                                    className="h-11 pr-11"
                                />
                                <button
                                    type="button"
                                    aria-label={"Hide password"
                                        if showPassword
                                        else "Show password"}
                                    className="absolute right-1.5 inline-flex size-8 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:bg-foreground/[0.06] hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
                                    onClick={lambda { showPassword = not showPassword; }}
                                >
                                    {if showPassword {
                                        <svg
                                            key="eyeoff"
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
                                                d="M10.733 5.076a10.744 10.744 0 0 1 11.205 6.575 1 1 0 0 1 0 .696 10.747 10.747 0 0 1-1.444 2.49"
                                            />
                                            <path
                                                d="M14.084 14.158a3 3 0 0 1-4.242-4.242"
                                            />
                                            <path
                                                d="M17.479 17.499a10.75 10.75 0 0 1-15.417-5.151 1 1 0 0 1 0-.696 10.75 10.75 0 0 1 4.446-5.143"
                                            />
                                            <path d="m2 2 20 20"/>
                                        </svg>
                                    } else {
                                        <svg
                                            key="eye"
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
                                        </svg>
                                    } }
                                </button>
                            </div>
                            {if signup {
                                <p
                                    key="rule"
                                    className={"flex items-center gap-1.5 text-xs transition-colors " + (
                                        "text-success"
                                            if len(password) >= MIN_PASSWORD
                                            else "text-muted-foreground"
                                    )}
                                    aria-live="polite"
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
                                        {if len(password) >= MIN_PASSWORD {
                                            <path key="ok" d="m5 12 5 5L20 7"/>
                                        } else {
                                            <circle key="dot" cx={12} cy={12} r={4}/>
                                        } }
                                    </svg>
                                    {"At least " + str(MIN_PASSWORD) + " characters"}
                                </p>
                            }}
                        </div>
                        {if error {
                            <ErrorNote key="err" message={error}/>
                        }}
                        <Button
                            type="submit"
                            className="mt-1 h-11"
                            disabled={not ready}
                        >
                            {if busy {
                                <Spinner key="sp"/>
                            }}
                            {("Creating workspace…" if signup else "Signing in…")
                                if busy
                                else ("Create workspace" if signup else "Sign in")}
                        </Button>
                    </form>
                    <p className="mt-5 text-center text-xs text-muted-foreground">
                        {"Already have a workspace? " if signup else "New to standup? "}
                        <button
                            type="button"
                            className="rounded-sm font-semibold text-primary hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
                            onClick={lambda { switchMode(
                                "login" if signup else "signup"
                            ); }}
                        >
                            {"Sign in" if signup else "Create one"}
                        </button>
                    </p>
                </div>
            </div>
        </div>;
}
