"""What the product actually ships today, four cards, nothing aspirational."""

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
             title="A workflow you design",
             body="Name the steps your team actually uses and connect them however " + "work moves, loops included. The board is those steps, with " + "drag-and-drop between them and filters by project and assignee.",
             tag="Workflow"
         ),
         Feature(
             n="02",
             title="A written daily log",
             body="One row per person per weekday: what they worked on, the project, " + "status, notes and links to the issue or PR. It becomes the archive " + "nobody has to remember.",
             tag="Daily Log"
         ),
         Feature(
             n="03",
             title="Projects and people you control",
             body="Create, rename and archive projects; add teammates and assign them " + "to as many projects as you need. Archiving keeps the history and " + "frees the open work.",
             tag="Admin"
         ),
         Feature(
             n="04",
             title="A workspace that is yours",
             body="Your account is your organization. Everything you create lives on " + "your own private graph. Another account cannot read or touch it.",
             tag="Private"
         )
     ];

def:pub Features -> JsxElement {
    return
        <section
            id="product"
            className="mx-auto max-w-[1180px] scroll-mt-24 px-7 pt-24"
        >
            <span
                className="text-xs font-semibold uppercase tracking-widest text-primary"
            >
                Product
            </span>
            <h2
                className="font-display mt-3 max-w-xl text-[clamp(1.9rem,4vw,2.65rem)] font-bold leading-tight tracking-[-0.04em]"
            >
                Everything a standup does. None of the 9:45.
            </h2>
            <p className="mt-4 max-w-2xl text-base text-muted-foreground">
                Four things replace the ritual, and unlike the meeting, the record is still there next month.
            </p>
            <div className="mt-10 grid gap-6 sm:grid-cols-2">
                {for f in FEATURES {
                    <Card
                        key={f.n}
                        className="card-hover h-full py-0 hover:ring-foreground/20"
                    >
                        <CardContent className="flex h-full flex-col gap-3 p-7">
                            <div className="flex items-center justify-between">
                                <span
                                    className="font-display text-sm font-bold text-primary"
                                >
                                    {f.n}
                                </span>
                                <span
                                    className="rounded-full border border-primary/20 bg-primary/10 px-2.5 py-1 text-xs font-semibold text-primary"
                                >
                                    {f.tag}
                                </span>
                            </div>
                            <h3
                                className="font-display text-xl font-bold tracking-tight"
                            >
                                {f.title}
                            </h3>
                            <p
                                className="text-sm leading-relaxed text-muted-foreground"
                            >
                                {f.body}
                            </p>
                        </CardContent>
                    </Card>
                }}
            </div>
        </section>;
}
