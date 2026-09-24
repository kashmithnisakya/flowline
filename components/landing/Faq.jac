"""FAQ. Every answer is true of the app today, including the "not yet" ones;
update an answer when a capability lands, never soften it in advance."""

obj QA {
    has q: str,
        a: str;
}

glob FAQS: list[QA] = [
         QA(
             q="Does it connect to GitHub?",
             a="Yes. Install the GitHub App on the repositories you pick to import issues as tasks and see the state of their pull requests. GitHub tells Flowline about changes as they happen. For each repository you can let a merged pull request or closed issue move its task to Done, and let Done close the issue. Both stay off until you turn them on. There is no Slack, Teams or mobile app today."
         ),
         QA(
             q="Where does my data live?",
             a="Open source under the MIT license. Each workspace is its own isolated graph, and you can run your own server."
         ),
         QA(
             q="Do my teammates need their own accounts?",
             a="No. One account runs the workspace. Teammates are people you add and assign tasks to, so nobody else has a password to forget."
         ),
         QA(
             q="Can two people manage the same workspace?",
             a="Not yet. Today one account is one workspace, which is what keeps workspaces isolated from each other."
         ),
         QA(
             q="Do we have to use the same steps as everyone else?",
             a="No. You draw the flow line: name the steps your team uses and connect them however work moves, loops included. The board groups the work under those steps, in order. Start from the Simple template if you would rather not draw."
         ),
         QA(
             q="Can we import from another tool?",
             a="Only from GitHub: issues from the repositories you connect become tasks. Everything else starts clean."
         )
     ];

def:pub Faq -> JsxElement {
    return
        <section
            id="faq"
            className="landing-wrap grid scroll-mt-16 gap-6 pt-16 sm:pt-24 lg:grid-cols-[minmax(0,4fr)_minmax(0,8fr)] lg:gap-10"
        >
            <div className="lg:sticky lg:top-24 lg:self-start">
                <p className="section-eyebrow">Answers</p>
                <h2
                    className="mt-3 text-[clamp(1.75rem,3.4vw,2.5rem)] leading-[1.1] font-bold tracking-[-0.025em]"
                >
                    Questions
                </h2>
            </div>
            <div className="grid gap-3 xl:grid-cols-2">
                {for (i, f) in enumerate(FAQS) {
                    <details
                        key={f.q}
                        open={i < 2}
                        className="bento-tile reveal group cursor-pointer gap-0 py-4"
                    >
                        <summary
                            className="flex cursor-pointer list-none items-start justify-between gap-6 text-left [&::-webkit-details-marker]:hidden"
                        >
                            <span className="text-base font-semibold">{f.q}</span>
                            <svg
                                width={16}
                                height={16}
                                viewBox="0 0 16 16"
                                aria-hidden="true"
                                className="mt-1 shrink-0 text-muted-foreground transition-transform duration-150 group-open:rotate-180"
                            >
                                <path
                                    d="m4.5 6.5 3.5 3.5 3.5-3.5"
                                    fill="none"
                                    stroke="currentColor"
                                    strokeWidth={1.6}
                                    strokeLinecap="round"
                                    strokeLinejoin="round"
                                />
                            </svg>
                        </summary>
                        <p
                            className="mt-2 max-w-[54ch] text-[15px] leading-relaxed text-muted-foreground"
                        >
                            {f.a}
                        </p>
                    </details>
                }}
            </div>
        </section>;
}
