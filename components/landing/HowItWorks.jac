"""The setup wizard as three numbered steps, in the order it asks them. The
sign-up sentence names only the sign-in providers this server has enabled."""

import from ..auth.SsoButtons { SignUpMethods }

glob STEP_ROW: str = "grid content-start gap-2 border-t py-5 md:border-t-0 md:border-l md:px-6 md:first:border-l-0 md:first:pl-0";

def:pub HowItWorks -> JsxElement {
    return
        <section
            id="how"
            className="mx-auto max-w-[1180px] scroll-mt-16 px-4 pt-14 sm:px-6 sm:pt-20"
        >
            <h2
                className="max-w-[28ch] text-[clamp(1.625rem,3vw,2.125rem)] leading-tight font-bold tracking-[-0.012em] [font-stretch:118%]"
            >
                From sign-up to a first card in three steps
            </h2>
            <ol className="mt-6 grid md:grid-cols-3 md:border-t md:pt-6">
                <li className={STEP_ROW}>
                    <span className="font-mono text-[12.5px] text-subtle">1</span>
                    <h3 className="text-base font-semibold [font-stretch:108%]">
                        Create your workspace
                    </h3>
                    <p className="text-[15px] leading-relaxed text-muted-foreground">
                        <SignUpMethods/>
                    </p>
                </li>
                <li className={STEP_ROW}>
                    <span className="font-mono text-[12.5px] text-subtle">2</span>
                    <h3 className="text-base font-semibold [font-stretch:108%]">
                        Name a project, add your people
                    </h3>
                    <p className="text-[15px] leading-relaxed text-muted-foreground">
                        Name your first project and add the people who work on it. They are names you assign cards to, not accounts, and you can skip them for now.
                    </p>
                </li>
                <li className={STEP_ROW}>
                    <span className="font-mono text-[12.5px] text-subtle">3</span>
                    <h3 className="text-base font-semibold [font-stretch:108%]">
                        Pick how work moves
                    </h3>
                    <p className="text-[15px] leading-relaxed text-muted-foreground">
                        Start from the Simple template or draw your own steps. The board opens with a new card ready to type.
                    </p>
                </li>
            </ol>
        </section>;
}
