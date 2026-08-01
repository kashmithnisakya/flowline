"""standup - Login / Signup, the public front door.

The account IS the organization: signing up creates the workspace, so the
form takes the organization name and hands it to jacSignup as the account
profile. jacSignup does NOT create a session — always signup, check success,
then login.

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
        fullName: str = "",
        orgName: str = "",
        email: str = "",
        password: str = "",
        showPassword: bool = False,
        expired: bool = False,
        busy: bool = False,
        error: str = "";

    can with entry {
        if jacIsLoggedIn() {
            window.location.href = "/";
            return;
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
    ready = (
        not busy and bool(email.strip()) and bool(password)
        and (not signup or (bool(orgName.strip()) and bool(fullName.strip())))
    );
    tabBase = "flex-1 rounded-[9px] py-2 text-[13.5px] font-semibold transition-colors";
    tabOn = "bg-card text-foreground shadow-sm";
    tabOff = "text-muted-foreground hover:text-foreground";

    <div className="mx-auto grid min-h-[88svh] max-w-6xl items-center gap-10 px-6 py-10 lg:grid-cols-[1.05fr_1fr]">
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
                {"Create your organization's workspace — you'll be its project manager."
                    if signup else "Your team's log is waiting in the archive."}
            </p>

            {if expired {
                <p
                    key="expired"
                    className="mt-4 rounded-xl border border-border bg-accent px-3 py-2 text-sm text-muted-foreground"
                >
                    Your session expired — please sign in again.
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
                {if signup {
                    <div key="who" className="grid grid-cols-2 gap-[9px]">
                        <div className="grid gap-1.5">
                            <Label className="text-[12.5px]">Your name</Label>
                            <Input
                                value={fullName}
                                onChange={lambda (ev: ChangeEvent) { fullName = ev.target.value; }}
                                placeholder="Priya Raman"
                            />
                        </div>
                        <div className="grid gap-1.5">
                            <Label className="text-[12.5px]">Organization</Label>
                            <Input
                                value={orgName}
                                onChange={lambda (ev: ChangeEvent) { orgName = ev.target.value; }}
                                placeholder="Acme Robotics"
                            />
                        </div>
                    </div>
                }}
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
    </div>
}
