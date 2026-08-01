"""standup - Login / Signup, the first page.

The account IS the organization: signing up creates the workspace, so the
form takes the organization name and hands it to jacSignup as the account
profile. jacSignup does NOT create a session — always signup, check success,
then login.
"""

import from "@jac/runtime" { jacIsLoggedIn, jacLogin, jacSignup }
import from ...components.ui.card {
    Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter
}
import from ...components.ui.button { Button }
import from ...components.ui.input { Input }
import from ...components.ui.label { Label }

def:pub LoginPage() -> JsxPage {
    has mode: str = "login",
        orgName: str = "",
        email: str = "",
        password: str = "",
        confirm: str = "",
        busy: bool = False,
        error: str = "";

    can with entry {
        if jacIsLoggedIn() {
            window.location.href = "/";
        }
    }

    async def submit(e: FormEvent) -> None;

    signup = mode == "signup";
    ready = (
        not busy and bool(email.strip()) and bool(password)
        and (not signup or bool(orgName.strip()))
    );

    <div className="flex min-h-[80svh] items-center justify-center">
        <Card className="w-full max-w-sm">
            <CardHeader>
                <CardTitle className="font-display text-xl font-bold tracking-tight">
                    {"Start your first standup." if signup else "Welcome back."}
                </CardTitle>
                <CardDescription>
                    {"Create your organization's workspace." if signup
                        else "Sign in to manage your projects."}
                </CardDescription>
            </CardHeader>
            <CardContent>
                <form onSubmit={submit} className="grid gap-4">
                    {if signup {
                        <div key="org" className="grid gap-2">
                            <Label>Organization name</Label>
                            <Input
                                value={orgName}
                                onChange={lambda (ev: ChangeEvent) { orgName = ev.target.value; }}
                                placeholder="Jaseci Labs"
                            />
                        </div>
                    }}
                    <div className="grid gap-2">
                        <Label>Work email</Label>
                        <Input
                            type="email"
                            value={email}
                            onChange={lambda (ev: ChangeEvent) { email = ev.target.value; }}
                            placeholder="you@company.com"
                        />
                    </div>
                    <div className="grid gap-2">
                        <Label>Password</Label>
                        <Input
                            type="password"
                            value={password}
                            onChange={lambda (ev: ChangeEvent) { password = ev.target.value; }}
                        />
                    </div>
                    {if signup {
                        <div key="confirm" className="grid gap-2">
                            <Label>Confirm password</Label>
                            <Input
                                type="password"
                                value={confirm}
                                onChange={lambda (ev: ChangeEvent) { confirm = ev.target.value; }}
                            />
                        </div>
                    }}
                    {if error {
                        <p key="err" className="text-sm text-destructive">{error}</p>
                    }}
                    <Button type="submit" disabled={not ready}>
                        {"Create workspace" if signup else "Sign in"}
                    </Button>
                </form>
            </CardContent>
            <CardFooter className="justify-center">
                <Button
                    variant="link"
                    className="text-sm"
                    onClick={lambda {
                        mode = "login" if signup else "signup";
                        error = "";
                    }}
                >
                    {"Already have a workspace? Sign in" if signup
                        else "New to standup? Create your workspace"}
                </Button>
            </CardFooter>
        </Card>
    </div>
}
