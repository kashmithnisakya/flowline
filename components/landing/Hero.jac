"""Landing hero. Copy describes only what the app does today (a board plus a
written daily log): no trial terms, integrations or usage figures. The board
mock under the CTAs is decorative and aria-hidden.
"""

import from ..ui.button { Button }
import from ..common.KineticGrid { KineticGrid }

def:pub Hero(loggedIn: bool) -> JsxElement {
    return
        <section className="bg-glow relative overflow-hidden">
            <KineticGrid className="[mask-image:linear-gradient(to_bottom,black_55%,transparent)]"/>
            <div className="relative z-10 mx-auto max-w-[1180px] px-7 pt-20 pb-10 text-center">
                <span
                    className="anim-fade-up inline-block rounded-full border border-primary/20 bg-primary/10 px-3 py-1 text-xs font-semibold text-primary"
                >
                    For teams that hate status meetings
                </span>
                <h1
                    className="anim-fade-up anim-d1 font-display mx-auto mt-6 max-w-4xl text-[clamp(2.6rem,7vw,4.75rem)] font-extrabold leading-[0.94] tracking-[-0.045em]"
                >
                    Kill the daily meeting.
                    <br/>
                    Keep the daily.
                </h1>
                <p
                    className="anim-fade-up anim-d2 mx-auto mt-6 max-w-xl text-base leading-relaxed text-muted-foreground"
                >
                    standup keeps a kanban board for every project and a written log of who did what each day, so status is something your team reads, not another fifteen minutes on the calendar.
                </p>
                <div className="anim-fade-up anim-d3 mt-8 flex flex-wrap items-center justify-center gap-3">
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
                <p className="anim-fade-up anim-d4 mt-5 text-xs text-muted-foreground">
                    One account is one organization · your data stays in your own workspace
                </p>
                <div aria-hidden="true" className="anim-fade-up anim-d5 mx-auto mt-14 max-w-3xl">
                    <div className="rounded-2xl bg-background/70 p-3 shadow-xl ring-1 ring-foreground/10 backdrop-blur">
                        <div className="grid grid-cols-3 gap-3 text-left">
                            <div className="rounded-xl bg-muted/50 p-2.5">
                                <div className="flex items-center gap-1.5 px-1 pb-2">
                                    <span className="h-2 w-2 rounded-full bg-sky-500"></span>
                                    <span className="text-xs font-semibold text-muted-foreground">Up next</span>
                                </div>
                                <div className="space-y-2">
                                    <div className="rounded-lg bg-card p-2.5 shadow-xs ring-1 ring-foreground/10">
                                        <div className="h-2 w-3/4 rounded-full bg-foreground/15"></div>
                                        <div className="mt-2 h-1.5 w-8 rounded-full bg-sky-500/50"></div>
                                    </div>
                                    <div className="rounded-lg bg-card p-2.5 shadow-xs ring-1 ring-foreground/10">
                                        <div className="h-2 w-1/2 rounded-full bg-foreground/15"></div>
                                        <div className="mt-2 h-1.5 w-10 rounded-full bg-sky-500/50"></div>
                                    </div>
                                    <div className="rounded-lg bg-card p-2.5 shadow-xs ring-1 ring-foreground/10">
                                        <div className="h-2 w-2/3 rounded-full bg-foreground/15"></div>
                                        <div className="mt-2 h-1.5 w-7 rounded-full bg-sky-500/50"></div>
                                    </div>
                                </div>
                            </div>
                            <div className="rounded-xl bg-muted/50 p-2.5">
                                <div className="flex items-center gap-1.5 px-1 pb-2">
                                    <span className="h-2 w-2 rounded-full bg-amber-500"></span>
                                    <span className="text-xs font-semibold text-muted-foreground">In progress</span>
                                </div>
                                <div className="space-y-2">
                                    <div className="rounded-lg bg-card p-2.5 shadow-xs ring-1 ring-foreground/10">
                                        <div className="h-2 w-4/5 rounded-full bg-foreground/15"></div>
                                        <div className="mt-2 h-1.5 w-9 rounded-full bg-amber-500/50"></div>
                                    </div>
                                    <div className="rounded-lg bg-card p-2.5 shadow-xs ring-1 ring-foreground/10">
                                        <div className="h-2 w-3/5 rounded-full bg-foreground/15"></div>
                                        <div className="mt-2 h-1.5 w-7 rounded-full bg-amber-500/50"></div>
                                    </div>
                                </div>
                            </div>
                            <div className="rounded-xl bg-muted/50 p-2.5">
                                <div className="flex items-center gap-1.5 px-1 pb-2">
                                    <span className="h-2 w-2 rounded-full bg-emerald-500"></span>
                                    <span className="text-xs font-semibold text-muted-foreground">Done</span>
                                </div>
                                <div className="space-y-2">
                                    <div className="rounded-lg bg-card p-2.5 shadow-xs ring-1 ring-foreground/10">
                                        <div className="h-2 w-2/3 rounded-full bg-foreground/15"></div>
                                        <div className="mt-2 h-1.5 w-8 rounded-full bg-emerald-500/50"></div>
                                    </div>
                                    <div className="rounded-lg bg-card p-2.5 shadow-xs ring-1 ring-foreground/10">
                                        <div className="h-2 w-1/2 rounded-full bg-foreground/15"></div>
                                        <div className="mt-2 h-1.5 w-10 rounded-full bg-emerald-500/50"></div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </section>;
}
