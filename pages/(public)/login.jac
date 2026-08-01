"""standup - Login / Signup, the first page.

Signing up makes you a Project Manager — team members do not get accounts
in v2. jacSignup does NOT create a session: always signup -> check success
-> login.
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

    <div className="flex min-h-[80svh] items-center justify-center">
        <Card className="w-full max-w-sm">
            <CardHeader>
                <CardTitle className="text-xl">standup</CardTitle>
                <CardDescription>
                    {"Log in to manage your projects." if mode == "login"
                        else "Create a Project Manager account."}
                </CardDescription>
            </CardHeader>
            <CardContent>
                <form onSubmit={submit} className="grid gap-4">
                    <div className="grid gap-2">
                        <Label>Email</Label>
                        <Input
                            type="email"
                            value={email}
                            onChange={lambda (ev: ChangeEvent) { email = ev.target.value; }}
                            placeholder="pm@example.com"
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
                    {if mode == "signup" {
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
                    <Button
                        type="submit"
                        disabled={busy or not email.strip() or not password}
                    >
                        {"Log in" if mode == "login" else "Sign up"}
                    </Button>
                </form>
            </CardContent>
            <CardFooter className="justify-center">
                <Button
                    variant="link"
                    className="text-sm"
                    onClick={lambda {
                        mode = "signup" if mode == "login" else "login";
                        error = "";
                    }}
                >
                    {"New here? Create a PM account" if mode == "login" else "Already have an account? Log in"}
                </Button>
            </CardFooter>
        </Card>
    </div>
}
