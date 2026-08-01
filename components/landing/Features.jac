"""What the product actually ships today — four cards, no roadmap items."""

import from ..ui.card { Card, CardContent }

obj Feature {
    has n: str,
        title: str,
        body: str,
        tag: str;
}

glob FEATURES: list[Feature] = [
    Feature(
        n="01",
        title="A board per project",
        body="Six columns from Backlog to Blocked, drag-and-drop between them, "
            + "filters by project, assignee and category. Where the work sits is "
            + "a glance, not a round-the-room.",
        tag="Board"
    ),
    Feature(
        n="02",
        title="A written daily log",
        body="One row per person per weekday: what they worked on, the project, "
            + "status, notes and links to the issue or PR. It becomes the archive "
            + "nobody has to remember.",
        tag="Daily Log"
    ),
    Feature(
        n="03",
        title="Projects and people you control",
        body="Create, rename and archive projects; add teammates and assign them "
            + "to as many projects as you need. Archiving keeps the history and "
            + "frees the open work.",
        tag="Admin"
    ),
    Feature(
        n="04",
        title="A workspace that is yours",
        body="Your account is your organization. Everything you create lives on "
            + "your own private graph — another account cannot read or touch it.",
        tag="Private"
    )
];

def:pub Features() -> JsxElement {
    <section id="product" className="mx-auto max-w-[1180px] px-7 pt-24">
        <h2 className="font-display max-w-xl text-[clamp(2rem,4vw,2.9rem)] font-bold leading-tight tracking-[-0.04em]">
            Everything a standup does. None of the 9:45.
        </h2>
        <p className="mt-4 max-w-2xl text-base text-muted-foreground">
            Four things replace the ritual — and unlike the meeting, the record is
            still there next month.
        </p>
        <div className="mt-10 grid gap-4 sm:grid-cols-2">
            {for f in FEATURES {
                <Card key={f.n} className="h-full">
                    <CardContent className="flex h-full flex-col gap-3 p-7">
                        <div className="flex items-center justify-between">
                            <span className="font-display text-sm font-bold text-primary">{f.n}</span>
                            <span className="rounded-full bg-accent px-2.5 py-1 text-[11px] font-semibold text-muted-foreground">
                                {f.tag}
                            </span>
                        </div>
                        <h3 className="font-display text-xl font-bold tracking-tight">{f.title}</h3>
                        <p className="text-sm leading-relaxed text-muted-foreground">{f.body}</p>
                    </CardContent>
                </Card>
            }}
        </div>
    </section>
}
