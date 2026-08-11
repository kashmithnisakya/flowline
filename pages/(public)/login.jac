"""standup - Login / Signup, the public front door.

Signing up asks for credentials and nothing else. The account IS the
organization, but naming it (and yourself) belongs to the setup wizard,
where there is room to explain what the names are for: a signup form is a
door, not a questionnaire, and every field on it is a reason to leave.
jacSignup does NOT create a session, always signup, check success, then
login; the wizard fills the profile in afterwards.

Layout follows the design: a brand panel beside a tabbed auth card, with
Google/GitHub sign-in wired to jac-scale's /sso endpoints. There is still no
"Forgot?" link because password reset has no flow behind it yet.
"""

import from "@jac/runtime" { jacIsLoggedIn, jacLogin, jacSignup }
import from ...components.auth.AuthAside { AuthAside }
import from ...components.auth.SsoButtons { SsoButtons }
import from ...components.common.KineticGrid { KineticGrid }
import from ...components.ui.button { Button }
import from ...components.ui.input { Input }
import from ...components.ui.label { Label }
import from ...lib.utils { cn }

def:pub LoginPage() -> JsxPage {
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
    ready = not busy and bool(email.strip()) and bool(password);
    tabBase = "relative z-10 rounded-lg py-2 text-sm font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/50";
    tabOn = "text-foreground";
    tabOff = "text-muted-foreground hover:text-foreground";

    # items-start on purpose: the two modes differ slightly in height, and
    # centering would let that push the card upward so the tabs and heading
    # jumped on every switch. Anchored at the top, the form only grows down.
    return <div className="relative overflow-hidden">
        <KineticGrid className="[mask-image:linear-gradient(to_bottom,black_55%,transparent)]"/>
        <div className="relative z-10 mx-auto grid max-w-6xl items-start gap-10 px-6 py-14 lg:grid-cols-[1.05fr_1fr] lg:py-20">
            <AuthAside />
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

                <div className="relative grid grid-cols-2 rounded-xl bg-foreground/[0.06] p-1">
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

                <div key={mode} className="mt-7 animate-in fade-in slide-in-from-bottom-1 duration-300">
                    <h1 className="font-display text-3xl font-bold leading-none tracking-tight">
                        {"Start your first standup." if signup else "Welcome back."}
                    </h1>
                    <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
                        {"Email and a password is all it takes. You'll name your organization next."
                            if signup else "Your team's log is waiting in the archive."}
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
                    <span className="text-xs font-medium uppercase tracking-wide text-muted-foreground">or with email</span>
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
                                aria-label={"Hide password" if showPassword else "Show password"}
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
                                        <path d="M10.733 5.076a10.744 10.744 0 0 1 11.205 6.575 1 1 0 0 1 0 .696 10.747 10.747 0 0 1-1.444 2.49"/>
                                        <path d="M14.084 14.158a3 3 0 0 1-4.242-4.242"/>
                                        <path d="M17.479 17.499a10.75 10.75 0 0 1-15.417-5.151 1 1 0 0 1 0-.696 10.75 10.75 0 0 1 4.446-5.143"/>
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
                                        <path d="M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0"/>
                                        <circle cx={12} cy={12} r={3}/>
                                    </svg>
                                }}
                            </button>
                        </div>
                    </div>
                    {if error {
                        <div
                            key="err"
                            className="flex items-start gap-2 rounded-lg border border-destructive/30 bg-destructive/10 px-3 py-2 text-sm text-destructive animate-in fade-in slide-in-from-top-1"
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
                                <path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 20h16a2 2 0 0 0 1.73-2Z"/>
                                <path d="M12 9v4"/>
                                <path d="M12 17h.01"/>
                            </svg>
                            {error}
                        </div>
                    }}
                    <Button type="submit" className="mt-1 h-11" disabled={not ready}>
                        {if busy {
                            <svg
                                key="sp"
                                className="animate-spin"
                                width={14}
                                height={14}
                                viewBox="0 0 24 24"
                                fill="none"
                                stroke="currentColor"
                                strokeWidth={2}
                                strokeLinecap="round"
                            >
                                <path d="M21 12a9 9 0 1 1-6.219-8.56"/>
                            </svg>
                        }}
                        {("Creating workspace…" if signup else "Signing in…")
                            if busy else ("Create workspace" if signup else "Sign in")}
                    </Button>
                </form>

                <p className="mt-5 text-center text-xs text-muted-foreground">
                    {"Already have a workspace? " if signup else "New to standup? "}
                    <button
                        type="button"
                        className="rounded-sm font-semibold text-primary hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
                        onClick={lambda { switchMode("login" if signup else "signup"); }}
                    >
                        {"Sign in" if signup else "Create one"}
                    </button>
                </p>
            </div>
        </div>
    </div>;
}
