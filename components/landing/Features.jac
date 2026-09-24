"""What else ships, as a bento grid of true sentences. Each row names a real
capability and the condition it depends on (the assistant needs a configured
model, the GitHub automations are per repository and off by default).
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
             body="Install the GitHub App on the repositories you pick. Issues become tasks, a task's details show its pull request's state, and GitHub's updates reach an open board in under half a minute. Per repository you can let a merged pull request or closed issue move its task to Done, and let Done close the issue.",
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
             body="What needs someone now, this week's figures, burn-up and done per week, counted from the board rather than typed in.",
             icon=Analytics01Icon,
             span="lg:col-span-2"
         ),
         Feature(
             key="roadmap",
             label="Roadmap",
             body="Give tasks start and due dates and follow them on a twelve-week roadmap, grouped by step.",
             icon=Calendar03Icon,
             span="lg:col-span-4"
         ),
         Feature(
             key="checklists",
             label="Checklists",
             body="Break a task into a checklist. Its row shows how far along it is, and each item you tick off lands in the task's travel so far.",
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
