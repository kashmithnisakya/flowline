"""The Workspace page's sections in page order, how the address names one, and
the hold that keeps a section in place while what sits above it settles.
Browser-only helpers, pinned client in jac.toml."""

glob:pub SECTIONS: list[list[str]] = [
         ["organization", "Organization"],
         ["people", "People"],
         ["projects", "Projects"],
         ["roles", "Roles"],
         ["github", "GitHub"],
         ["preferences", "Preferences"]
     ];

glob HOLD_MS: float = 4000.0,
     # Past this line from the viewport's top a section counts as being read.
     SPY_LINE: float = 140.0,
     HOLD: dict[str, any] = {"key": "", "until": 0.0};

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
def:pub asksForGithub -> bool {
    w: any = window;
    search = str(w.location.search);
    return askedSection(str(w.location.pathname), search) == "github"
        or "view=" in search;
}

def:pub currentFromAddress -> str {
    w: any = window;
    return askedSection(str(w.location.pathname), str(w.location.search))
        or SECTIONS[0][0];
}

def:pub scrollToSection(key: str, smooth: bool = False) -> None {
    el: any = document.getElementById("section-" + key);
    if not el {
        return;
    }
    w: any = window;
    calm: any = w.matchMedia("(prefers-reduced-motion: reduce)");
    glide = smooth and not bool(calm.matches);
    el.scrollIntoView({"behavior": "smooth" if glide else "auto", "block": "start"});
}

# Scroll to a section and keep it there as reads land above it; SectionSpy
# re-scrolls while this lasts, and the reader's first input ends it early.
def:pub holdSection(key: str, smooth: bool = False) {
    d = new(Date);
    HOLD["key"] = key;
    HOLD["until"] = (d.getTime() as float) + HOLD_MS;
    scrollToSection(key, smooth);
}

def:pub releaseSection {
    HOLD["key"] = "";
}

def:pub heldSection -> str {
    d = new(Date);
    if HOLD["key"] and (d.getTime() as float) > (HOLD["until"] as float) {
        HOLD["key"] = "";
    }
    return HOLD["key"];
}

# The section under the reading line; the last one once the page is at its end,
# since a short last section can never reach the line.
def:pub sectionAtLine -> str {
    w: any = window;
    doc: any = document;
    page: any = doc.documentElement;
    if (w.innerHeight + w.scrollY) >= (page.scrollHeight - 2) {
        return SECTIONS[len(SECTIONS) - 1][0];
    }
    found = SECTIONS[0][0];
    for item in SECTIONS {
        el: any = doc.getElementById("section-" + item[0]);
        if el and el.getBoundingClientRect().top <= SPY_LINE {
            found = item[0];
        }
    }
    return found;
}
