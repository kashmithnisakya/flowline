"""Implementations for the root layout."""

impl Shell.loadOrg -> None {
    try {
        result = root spawn GetMe();
        fetched = result.reports[0] if result.reports else None;
        if fetched {
            orgName = fetched.name;
        }
    } except Exception as e {
        orgName = "";
    }
}

impl Shell.logout -> None {
    jacLogout();
    window.location.href = "/login";
}
