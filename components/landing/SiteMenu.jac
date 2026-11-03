"""The public header's links, and their disclosure below md: the page's
sections, the docs, the source and, for a visitor with no session, Sign in."""

glob:pub DOCS_URL: str = "https://kashmithnisakya.github.io/flowline/",
     REPO_URL: str = "https://github.com/kashmithnisakya/flowline",
     SECTIONS: list[list[str]] = [
         ["Flow line", "#draw"],
         ["AI", "#ai"],
         ["GitHub", "#github"],
         ["FAQ", "#faq"]
     ];

glob MENU_LINK: str = "flex min-h-11 items-center rounded-md px-3 text-sm font-medium text-text-secondary hover:bg-accent hover:text-foreground";

def:pub SiteMenu(loggedIn: bool, onClose: Callable[[], None]) -> JsxElement {
    return
        <div
            id="site-menu"
            className="grid gap-0.5 border-t bg-background px-2 py-2 md:hidden"
        >
            {for s in SECTIONS {
                <a key={s[1]} href={s[1]} className={MENU_LINK} onClick={onClose}>
                    {s[0]}
                </a>
            }}
            <a
                href={DOCS_URL}
                target="_blank"
                rel="noopener noreferrer"
                className={MENU_LINK}
            >
                Docs
            </a>
            <a
                href={REPO_URL}
                target="_blank"
                rel="noopener noreferrer"
                className={MENU_LINK}
            >
                Source on GitHub
            </a>
            {if not loggedIn {
                <a key="signin" href="/login" className={MENU_LINK}>Sign in</a>
            }}
        </div>;
}
