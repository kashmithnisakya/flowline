"""Implementations for the root layout."""

# The organization name and the signed-in identity, through the one
# /user/me read of this page load (lib/session.jac's fetchMe).
impl Shell.loadMe -> None {
    try {
        data: any = await fetchMe();
        # A dead token ended the session inside fetchMe: nothing to show, and
        # the route guard takes an app page to sign-in. Flipping `loggedIn`
        # here would remount the page under it (the login page lost its note).
        if not jacIsLoggedIn() {
            return;
        }
        profile: any = data["profile"] if data["profile"] else {};
        name = str(profile["org_name"]) if profile["org_name"] else "";
        if name {
            orgName = name;
            rememberOrgName(name);
        }
        idents: list[any] = data["identities"] if data["identities"] else [];
        # An email first, then any other login value, then the SSO provider.
        who = "";
        for ident in idents {
            if not who and ident["type"] == "email" and ident["value"] {
                who = str(ident["value"]);
            }
        }
        for ident in idents {
            if not who and ident["value"] {
                who = str(ident["value"]);
            }
        }
        for ident in idents {
            if not who and ident["provider"] {
                provider = str(ident["provider"]);
                who = "Signed in with " + provider[:1].upper() + provider[1:];
            }
        }
        account = who;
        rememberAccount(who);
    } except Exception as e {
        return;
    }
}

impl Shell.logout -> None {
    forgetSession();
    jacLogout();
    window.location.href = "/login";
}

impl Shell.pickTheme(pref: str) -> None {
    setThemePref(pref);
    themeChoice = pref;
}
