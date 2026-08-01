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
