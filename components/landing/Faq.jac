"""FAQ, on the spine. Every answer is true of the app today, including the "not
yet" ones; update an answer when a capability lands, never soften it in advance.
"""

import from .Spine { SpineStep, StepCopy }

obj QA {
    has q: str,
        a: str;
}

glob FAQS: list[QA] = [
         QA(
             q="What does the AI see?",
             a="A responsibility, only while AI is on and only for a task it runs on, sees the changed files of its linked pull request, the task's title and first note line, and your team's instructions. Ask, when you use it, sees a summary of the workspace: counts, blocked, overdue, aging and in-review tasks, people, projects and recent log lines. Both go to the model provider your server is set up with."
         ),
         QA(
             q="Where does my data live?",
             a="Flowline is open source under the MIT license. Each workspace is its own isolated graph, and you can run your own server."
         ),
         QA(
             q="Do my teammates need their own accounts?",
             a="No. One account runs the workspace. Teammates are people you add and assign tasks to."
         ),
         QA(
             q="Can two people manage the same workspace?",
             a="Not yet. Today one account is one workspace."
         ),
         QA(
             q="Can we import from another tool?",
             a="Only from GitHub: issues from the repositories you connect become tasks. Everything else starts clean."
         ),
         QA(
             q="Is there Slack, Teams or a mobile app?",
             a="Not today. The web app works on a phone."
         )
     ];

def:pub Faq -> JsxElement {
    return
        <SpineStep anchor="faq">
            <div className="lp-step-grid items-start">
                <StepCopy label="Answers">
                    {'Straight answers, including the "not yet" ones.'}
                </StepCopy>
                <div>
                    {for (i, f) in enumerate(FAQS) {
                        <details
                            key={f.q}
                            open={i == 0}
                            className="group border-b py-4"
                        >
                            <summary
                                className="flex cursor-pointer list-none items-start justify-between gap-6 text-base font-medium [&::-webkit-details-marker]:hidden"
                            >
                                {f.q}
                                <svg
                                    width={16}
                                    height={16}
                                    viewBox="0 0 16 16"
                                    aria-hidden="true"
                                    className="mt-1 shrink-0 text-text-tertiary transition-transform duration-150 group-open:rotate-180"
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
                                className="mt-2 max-w-[62ch] text-[15px] leading-[1.55] text-text-secondary"
                            >
                                {f.a}
                            </p>
                        </details>
                    }}
                </div>
            </div>
        </SpineStep>;
}
