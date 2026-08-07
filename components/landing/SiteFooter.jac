"""Closing call to action plus the site footer."""

import from ..ui.button { Button }

def:pub SiteFooter(loggedIn: bool) -> JsxElement {
    return
        <footer className="mx-auto max-w-[1180px] px-7 pt-24 pb-14">
            <div
                className="rounded-3xl bg-foreground px-8 py-14 text-center text-background"
            >
                <h2
                    className="font-display mx-auto max-w-lg text-[clamp(1.9rem,4vw,3rem)] font-extrabold leading-[1.02] tracking-[-0.045em]"
                >
                    Tomorrow at 9:45,
                    <br/>
                    do something else.
                </h2>
                <div className="mt-8 flex flex-wrap items-center justify-center gap-3">
                    {if loggedIn {
                        <Button
                            key="app"
                            className="h-12 px-7 text-base"
                            onClick={lambda { window.location.href = "/board"; }}
                        >
                            Go to your board
                        </Button>
                    } else {
                        <Button
                            key="start"
                            className="h-12 px-7 text-base"
                            onClick={lambda { window.location.href = "/login?mode=signup"; }}
                        >
                            Create your workspace
                        </Button>
                    } }
                </div>
            </div>
            <div
                className="mt-10 flex flex-wrap items-center justify-between gap-4 text-xs text-muted-foreground"
            >
                <div className="flex items-center gap-2">
                    <img
                        src="/static/brand/logo-mark.svg"
                        alt=""
                        width={20}
                        height={20}
                    />
                    <span>
                        standup
                        <span className="text-primary ml-0.5">.</span>{" "}
                        · built with Jac
                    </span>
                </div>
                <div className="flex gap-5">
                    <a
                        href="#product"
                        className="transition-colors hover:text-foreground"
                    >
                        Product
                    </a>
                    <a href="#how" className="transition-colors hover:text-foreground">
                        How it works
                    </a>
                    <a href="#faq" className="transition-colors hover:text-foreground">
                        FAQ
                    </a>
                    <a
                        href="https://github.com/kashmithnisakya/standup"
                        target="_blank"
                        className="transition-colors hover:text-foreground"
                    >
                        Source
                    </a>
                </div>
            </div>
        </footer>;
}
