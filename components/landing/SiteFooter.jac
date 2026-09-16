"""A plain closing call to action, then the site footer."""

import from ..ui.button { Button }
import from .Wordmark { Wordmark }

glob REPO_URL: str = "https://github.com/kashmithnisakya/flowline",
     FOOT_LINK: str = "text-muted-foreground transition-colors hover:text-foreground";

def:pub SiteFooter(loggedIn: bool) -> JsxElement {
    return
        <footer className="mx-auto max-w-[1180px] px-4 pt-16 pb-10 sm:px-6 sm:pt-24">
            <div className="grid gap-5">
                <h2
                    className="max-w-[24ch] text-[clamp(1.625rem,3vw,2.125rem)] leading-tight font-bold tracking-[-0.012em] [font-stretch:118%]"
                >
                    Draw your flow line this afternoon.
                </h2>
                <div
                    className="flex flex-col gap-4 sm:flex-row sm:flex-wrap sm:items-center sm:gap-6"
                >
                    <Button
                        asChild={True}
                        className="h-11 w-full px-5 text-[15px] font-semibold sm:w-auto"
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
                        className="text-sm font-semibold underline-offset-4 hover:underline"
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
