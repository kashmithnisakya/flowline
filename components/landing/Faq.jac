"""FAQ.

Every answer here is true of the app as it stands today, including the
honest "not yet" ones. If a capability lands later, update the answer —
do not soften it in advance.
"""

obj QA {
    has q: str,
        a: str;
}

glob FAQS: list[QA] = [
    QA(
        q="Do my teammates need their own accounts?",
        a="No. Only the person managing the projects signs in. Teammates are "
            + "roster records you create, and you log the day on their behalf, "
            + "so nobody else has a password to forget."
    ),
    QA(
        q="Can two managers share one organization?",
        a="Not yet. Today one account is one organization, which is what keeps "
            + "workspaces completely isolated from each other. Multi-manager "
            + "organizations are the next thing on the list."
    ),
    QA(
        q="Where does my data live?",
        a="On your own private graph inside the workspace you created. Every "
            + "request runs against your account's own data, so another account "
            + "cannot read or modify it. You run the server, so it stays wherever "
            + "you deploy it."
    ),
    QA(
        q="Does it connect to GitHub?",
        a="You can attach an issue link and a PR link to any daily-log entry, and "
            + "keep a list of the repos your team uses. There is no API sync yet. "
            + "Nothing reads or writes GitHub on your behalf."
    ),
    QA(
        q="Is there a Slack or Teams app?",
        a="No. standup is a web app today; there is no chat integration and no "
            + "mobile app."
    ),
    QA(
        q="What happened to the spreadsheet we used before?",
        a="This replaced it. The board covers the to-do sheet, the daily log "
            + "covers the activity sheet, and projects replaced the hardcoded team "
            + "column, but the app does not import the old file, so you start "
            + "clean."
    )
];

def:pub Faq() -> JsxElement {
    <section id="faq" className="mx-auto max-w-[840px] px-7 pt-24">
        <h2 className="font-display text-[clamp(1.8rem,4vw,2.4rem)] font-bold leading-tight tracking-[-0.035em]">
            Questions worth asking first
        </h2>
        <div className="mt-8 divide-y divide-border border-y border-border">
            {for f in FAQS {
                <details key={f.q} className="group py-5">
                    <summary className="flex cursor-pointer list-none items-center justify-between gap-6 text-left">
                        <span className="font-display text-base font-bold tracking-tight">
                            {f.q}
                        </span>
                        <span
                            aria-hidden="true"
                            className="shrink-0 text-lg text-primary transition-transform group-open:rotate-45"
                        >
                            +
                        </span>
                    </summary>
                    <p className="mt-3 max-w-2xl text-sm leading-relaxed text-muted-foreground">
                        {f.a}
                    </p>
                </details>
            }}
        </div>
    </section>
}
