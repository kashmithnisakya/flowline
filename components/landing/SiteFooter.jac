"""The closing call to action as one lit panel, then the site footer. The
panel carries the same two glows as the hero, so the page opens and closes on
the same note."""

import from ..ui.button { Button }
import from .Wordmark { Wordmark }

glob REPO_URL: str = "https://github.com/kashmithnisakya/flowline",
     FOOT_LINK: str = "text-muted-foreground transition-colors hover:text-foreground";

def:pub SiteFooter(loggedIn: bool) -> JsxElement {
    return
        <footer className="landing-wrap pt-16 pb-10 sm:pt-24">
            <div
                className="cta-band reveal grid gap-5 px-6 py-10 sm:px-10 sm:py-14 lg:px-14 lg:py-16"
            >
                <p className="section-eyebrow">Open source, MIT licensed</p>
                <h2
                    className="max-w-[24ch] text-[clamp(1.75rem,3.4vw,2.5rem)] leading-[1.1] font-bold tracking-[-0.025em]"
                >
                    Draw your flow line this afternoon.
                </h2>
                <div
                    className="flex flex-col gap-4 sm:flex-row sm:flex-wrap sm:items-center sm:gap-6"
                >
                    <Button
                        asChild={True}
                        className="h-12 w-full rounded-md px-7 text-[15px] font-semibold shadow-[var(--float-1)] sm:w-auto"
                    >
                        <a href={"/board" if loggedIn else "/login?mode=signup"}>
                            {"Go to your board"
                                if loggedIn
                                else "Create your workspace"}
                        </a>
                    </Button>
                    <a
                        href={REPO_URL}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="glass-pill inline-flex h-12 items-center justify-center px-6 text-sm font-semibold text-foreground transition-colors hover:text-primary"
                    >
                        Read the source
                    </a>
                </div>
            </div>
            <div
                className="mt-14 flex flex-col gap-4 border-t pt-6 text-[13px] sm:flex-row sm:items-center sm:justify-between"
            >
                <div className="flex flex-wrap items-center gap-x-3 gap-y-1">
                    <Wordmark/>
                    <span className="text-muted-foreground">
                        Built with Jac · MIT licensed
                    </span>
                </div>
                <nav aria-label="Footer" className="flex flex-wrap gap-x-5 gap-y-2">
                    <a href="#tour" className={FOOT_LINK}>Tour</a>
                    <a href="#how" className={FOOT_LINK}>Setup</a>
                    <a href="#faq" className={FOOT_LINK}>FAQ</a>
                    <a
                        href={REPO_URL}
                        target="_blank"
                        rel="noopener noreferrer"
                        className={FOOT_LINK}
                    >
                        Source
                    </a>
                </nav>
            </div>
        </footer>;
}
