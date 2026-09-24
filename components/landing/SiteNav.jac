"""Public site header. A session swaps the calls to action for the board link.
Below md the anchors and Sign in move into a disclosure menu, leaving the
mark, one compact primary action and the menu button on a phone's row.
"""

import from ..ui.button { Button }
import from .Wordmark { Wordmark }

glob REPO_URL: str = "https://github.com/kashmithnisakya/flowline",
     NAV_LINK: str = "rounded-full px-3 py-1.5 text-[13.5px] text-muted-foreground transition-colors hover:bg-accent/70 hover:text-foreground",
     MENU_LINK: str = "flex min-h-11 items-center rounded-md px-3 text-sm font-medium text-muted-foreground hover:bg-accent hover:text-foreground";

def:pub SiteNav(loggedIn: bool) -> JsxElement {
    has menuOpen: bool = False;

    return
        <header
            className="sticky top-0 z-30 border-b border-border/50 bg-background/70 backdrop-blur-xl"
        >
            <nav
                aria-label="Site"
                className="landing-wrap grid h-16 grid-cols-[1fr_auto_1fr] items-center gap-4"
            >
                <a
                    href="/"
                    aria-label="flowline home"
                    className="justify-self-start rounded-sm"
                >
                    <Wordmark/>
                </a>
                <div
                    className="glass-pill hidden items-center gap-0.5 px-1.5 py-1 md:flex"
                >
                    <a href="#tour" className={NAV_LINK}>Tour</a>
                    <a href="#github" className={NAV_LINK}>GitHub</a>
                    <a href="#faq" className={NAV_LINK}>FAQ</a>
                    <a
                        href={REPO_URL}
                        target="_blank"
                        rel="noopener noreferrer"
                        className={NAV_LINK}
                    >
                        Source
                    </a>
                </div>
                <div className="flex items-center gap-2 justify-self-end">
                    {if loggedIn {
                        <Button
                            key="app"
                            asChild={True}
                            size="sm"
                            className="rounded-full"
                        >
                            <a href="/board">Go to your board</a>
                        </Button>
                    } else {
                        <div key="auth" className="flex items-center gap-2">
                            <Button
                                asChild={True}
                                variant="ghost"
                                size="sm"
                                className="hidden rounded-full text-muted-foreground md:inline-flex"
                            >
                                <a href="/login">Sign in</a>
                            </Button>
                            <Button asChild={True} size="sm" className="rounded-full">
                                <a href="/login?mode=signup">
                                    <span className="sm:hidden">Create workspace</span>
                                    <span className="hidden sm:inline">
                                        Create your workspace
                                    </span>
                                </a>
                            </Button>
                        </div>
                    } }
                    <Button
                        variant="ghost"
                        size="icon"
                        className="md:hidden"
                        aria-label="Menu"
                        aria-expanded={menuOpen}
                        aria-controls="site-menu"
                        onClick={lambda { menuOpen = not menuOpen; }}
                    >
                        <svg
                            width={16}
                            height={16}
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth={2}
                            strokeLinecap="round"
                            aria-hidden="true"
                        >
                            <path
                                d={"M18 6 6 18M6 6l12 12"
                                    if menuOpen
                                    else "M4 7h16M4 12h16M4 17h16"}
                            />
                        </svg>
                    </Button>
                </div>
            </nav>
            {if menuOpen {
                <div
                    key="menu"
                    id="site-menu"
                    className="grid gap-0.5 border-t bg-background/95 px-2 py-2 backdrop-blur-xl md:hidden"
                >
                    <a
                        href="#tour"
                        className={MENU_LINK}
                        onClick={lambda { menuOpen = False; }}
                    >
                        Tour
                    </a>
                    <a
                        href="#github"
                        className={MENU_LINK}
                        onClick={lambda { menuOpen = False; }}
                    >
                        GitHub
                    </a>
                    <a
                        href="#faq"
                        className={MENU_LINK}
                        onClick={lambda { menuOpen = False; }}
                    >
                        FAQ
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
                </div>
            }}
        </header>;
}
