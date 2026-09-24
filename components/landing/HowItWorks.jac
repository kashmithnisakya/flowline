"""The setup wizard as three numbered steps, grouped the way it asks them. The
sign-up sentence names providers only once the sign-in page has seen them."""

import from ..auth.SsoButtons { SignUpMethods }

glob STEP_CARD: str = "bento-tile scroll-mt-20";

def:pub HowItWorks -> JsxElement {
    return
        <section id="how" className="landing-wrap scroll-mt-16 pt-16 sm:pt-24">
            <p className="section-eyebrow">Getting started</p>
            <h2
                className="mt-3 max-w-[28ch] text-[clamp(1.75rem,3.4vw,2.5rem)] leading-[1.1] font-bold tracking-[-0.025em]"
            >
                From sign-up to a first task in three steps
            </h2>
            <ol className="mt-8 grid gap-4 md:grid-cols-3">
                <li className={STEP_CARD}>
                    <span
                        className="num inline-flex size-7 items-center justify-center rounded-full border border-primary/25 bg-primary/10 text-[13px] font-semibold text-primary"
                        aria-hidden="true"
                    >
                        1
                    </span>
                    <h3 className="text-base font-semibold">Create your workspace</h3>
                    <p className="text-[15px] leading-relaxed text-muted-foreground">
                        <SignUpMethods/>
                        {" Then name your team and its first project."}
                    </p>
                </li>
                <li className={STEP_CARD}>
                    <span
                        className="num inline-flex size-7 items-center justify-center rounded-full border border-primary/25 bg-primary/10 text-[13px] font-semibold text-primary"
                        aria-hidden="true"
                    >
                        2
                    </span>
                    <h3 className="text-base font-semibold">Add your people</h3>
                    <p className="text-[15px] leading-relaxed text-muted-foreground">
                        Add the people who work on that project. They are names you assign tasks to, not accounts, and you can skip this for now.
                    </p>
                </li>
                <li className={STEP_CARD}>
                    <span
                        className="num inline-flex size-7 items-center justify-center rounded-full border border-primary/25 bg-primary/10 text-[13px] font-semibold text-primary"
                        aria-hidden="true"
                    >
                        3
                    </span>
                    <h3 className="text-base font-semibold">Pick how work moves</h3>
                    <p className="text-[15px] leading-relaxed text-muted-foreground">
                        Pick a template and the board opens with a new task ready to type. Or draw your own steps on the flow line page.
                    </p>
                </li>
            </ol>
        </section>;
}
