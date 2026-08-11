"""Three setup steps, these mirror the real onboarding wizard."""

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
                 + "you create is the organization. There is nothing else to set up."
         ),
         Step(
             n="2",
             title="Add projects and people",
             body="Name your first project, add your teammates, and put them on the "
                 + "projects they work on. Teammates do not need their own accounts."
         ),
         Step(
             n="3",
             title="Work the board, log the day",
             body="Move cards as work progresses and record one line per person per "
                 + "day. The week view is the summary you used to hold a meeting for."
         )
     ];

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
                    <div key={s.n} className="relative space-y-3">
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
                            <span className="font-display text-base font-bold text-primary">
                                {s.n}
                            </span>
                        </div>
                        <h3 className="font-display text-lg font-bold tracking-tight">
                            {s.title}
                        </h3>
                        <p className="text-sm leading-relaxed text-muted-foreground">
                            {s.body}
                        </p>
                    </div>
                }}
            </div>
        </section>;
}
