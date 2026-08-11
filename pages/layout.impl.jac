"""Implementations for the root layout."""

impl Shell.loadOrg -> None {
    name = await fetchOrgName();
    if name {
        orgName = name;
    }
}

impl Shell.logout -> None {
    jacLogout();
    window.location.href = "/login";
}

impl Shell.toggleTheme -> None {
    # One click flips light/dark and pins the explicit choice; the three-way
    # picker (including "follow the system") stays on the Settings page.
    goDark = not themeDark;
    setThemePref("dark" if goDark else "light");
    themeDark = goDark;
}
