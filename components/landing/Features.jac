"""What else ships, as a bento grid of true sentences. Each tile names a real
capability and the condition it depends on (the assistant needs a configured
model, the GitHub automations are per repository and off by default). The two
flagship tiles run wider than the rest, so the grid ranks the capabilities
instead of flattening them into equal rows.
"""

import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    GithubIcon,
    SparklesIcon,
    Analytics01Icon,
    Calendar03Icon,
    CheckListIcon,
    UserGroupIcon
}

obj Feature {
    has key: str,
        label: str,
        body: str,
        icon: any,
        span: str;
}

glob FEATURES: list[Feature] = [
         Feature(
             key="github",
             label="GitHub",
             body="Install the GitHub App on the repositories you pick. Issues become cards, a card's details show its pull request's state, and GitHub's updates reach an open board in under half a minute. Per repository you can let a merged pull request or closed issue move its card to Done, and let Done close the issue.",
             icon=GithubIcon,
             span="lg:col-span-4"
         ),
         Feature(
             key="assistant",
             label="Assistant",
             body="When the server has a language model configured, the assistant drafts today's standup from the workspace, answers questions about it, and proposes changes that you confirm before anything is saved.",
             icon=SparklesIcon,
             span="lg:col-span-2"
         ),
         Feature(
             key="overview",
             label="Overview",
             body="Needs attention, the review queue, burn-up and throughput, counted from the board and the log rather than typed in.",
             icon=Analytics01Icon,
             span="lg:col-span-2"
         ),
         Feature(
             key="plan",
             label="Iterations and roadmap",
             body="Give cards start and due dates, plan them into iterations, and follow the work on a twelve-week roadmap.",
             icon=Calendar03Icon,
             span="lg:col-span-4"
         ),
         Feature(
             key="checklists",
             label="Checklists",
             body="Break a card into a checklist. Each item you tick off writes its own line in the log.",
             icon=CheckListIcon,
             span="lg:col-span-3"
         ),
         Feature(
             key="people",
             label="People",
             body="Teammates are people you add and assign, not accounts. One sign-in runs the workspace, and archiving someone keeps their history.",
             icon=UserGroupIcon,
             span="lg:col-span-3"
         )
     ];

def:pub Features -> JsxElement {
    return
        <section className="landing-wrap pt-16 sm:pt-24">
            <p className="section-eyebrow">Capabilities</p>
            <h2
                className="mt-3 text-[clamp(1.75rem,3.4vw,2.5rem)] leading-[1.1] font-bold tracking-[-0.025em]"
            >
                What else ships
            </h2>
            <p
                className="mt-2 max-w-[62ch] text-[15px] leading-relaxed text-muted-foreground"
            >
                Everything below is in the app today. Where a capability depends on something, the tile says so.
            </p>
            <div className="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-6">
                {for f in FEATURES {
                    <article
                        key={f.key}
                        id={f.key}
                        className={"bento-tile scroll-mt-20 " + f.span}
                    >
                        <span className="tile-icon" aria-hidden="true">
                            <HugeiconsIcon icon={f.icon} size={20} strokeWidth={1.8}/>
                        </span>
                        <h3 className="text-[15px] font-semibold tracking-[-0.01em]">
                            {f.label}
                        </h3>
                        <p
                            className="max-w-[54ch] text-[14.5px] leading-relaxed text-muted-foreground"
                        >
                            {f.body}
                        </p>
                    </article>
                }}
            </div>
        </section>;
}
