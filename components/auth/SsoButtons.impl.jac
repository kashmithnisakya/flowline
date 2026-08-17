"""Implementation for the SSO buttons."""

impl SsoButtons.start(platform: str) -> None {
    # Pending drives the spinner swap and disables both buttons; it stays
    # set on the success path because the browser is about to navigate away.
    pending = platform;
    # jac-scale requires client_callback on the initiate call (it 422s
    # without one), which jacSsoLogin does not send, so build the URL by
    # hand. The server only honours the value when it is a safe loopback;
    # otherwise it falls back to [scale.sso] client_auth_callback_url.
    back = encodeURIComponent(window.location.origin + "/auth/callback");
    url = "/sso/" + platform + "/" + operation + "?client_callback=" + back;

    # Pre-flight so an unconfigured provider shows a message instead of
    # dumping the raw 501 JSON in the address bar. A configured provider
    # answers with a redirect to the vendor, which `manual` makes opaque.
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
        onFailure(
            platform.capitalize() + " sign-in isn't configured yet. Add its " + "client_id and client_secret under [scale.sso." + platform + "] in jac.toml."
        );
        return;
    }
    # Marker so a later 401 can tell a timeout from a cold arrival.
    localStorage.setItem("standup_session", "1");
    window.location.href = url;
}
