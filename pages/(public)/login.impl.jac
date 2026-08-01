"""Implementations for the login/signup page."""

impl LoginPage.switchMode(next: str) -> None {
    mode = next;
    error = "";
    expired = False;
}

impl LoginPage.submit(e: FormEvent) -> None {
    e.preventDefault();
    if busy or not email.strip() or not password {
        return;
    }
    signingUp = mode == "signup";
    if signingUp and (not orgName.strip() or not fullName.strip()) {
        return;
    }
    error = "";
    busy = True;
    addr = email.strip();
    pw = password;
    org = orgName.strip();
    who = fullName.strip();
    try {
        if signingUp {
            # The org name and PM name ride along as the account profile —
            # jacSignup takes it directly, so there is no org-creation step.
            res: dict = {};
            res = await jacSignup(addr, pw, {"org_name": org, "full_name": who});
            if not res["success"] {
                error = "Signup failed — is that email already registered?";
                busy = False;
                return;
            }
        }
        ok: bool = False;
        ok = await jacLogin(addr, pw);
        if ok {
            # Marker for the session-expired notice: a 401 clears the JWT
            # and reloads, and this is how /login knows it was a timeout.
            localStorage.setItem("standup_session", "1");
            window.location.href = "/board";
        } else {
            error = "Invalid email or password.";
        }
    } except Exception as ex {
        error = "Something went wrong — try again.";
    }
    busy = False;
}
