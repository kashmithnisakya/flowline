"""Implementations for the root layout."""

impl Shell.loadOrg -> None {
    profile = await fetchProfile();
    name = profile["org_name"] if profile["org_name"] else "";
    if name {
        orgName = name;
    }
    who = profile["full_name"] if profile["full_name"] else "";
    if who {
        fullName = who;
    }
    # Space context: which board this session shows, and my standing there.
    sp = spaceRoot();
    spId = str(sp);
    spaceOrgId = spId;
    try {
        mres = root spawn ListMyMemberships();
        got = mres.reports[0] if mres.reports else None;
        memberships = got["rows"] if got and got["rows"] else [];
    } except Exception {
        memberships = [];
    }
    if spId {
        try {
            cres = sp spawn GetOrgContext();
            ctx = cres.reports[0] if cres.reports else None;
            if ctx and ctx["ok"] {
                spaceLevel = ctx["level"];
                if ctx["org_name"] {
                    orgName = ctx["org_name"];
                }
            } else {
                # The key was revoked: fall back to the account's own board.
                setSpaceRoot("");
                window.location.reload();
            }
        } except Exception {
            # Transient failure: keep the page, just without level gating.
            spaceLevel = spaceLevel;
        }
    } else {
        spaceLevel = "owner";
        if name {
            # Mirror the org name into the graph so members can read it.
            try {
                root spawn EnsureOrgMeta(name=name);
            } except Exception {
                spaceLevel = "owner";
            }
        }
    }
}

impl Shell.switchSpace(orgRootId: str) -> None {
    setSpaceRoot(orgRootId);
    window.location.href = "/board";
}

impl Shell.logout -> None {
    jacLogout();
    window.location.href = "/login";
}

impl Shell.toggleTheme -> None {
    # One click flips light/dark and pins the explicit choice; the three-way
    # picker (including "follow the system") is in the account menu and on
    # the Settings page.
    goDark = not themeDark;
    setThemePref("dark" if goDark else "light");
    themeDark = goDark;
    themePref = "dark" if goDark else "light";
}

impl Shell.pickTheme(pref: str) -> None {
    setThemePref(pref);
    themePref = pref;
    doc: any = document;
    themeDark = bool(doc.documentElement.classList.contains("dark"));
}
