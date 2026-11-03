"""Public site header: the mark, the page's sections, then Sign in and the
primary action. A session swaps those two for the board link. Below md the
links move into SiteMenu, leaving the mark, one action and the menu button.
"""

import from ..ui.button { Button }
import from .SiteMenu { SiteMenu, SECTIONS, DOCS_URL }
import from .Wordmark { Wordmark }

glob NAV_LINK: str = "text-text-secondary transition-colors hover:text-foreground";

def:pub SiteNav(loggedIn: bool) -> JsxElement {
    has menuOpen: bool = False;

    return
        <header>
            <div className="lp-wrap flex items-center gap-6 py-4">
                <a href="/" aria-label="Flowline home" className="shrink-0 rounded-sm">
                    <Wordmark/>
                </a>
                <nav
                    aria-label="Page sections"
                    className="hidden items-center gap-5 text-sm md:flex"
                >
                    {for s in SECTIONS {
                        <a key={s[1]} href={s[1]} className={NAV_LINK}>{s[0]}</a>
                    }}
                    <a
                        href={DOCS_URL}
                        target="_blank"
                        rel="noopener noreferrer"
                        className={NAV_LINK}
                    >
                        Docs
                    </a>
                </nav>
                <div className="ml-auto flex items-center gap-2">
                    {if loggedIn {
                        <Button key="app" asChild={True} className="text-[13px]">
                            <a href="/board">Go to your board</a>
                        </Button>
                    } else {
                        <Button
                            key="signin"
                            asChild={True}
                            variant="ghost"
                            className="hidden text-[13px] md:inline-flex"
                        >
                            <a href="/login">Sign in</a>
                        </Button>
                    } }
                    {if not loggedIn {
                        <Button key="signup" asChild={True} className="text-[13px]">
                            <a href="/login?mode=signup">
                                <span className="sm:hidden">Create workspace</span>
                                <span className="hidden sm:inline">
                                    Create your workspace
                                </span>
                            </a>
                        </Button>
                    }}
                    <Button
                        variant="ghost"
                        size="icon"
                        className="md:hidden"
                        aria-label="Menu"
                        title="Menu"
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
            </div>
            {if menuOpen {
                <SiteMenu
                    key="menu"
                    loggedIn={loggedIn}
                    onClose={lambda { menuOpen = False; }}
                />
            }}
        </header>;
}
