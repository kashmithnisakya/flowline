"""FAQ. Every answer is true of the app today, including the "not yet" ones;
update an answer when a capability lands, never soften it in advance."""

obj QA {
    has q: str,
        a: str;
}

glob FAQS: list[QA] = [
         QA(
             q="Does it connect to GitHub?",
             a="Yes. Install the GitHub App on the repositories you pick to import issues as cards and see the state of their pull requests. GitHub tells Flowline about changes as they happen. For each repository you can let a merged pull request or closed issue move its card to Done, and let Done close the issue. Both stay off until you turn them on. There is no Slack, Teams or mobile app today."
         ),
         QA(
             q="Where does my data live?",
             a="Open source under the MIT license. Each workspace is its own isolated graph, and you can run your own server."
         ),
         QA(
             q="Do my teammates need their own accounts?",
             a="No. One account runs the workspace. Teammates are people you add and assign cards to, so nobody else has a password to forget."
         ),
         QA(
             q="Can two people manage the same workspace?",
             a="Not yet. Today one account is one workspace, which is what keeps workspaces isolated from each other."
         ),
         QA(
             q="Do we have to use the same columns as everyone else?",
             a="No. You draw the flow line: name the steps your team uses and connect them however work moves, loops included. The board's columns are those steps. Start from the Simple template if you would rather not draw."
         ),
         QA(
             q="Can we import from another tool?",
             a="Only from GitHub: issues from the repositories you connect become cards. Everything else starts clean."
         )
     ];

def:pub Faq -> JsxElement {
    return
        <section
            id="faq"
            className="mx-auto grid max-w-[1180px] scroll-mt-16 gap-6 px-4 pt-14 sm:px-6 sm:pt-20 lg:grid-cols-[minmax(0,4fr)_minmax(0,8fr)] lg:gap-10"
        >
            <h2
                className="text-[clamp(1.625rem,3vw,2.125rem)] leading-tight font-bold tracking-[-0.012em] [font-stretch:118%] lg:sticky lg:top-24 lg:self-start"
            >
                Questions
            </h2>
            <div className="border-b">
                {for (i, f) in enumerate(FAQS) {
                    <details key={f.q} open={i < 2} className="group border-t py-4">
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
                            className="mt-2 max-w-[68ch] text-[15px] leading-relaxed text-muted-foreground"
                        >
                            {f.a}
                        </p>
                    </details>
                }}
            </div>
        </section>;
}
