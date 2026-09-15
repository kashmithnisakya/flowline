"""Landing hero. Copy describes only what the app does today (a board plus a
written daily log): no trial terms, integrations or usage figures. At lg the
hero splits, copy left and the playable board (HeroBoard) right; below that
the board stacks under the centered copy.
"""

import from ..ui.button { Button }
import from .HeroBoard { HeroBoard }

def:pub Hero(loggedIn: bool) -> JsxElement {
    return
        <section className="relative overflow-hidden">
            <div
                className="relative z-10 mx-auto max-w-[1180px] px-7 pt-16 pb-12 lg:pt-24 lg:pb-16"
            >
                <div
                    className="grid items-center gap-10 lg:grid-cols-[5fr_6fr] lg:gap-14"
                >
                    <div className="text-center lg:text-left">
                        <span
                            className="inline-block rounded-full border border-primary/20 bg-primary/10 px-3 py-1 text-xs font-semibold text-primary"
                        >
                            For teams that hate status meetings
                        </span>
                        <h1
                            className="font-display mx-auto mt-6 max-w-2xl text-[clamp(2.5rem,5.5vw,3.9rem)] font-extrabold leading-[0.94] tracking-[-0.045em] lg:mx-0"
                        >
                            Kill the daily meeting.
                            <br/>
                            Keep the daily.
                        </h1>
                        <p
                            className="mx-auto mt-6 max-w-xl text-base leading-relaxed text-muted-foreground lg:mx-0"
                        >
                            Flowline keeps a kanban board for every project and a written log of who did what each day, so status is something your team reads, not another fifteen minutes on the calendar.
                        </p>
                        <div
                            className="mt-8 flex flex-wrap items-center justify-center gap-3 lg:justify-start"
                        >
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
                    </div>
                    <HeroBoard loggedIn={loggedIn}/>
                </div>
            </div>
        </section>;
}
