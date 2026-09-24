"""What else ships, as a ruled list of true sentences. Each row names a real
capability and the condition it depends on (the assistant needs a configured
model, the GitHub automations are per repository and off by default).
"""

obj Feature {
    has key: str,
        label: str,
        body: str;
}

glob FEATURES: list[Feature] = [
         Feature(
             key="github",
             label="GitHub",
             body="Install the GitHub App on the repositories you pick. Issues become tasks, a task's details show its pull request's state, and GitHub's updates reach an open board in under half a minute. Per repository you can let a merged pull request or closed issue move its task to Done, and let Done close the issue."
         ),
         Feature(
             key="assistant",
             label="Assistant",
             body="When the server has a language model configured, the assistant drafts today's standup from the workspace, answers questions about it, and proposes changes that you confirm before anything is saved."
         ),
         Feature(
             key="overview",
             label="Overview",
             body="What needs someone now, this week's figures, burn-up and done per week, counted from the board rather than typed in."
         ),
         Feature(
             key="roadmap",
             label="Roadmap",
             body="Give tasks start and due dates and follow them on a twelve-week roadmap, grouped by step."
         ),
         Feature(
             key="checklists",
             label="Checklists",
             body="Break a task into a checklist. Its row shows how far along it is, and each item you tick off lands in the task's travel so far."
         ),
         Feature(
             key="people",
             label="People",
             body="Teammates are people you add and assign, not accounts. One sign-in runs the workspace, and archiving someone keeps their history."
         )
     ];

def:pub Features -> JsxElement {
    return
        <section className="landing-wrap pt-14 sm:pt-20">
            <h2
                className="text-[clamp(1.625rem,3vw,2.125rem)] leading-tight font-bold tracking-[-0.012em]"
            >
                What else ships
            </h2>
            <dl className="mt-6 border-b xl:grid xl:grid-cols-2">
                {for f in FEATURES {
                    <div
                        key={f.key}
                        id={f.key}
                        className="grid scroll-mt-20 gap-1 border-t py-4 md:grid-cols-[13rem_minmax(0,1fr)] md:gap-6 xl:grid-cols-[11rem_minmax(0,1fr)] xl:odd:pr-8 xl:even:pl-8"
                    >
                        <dt className="text-[15px] font-semibold">{f.label}</dt>
                        <dd
                            className="max-w-[54ch] text-[15px] leading-relaxed text-muted-foreground"
                        >
                            {f.body}
                        </dd>
                    </div>
                }}
            </dl>
        </section>;
}
