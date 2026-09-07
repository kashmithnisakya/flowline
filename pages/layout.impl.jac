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
    themeChoice = "dark" if goDark else "light";
}

impl Shell.pickTheme(pref: str) -> None {
    setThemePref(pref);
    themeChoice = pref;
    doc: any = document;
    themeDark = bool(doc.documentElement.classList.contains("dark"));
}
