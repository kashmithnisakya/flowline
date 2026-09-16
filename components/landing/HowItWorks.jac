"""Three setup steps, these mirror the real onboarding wizard. Each step
carries a small mock of the screen it happens on: the signup form, the
roster, then the board writing the log.
"""

import from ..common.Avatar { Avatar }

obj Step {
    has n: str,
        title: str,
        body: str;
}

glob STEPS: list[Step] = [
         Step(
             n="1",
             title="Create your workspace",
             body="Sign up with your work email and name your organization. The account "
             "you create is the organization. There is nothing else to set up."
         ),
         Step(
             n="2",
             title="Add projects and people",
             body="Name your first project, add your teammates, and put them on the "
             "projects they work on. Teammates do not need their own accounts."
         ),
         Step(
             n="3",
             title="Work the board, log the day",
             body="Move cards as work progresses and record one line per person per "
             "day. The week view is the summary you used to hold a meeting for."
         )
     ];

# The screen each step happens on, reduced to a glanceable mock.
def StepThumb(n: str) -> JsxElement {
    if n == "1" {
        return
            <div
                aria-hidden="true"
                className="mt-auto flex h-24 flex-col justify-center gap-2 rounded-xl border bg-card p-4"
            >
                <div className="h-4 w-4/5 rounded-md border bg-muted/40"></div>
                <div className="h-4 w-3/5 rounded-md border bg-muted/40"></div>
                <div className="h-5 w-2/5 rounded-md bg-primary"></div>
            </div>;
    }
    if n == "2" {
        return
            <div
                aria-hidden="true"
                className="mt-auto flex h-24 flex-col justify-center gap-2.5 rounded-xl border bg-card p-4"
            >
                <div className="flex">
                    <span className="inline-flex">
                        <Avatar
                            name="Amara Perera"
                            size="sm"
                            className="ring-2 ring-card"
                        />
                    </span>
                    <span className="-ml-2 inline-flex">
                        <Avatar
                            name="Kasun Silva"
                            size="sm"
                            className="ring-2 ring-card"
                        />
                    </span>
                    <span className="-ml-2 inline-flex">
                        <Avatar
                            name="Priya Raman"
                            size="sm"
                            className="ring-2 ring-card"
                        />
                    </span>
                </div>
                <div className="flex gap-1.5">
                    <span
                        className="rounded-full border px-2 py-0.5 text-[9px] font-medium text-muted-foreground"
                    >
                        Launch Site
                    </span>
                    <span
                        className="rounded-full border px-2 py-0.5 text-[9px] font-medium text-muted-foreground"
                    >
                        Platform
                    </span>
                </div>
            </div>;
    }
    return
        <div
            aria-hidden="true"
            className="mt-auto flex h-24 flex-col justify-center gap-2 rounded-xl border bg-card p-4"
        >
            <div className="grid grid-cols-3 gap-1.5">
                <div
                    className="h-8 rounded-md border-t-[3px] border-t-step-sky bg-step-sky-wash"
                ></div>
                <div
                    className="h-8 rounded-md border-t-[3px] border-t-step-amber bg-step-amber-wash"
                ></div>
                <div
                    className="h-8 rounded-md border-t-[3px] border-t-step-emerald bg-step-emerald-wash"
                ></div>
            </div>
            <div className="flex items-center gap-1.5">
                <span
                    className="text-[8px] font-semibold uppercase tracking-wide text-muted-foreground"
                >
                    Log
                </span>
                <div className="h-2 w-3/5 rounded bg-muted"></div>
            </div>
        </div>;
}

def:pub HowItWorks -> JsxElement {
    return
        <section id="how" className="mx-auto max-w-[1180px] scroll-mt-24 px-7 pt-24">
            <span
                className="text-xs font-semibold uppercase tracking-widest text-primary"
            >
                How it works
            </span>
            <h2
                className="font-display mt-3 max-w-2xl text-[clamp(1.9rem,4vw,2.65rem)] font-bold leading-tight tracking-[-0.04em]"
            >
                Three steps, then it is just how the team works.
            </h2>
            <div className="mt-10 grid gap-8 md:grid-cols-3">
                {for s in STEPS {
                    <div key={s.n} className="relative flex h-full flex-col gap-3">
                        {if s.n != "3" {
                            <div
                                key="line"
                                aria-hidden="true"
                                className="absolute -right-8 left-12 top-5 hidden h-px bg-border md:block"
                            ></div>
                        }}
                        <div
                            className="flex h-10 w-10 items-center justify-center rounded-full bg-background shadow-xs ring-1 ring-foreground/15"
                        >
                            <span
                                className="font-display text-base font-bold text-primary"
                            >
                                {s.n}
                            </span>
                        </div>
                        <h3 className="font-display text-lg font-bold tracking-tight">
                            {s.title}
                        </h3>
                        <p className="text-sm leading-relaxed text-muted-foreground">
                            {s.body}
                        </p>
                        {StepThumb(s.n)}
                    </div>
                }}
            </div>
        </section>;
}
