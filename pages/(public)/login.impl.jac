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
    error = "";
    busy = True;
    addr = email.strip();
    pw = password;
    try {
        if signingUp {
            # The profile starts empty on purpose: the setup wizard collects
            # the organization and PM name, where there is room to say what
            # they are for. jacSignup still needs the argument.
            res: dict = {};
            res = await jacSignup(addr, pw, {});
            if not res["success"] {
                error = "Signup failed. Is that email already registered?";
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
        error = "Something went wrong. Try again.";
    }
    busy = False;
}
