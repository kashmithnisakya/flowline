"""Public site header. Shows the app link when a session already exists."""

import from "@jac/runtime" { Link }
import from ..ui.button { Button }

def:pub SiteNav(loggedIn: bool) -> JsxElement {
    <header className="sticky top-0 z-20 border-b border-border/70 bg-background/85 backdrop-blur">
        <nav className="mx-auto flex max-w-[1180px] items-center gap-8 px-7 py-4">
            <Link to="/" className="flex items-center gap-2">
                <img src="/static/brand/logo-mark.svg" alt="" width={28} height={28} />
                <span className="font-display text-lg font-bold tracking-tight">standup<span className="text-primary ml-0.5">.</span></span>
            </Link>
            <a href="#product" className="hidden text-sm text-muted-foreground transition-colors hover:text-foreground sm:block">
                Product
            </a>
            <a href="#how" className="hidden text-sm text-muted-foreground transition-colors hover:text-foreground sm:block">
                How it works
            </a>
            <a href="#faq" className="hidden text-sm text-muted-foreground transition-colors hover:text-foreground sm:block">
                FAQ
            </a>
            <div className="ml-auto flex items-center gap-2">
                {if loggedIn {
                    <Button key="app" onClick={lambda { window.location.href = "/board"; }}>
                        Go to your board
                    </Button>
                } else {
                    <div key="auth" className="flex items-center gap-2">
                        <Button
                            variant="ghost"
                            onClick={lambda { window.location.href = "/login"; }}
                        >
                            Sign in
                        </Button>
                        <Button onClick={lambda { window.location.href = "/login?mode=signup"; }}>
                            Create workspace
                        </Button>
                    </div>
                }}
            </div>
        </nav>
    </header>
}
