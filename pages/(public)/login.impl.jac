"""Implementations for the login/signup page."""

impl LoginPage.submit(e: FormEvent) -> None {
    e.preventDefault();
    if busy or not email.strip() or not password {
        return;
    }
    signingUp = mode == "signup";
    if signingUp and not orgName.strip() {
        return;
    }
    error = "";
    if signingUp and password != confirm {
        error = "Passwords do not match.";
        return;
    }
    busy = True;
    addr = email.strip();
    pw = password;
    org = orgName.strip();
    try {
        if signingUp {
            # The org name rides along as the account profile — jacSignup
            # takes it directly, so there is no separate org-creation step.
            res: dict = {};
            res = await jacSignup(addr, pw, {"org_name": org});
            if not res["success"] {
                error = "Signup failed — is that email already registered?";
                busy = False;
                return;
            }
        }
        ok: bool = False;
        ok = await jacLogin(addr, pw);
        if ok {
            window.location.href = "/";
        } else {
            error = "Invalid email or password.";
        }
    } except Exception as ex {
        error = "Something went wrong — try again.";
    }
    busy = False;
}
