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
    tabBase = "flex-1 rounded-[9px] py-2 text-[13.5px] font-semibold transition-colors";
    tabOn = "bg-card text-foreground shadow-sm";
    tabOff = "text-muted-foreground hover:text-foreground";

    # items-start on purpose: the two modes differ slightly in height, and
    # centering would let that push the card upward so the tabs and heading
    # jumped on every switch. Anchored at the top, the form only grows down.
    return <div className="mx-auto grid max-w-6xl items-start gap-10 px-6 py-14 lg:grid-cols-[1.05fr_1fr] lg:py-20">
        <AuthAside />
        <div className="mx-auto w-full max-w-md">
            <div className="flex gap-[2px] rounded-xl bg-foreground/[0.06] p-1">
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

            <h1 className="font-display mt-7 text-[33px] font-bold leading-none tracking-[-1.5px]">
                {"Start your first standup." if signup else "Welcome back."}
            </h1>
            <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
                {"Email and a password is all it takes. You'll name your organization next."
                    if signup else "Your team's log is waiting in the archive."}
            </p>

            {if expired {
                <p
                    key="expired"
                    className="mt-4 rounded-xl border border-border bg-accent px-3 py-2 text-sm text-muted-foreground"
                >
                    Your session expired. Please sign in again.
                </p>
            }}

            <div className="mt-6">
                <SsoButtons
                    operation={"register" if signup else "login"}
                    onFailure={lambda (msg: str) { error = msg; }}
                />
            </div>
            <div className="my-5 flex items-center gap-3">
                <span className="h-px flex-1 bg-border"></span>
                <span className="text-[11.5px] text-muted-foreground">or with email</span>
                <span className="h-px flex-1 bg-border"></span>
            </div>

            <form onSubmit={submit} className="flex flex-col gap-[13px]">
                <div className="grid gap-1.5">
                    <Label className="text-[12.5px]">Work email</Label>
                    <Input
                        type="email"
                        value={email}
                        onChange={lambda (ev: ChangeEvent) { email = ev.target.value; }}
                        placeholder="you@company.com"
                    />
                </div>
                <div className="grid gap-1.5">
                    <Label className="text-[12.5px]">Password</Label>
                    <div className="relative flex items-center">
                        <Input
                            type={"text" if showPassword else "password"}
                            value={password}
                            onChange={lambda (ev: ChangeEvent) { password = ev.target.value; }}
                            placeholder="••••••••••"
                            className="pr-16"
                        />
                        <button
                            type="button"
                            className="absolute right-2 rounded-lg bg-foreground/[0.06] px-2 py-1 text-[11.5px] font-semibold text-muted-foreground transition-colors hover:bg-foreground/[0.12]"
                            onClick={lambda { showPassword = not showPassword; }}
                        >
                            {"Hide" if showPassword else "Show"}
                        </button>
                    </div>
                </div>
                {if error {
                    <p key="err" className="text-sm text-destructive">{error}</p>
                }}
                <Button type="submit" className="mt-1 h-11" disabled={not ready}>
                    {"Create workspace" if signup else "Sign in"}
                </Button>
            </form>

            <p className="mt-5 text-center text-xs text-muted-foreground">
                {"Already have a workspace? " if signup else "New to standup? "}
                <button
                    type="button"
                    className="font-semibold text-primary hover:underline"
                    onClick={lambda { switchMode("login" if signup else "signup"); }}
                >
                    {"Sign in" if signup else "Create one"}
                </button>
            </p>
        </div>
    </div>;
}
