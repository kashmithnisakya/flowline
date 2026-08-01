"""Landing hero.

Copy describes only what the app does today — a board plus a written daily
log. No trial terms, no chat-tool integrations, no usage figures.
"""

import from ..ui.button { Button }

def:pub Hero(loggedIn: bool) -> JsxElement {
    <section className="mx-auto max-w-[1180px] px-7 pt-20 pb-6 text-center">
        <span className="inline-block rounded-full border border-border bg-card px-3 py-1 text-xs font-semibold text-muted-foreground">
            For teams that hate status meetings
        </span>
        <h1 className="font-display mx-auto mt-6 max-w-4xl text-[clamp(2.6rem,7vw,4.75rem)] font-extrabold leading-[0.94] tracking-[-0.045em]">
            Kill the daily meeting.
            <br />
            Keep the daily.
        </h1>
        <p className="mx-auto mt-6 max-w-xl text-base leading-relaxed text-muted-foreground">
            standup keeps a kanban board for every project and a written log of who
            did what each day, so status is something your team reads, not another
            fifteen minutes on the calendar.
        </p>
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
            }}
            <Button
                variant="outline"
                className="h-12 px-7 text-base"
                onClick={lambda { window.location.href = "#how"; }}
            >
                See how it works
            </Button>
        </div>
        <p className="mt-5 text-xs text-muted-foreground">
            One account is one organization · your data stays in your own workspace
        </p>
    </section>
}
