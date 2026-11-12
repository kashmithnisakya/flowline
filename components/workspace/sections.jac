"""The Workspace page's sections in rail order and how the address names one.
Browser-only helpers, pinned client in jac.toml."""

glob:pub SECTIONS: list[list[str]] = [
         ["organization", "Organization"],
         ["people", "People"],
         ["projects", "Projects"],
         ["roles", "Roles"],
         ["github", "GitHub"],
         ["preferences", "Preferences"]
     ];

# The section an address asks for, "" when it names none we know. /github and
# a GitHub list's own `view` param both mean the GitHub section.
def:pub askedSection(path: str, search: str) -> str {
    w: any = window;
    params: any = new(w.URLSearchParams, search);
    wanted = str(params.get("tab") or "");
    for item in SECTIONS {
        if item[0] == wanted {
            return wanted;
        }
    }
    if path == "/github" or params.get("view") {
        return "github";
    }
    return "";
}

# Whether this address needs the GitHub section mounted from the first render.
def:pub currentFromAddress -> str {
    w: any = window;
    return askedSection(str(w.location.pathname), str(w.location.search))
        or SECTIONS[0][0];
}
