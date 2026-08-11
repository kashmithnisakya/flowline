"""Public site header. Shows the app link when a session already exists.

Below sm the anchor links live behind a disclosure toggle so phones can
still reach Product / How it works / FAQ.
"""

import from "@jac/runtime" { Link }
import from ..ui.button { Button }

def:pub SiteNav(loggedIn: bool) -> JsxElement {
    has menuOpen: bool = False;

    return
        <header
            className="sticky top-0 z-20 border-b border-border/70 bg-background/85 backdrop-blur"
        >
            <nav className="mx-auto flex max-w-[1180px] items-center gap-8 px-7 py-4">
                <Link to="/" className="flex items-center gap-2">
                    <img
                        src="/static/brand/logo-mark.svg"
                        alt=""
                        width={28}
                        height={28}
                    />
                    <span className="font-display text-lg font-bold tracking-tight">
                        standup
                        <span className="text-primary ml-0.5">.</span>
                    </span>
                </Link>
                <a
                    href="#product"
                    className="hidden text-sm text-muted-foreground transition-colors hover:text-foreground sm:block"
                >
                    Product
                </a>
                <a
                    href="#how"
                    className="hidden text-sm text-muted-foreground transition-colors hover:text-foreground sm:block"
                >
                    How it works
                </a>
                <a
                    href="#faq"
                    className="hidden text-sm text-muted-foreground transition-colors hover:text-foreground sm:block"
                >
                    FAQ
                </a>
                <div className="anim-fade-in ml-auto flex items-center gap-2">
                    {if loggedIn {
                        <Button
                            key="app"
                            size="lg"
                            onClick={lambda { window.location.href = "/board"; }}
                        >
                            Go to your board
                        </Button>
                    } else {
                        <div key="auth" className="flex items-center gap-2">
                            <Button
                                variant="ghost"
                                size="lg"
                                onClick={lambda { window.location.href = "/login"; }}
                            >
                                Sign in
                            </Button>
                            <Button
                                size="lg"
                                onClick={lambda { window.location.href = "/login?mode=signup"; }}
                            >
                                Create workspace
                            </Button>
                        </div>
                    } }
                    <Button
                        variant="ghost"
                        size="icon"
                        className="sm:hidden"
                        aria-label="Toggle menu"
                        aria-expanded={menuOpen}
                        onClick={lambda { menuOpen = not menuOpen; }}
                    >
                        {if menuOpen {
                            <svg
                                key="close"
                                width={16}
                                height={16}
                                viewBox="0 0 24 24"
                                fill="none"
                                stroke="currentColor"
                                strokeWidth={2}
                                strokeLinecap="round"
                                strokeLinejoin="round"
                            >
                                <path d="M18 6 6 18"/>
                                <path d="m6 6 12 12"/>
                            </svg>
                        } else {
                            <svg
                                key="open"
                                width={16}
                                height={16}
                                viewBox="0 0 24 24"
                                fill="none"
                                stroke="currentColor"
                                strokeWidth={2}
                                strokeLinecap="round"
                                strokeLinejoin="round"
                            >
                                <path d="M4 6h16"/>
                                <path d="M4 12h16"/>
                                <path d="M4 18h16"/>
                            </svg>
                        }}
                    </Button>
                </div>
            </nav>
            {if menuOpen {
                <div
                    key="menu"
                    className="border-t border-border/70 px-4 py-3 animate-in fade-in slide-in-from-top-2 duration-200 sm:hidden"
                >
                    <a
                        href="#product"
                        className="block rounded-lg px-3 py-2 text-sm font-medium text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
                        onClick={lambda { menuOpen = False; }}
                    >
                        Product
                    </a>
                    <a
                        href="#how"
                        className="block rounded-lg px-3 py-2 text-sm font-medium text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
                        onClick={lambda { menuOpen = False; }}
                    >
                        How it works
                    </a>
                    <a
                        href="#faq"
                        className="block rounded-lg px-3 py-2 text-sm font-medium text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
                        onClick={lambda { menuOpen = False; }}
                    >
                        FAQ
                    </a>
                </div>
            }}
        </header>;
}
