"""Implementation for the SSO buttons."""

impl SsoButtons.start(platform: str) -> None {
    # Pending drives the spinner and disables both buttons; it stays set on
    # success because the browser is about to navigate away.
    pending = platform;
    # jac-scale needs client_callback on the initiate call, which jacSsoLogin
    # does not send. The server honours it only for a safe loopback and
    # otherwise falls back to [scale.sso] client_auth_callback_url.
    back = encodeURIComponent(window.location.origin + "/auth/callback");
    url = "/sso/" + platform + "/" + operation + "?client_callback=" + back;
    # The mount probe already hid unconfigured providers; this catches a
    # server whose credentials went away since the page loaded.
    configured = True;
    try {
        probe = await fetch(url, {"redirect": "manual"});
        if probe.status == 501 or probe.status == 422 {
            configured = False;
        }
    } except Exception as e {
        configured = True;
    }
    if not configured {
        pending = "";
        label = "Google" if platform == "google" else "GitHub";
        console.warn(
            "SSO "
                + platform
                + " is not configured: set its client_id and client_secret under [scale.sso."
                + platform
                + "] in jac.toml."
        );
        onFailure(label + " sign-in isn't set up on this server. Use email instead.");
        return;
    }
    # Marker so a later 401 can tell a timeout from a cold arrival.
    localStorage.setItem("flowline_session", "1");
    window.location.href = url;
}
