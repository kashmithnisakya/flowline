"""Implementations for the login/signup page."""

impl LoginPage.submit(e: FormEvent) -> None {
    e.preventDefault();
    if busy or not email.strip() or not password {
        return;
    }
    error = "";
    if mode == "signup" and password != confirm {
        error = "Passwords do not match.";
        return;
    }
    busy = True;
    addr = email.strip();
    pw = password;
    try {
        if mode == "signup" {
            # jacSignup returns a dict and does NOT log in.
            res: dict = {};
            res = await jacSignup(addr, pw);
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
