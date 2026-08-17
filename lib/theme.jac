"""Theme preference: light, dark, or follow the system. Applied by toggling the
`dark` class on <html>, persisted in localStorage; the layout applies it on
mount and the Settings page changes it.
"""

glob THEME_KEY: str = "standup-theme",
     THEME_PREFS: list[str] = ["light", "dark", "system"];

# Paint the theme at module-import time, before React mounts anything, so a
# dark-mode user does not get a white flash on every full page load. The
# layout re-applies on mount for good measure.
with entry {
    applyTheme(getThemePref());
}


def:pub getThemePref -> str {
    saved = localStorage.getItem(THEME_KEY) or "";
    return saved if saved in THEME_PREFS else "system";
}


def:pub applyTheme(pref: str) {
    dark = pref == "dark";
    win: any = window;
    doc: any = document;
    if pref == "system" {
        media: any = win.matchMedia("(prefers-color-scheme: dark)");
        dark = bool(media.matches);
    }
    docRoot: any = doc.documentElement;
    if dark {
        docRoot.classList.add("dark");
    } else {
        docRoot.classList.remove("dark");
    }
}


def:pub setThemePref(pref: str) {
    localStorage.setItem(THEME_KEY, pref);
    applyTheme(pref);
}


# Keep a live session honest: on "system" the OS can flip mid-session (a
# scheduled sunset switch), and a choice made in another tab should not leave
# this one stale. Both handlers re-read the preference at event time, so an
# explicit light/dark choice still wins over the OS.
def:pub watchTheme {
    win: any = window;
    media: any = win.matchMedia("(prefers-color-scheme: dark)");
    media.addEventListener(
        "change", lambda { if getThemePref() == "system" { applyTheme("system"); }}
    );
    win.addEventListener(
        "storage",
        lambda (e: any) { if e.key == THEME_KEY { applyTheme(getThemePref()); }}
    );
}
