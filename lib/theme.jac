"""Theme preference: light, dark, or follow the system. Applied by toggling the
`dark` class on <html>, persisted in localStorage; the layout applies it on
mount and the account menu, the palette and Preferences change it.
"""

glob THEME_KEY: str = "flowline-theme",
     # Pre-rename key, read once so an old browser keeps its choice.
     THEME_KEY_OLD: str = "standup-theme",
     THEME_PREFS: list[str] = ["light", "dark", "system"],
     # The page ground per theme, for the browser's own chrome on phones.
     GROUND_LIGHT: str = "#F2F3F1",
     GROUND_DARK: str = "#111413";

# Paint the theme at module-import time, before React mounts anything.
# lib/boot.js already did this from <head> before the bundle arrived; this
# keeps the two in step and the layout re-applies on mount for good measure.
with entry {
    applyTheme(getThemePref());
}


def:pub getThemePref -> str {
    saved = localStorage.getItem(THEME_KEY)
        or localStorage.getItem(THEME_KEY_OLD)
        or "";
    return saved if saved in THEME_PREFS else "system";
}


# Every change ends in a `flowline:theme` window event, so the chrome's theme
# controls stay in step when the palette or Preferences flips it.
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
    # lib/boot.js paints these two before the bundle runs; a theme change
    # in the app has to move them too, or the ground behind a short page
    # stays on the old theme.
    docRoot.style.colorScheme = "dark" if dark else "light";
    docRoot.style.backgroundColor = GROUND_DARK if dark else GROUND_LIGHT;
    meta: any = doc.querySelector("meta[name=theme-color]");
    if meta {
        meta.setAttribute("content", GROUND_DARK if dark else GROUND_LIGHT);
    }
    win.dispatchEvent(new(win.CustomEvent, "flowline:theme", {"detail": pref}));
}


def:pub setThemePref(pref: str) {
    localStorage.setItem(THEME_KEY, pref);
    applyTheme(pref);
}


# True when the dark palette is showing right now ("system" resolved).
def:pub isDarkNow -> bool {
    doc: any = document;
    return bool(doc.documentElement.classList.contains("dark"));
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
