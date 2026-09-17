"""Implementations for the root layout."""

# One read of /user/me for the organization name and the signed-in identity.
# lib/session.jac's fetchProfile drops the identities, so this reads the body.
impl Shell.loadMe -> None {
    try {
        token = localStorage.getItem("jac_token") or "";
        response = await fetch(
            "/user/me", {"headers": {"Authorization": "Bearer " + token}}
        );
        if not response.ok {
            return;
        }
        body: any = await response.json();
        data: any = body["data"] if body["data"] else {};
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
