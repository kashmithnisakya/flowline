"""Implementations for the sign-in and sign-up page."""

impl LoginPage.switchMode(next: str) -> None {
    mode = next;
    error = "";
    emailError = "";
    passwordError = "";
    expired = False;
    # Keep the address in step so a reload or a shared link opens this tab.
    w: any = window;
    w.history.replaceState(
        None, "", "/login?mode=signup" if next == "signup" else "/login"
    );
}

impl LoginPage.tabKey(e: KeyboardEvent) -> None {
    # Tabs pattern: either arrow flips between the two modes, Home and End pick.
    next = "";
    if e.key == "ArrowLeft" or e.key == "ArrowRight" {
        next = "login" if mode == "signup" else "signup";
    } elif e.key == "Home" {
        next = "login";
    } elif e.key == "End" {
        next = "signup";
    }
    if not next {
        return;
    }
    e.preventDefault();
    switchMode(next);
    doc: any = document;
    target: any = doc.getElementById("tab-" + next);
    if target {
        target.focus();
    }
}

impl LoginPage.submit(e: FormEvent) -> None {
    e.preventDefault();
    if busy {
        return;
    }
    signingUp = mode == "signup";
    addr = email.strip();
    pw = password;
    error = "";
    emailError = "";
    passwordError = "";
    if not addr {
        emailError = "Enter your email address.";
    } elif "@" not in addr {
        emailError = "Enter a full email address, like you@company.com.";
    }
    if not pw {
        passwordError = "Choose a password." if signingUp else "Enter your password.";
    } elif signingUp and len(pw) < MIN_PASSWORD {
        passwordError = "Use at least " + str(MIN_PASSWORD) + " characters.";
    }
    if emailError or passwordError {
        doc: any = document;
        target: any = doc.getElementById(
            "auth-email" if emailError else "auth-password"
        );
        if target {
            target.focus();
        }
        return;
    }
    busy = True;
    try {
        if signingUp {
            # The profile starts empty on purpose: the setup wizard asks for
            # the workspace name. jacSignup still needs the argument.
            res: any = {};
            res = await jacSignup(addr, pw, {});
            if not res["success"] {
                error = "Could not create a workspace with that email. It may already be registered; try signing in.";
                busy = False;
                return;
            }
        }
        ok: bool = False;
        ok = await jacLogin(addr, pw);
        if ok {
            # A fresh session: the header's cached workspace name may belong
            # to whoever signed in here last.
            forgetSession();
            # Marker for the session-expired notice: a 401 clears the JWT
            # and reloads, and this is how /login knows it was a timeout.
            localStorage.setItem("flowline_session", "1");
            # A new account goes straight to the wizard, not via the board.
            window.location.href = "/setup" if signingUp else "/board";
            return;
        }
        error = "That email and password do not match.";
    } except Exception as ex {
        error = "Something went wrong. Try again.";
    }
    busy = False;
}
