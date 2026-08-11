"""The brand panel beside the auth card.

Mirrors the design's split layout. The design mock filled this space with a
customer quote and usage metrics; those were placeholders, so this states
what the product actually does instead of inventing social proof.

The panel is deliberately INVERTED, `bg-foreground` on `text-background` ,
so it flips with the theme: ink on paper becomes paper on ink. Anything with
a fixed colour therefore needs both variants, which is why the wordmark is
two images. The bullet chips lean on `bg-background`/`text-background`,
which flip with the panel, so they hold contrast on both grounds. A single
logo here painted light ink onto the light panel and vanished.
"""

def:pub AuthAside -> JsxElement {
    return
        <div
            className="anim-fade-up relative hidden min-h-[560px] flex-col justify-between gap-12 overflow-hidden rounded-3xl bg-foreground p-10 text-background lg:flex"
        >
            <div
                aria-hidden="true"
                className="pointer-events-none absolute inset-0 bg-gradient-to-br from-primary/15 via-transparent to-primary/10"
            ></div>
            <div
                aria-hidden="true"
                className="pointer-events-none absolute -right-20 -top-20 size-64 rounded-full bg-primary/20 blur-3xl"
            ></div>
            <div
                aria-hidden="true"
                className="pointer-events-none absolute -bottom-24 -left-16 size-72 rounded-full bg-background/10 blur-3xl"
            ></div>
            <img
                src="/static/brand/logo-full-dark.svg"
                alt="standup"
                width={168}
                height={45}
                className="relative dark:hidden"
            />
            <img
                src="/static/brand/logo-full.svg"
                alt="standup"
                width={168}
                height={45}
                className="relative hidden dark:block"
            />
            <div className="relative space-y-6">
                <p
                    className="font-display text-3xl font-bold leading-tight tracking-tight"
                >
                    Everything a standup does.
                    <br/>
                    None of the 9:45.
                </p>
                <ul className="space-y-3 text-sm text-background/70">
                    <li className="flex items-start gap-3">
                        <span
                            aria-hidden="true"
                            className="mt-0.5 flex size-5 shrink-0 items-center justify-center rounded-full bg-background/15 text-background"
                        >
                            <svg
                                width={12}
                                height={12}
                                viewBox="0 0 24 24"
                                fill="none"
                                stroke="currentColor"
                                strokeWidth={2}
                                strokeLinecap="round"
                                strokeLinejoin="round"
                            >
                                <path d="M20 6 9 17l-5-5"/>
                            </svg>
                        </span>
                        A kanban board per project, so status is a glance instead of a meeting.
                    </li>
                    <li className="flex items-start gap-3">
                        <span
                            aria-hidden="true"
                            className="mt-0.5 flex size-5 shrink-0 items-center justify-center rounded-full bg-background/15 text-background"
                        >
                            <svg
                                width={12}
                                height={12}
                                viewBox="0 0 24 24"
                                fill="none"
                                stroke="currentColor"
                                strokeWidth={2}
                                strokeLinecap="round"
                                strokeLinejoin="round"
                            >
                                <path d="M20 6 9 17l-5-5"/>
                            </svg>
                        </span>
                        A written daily log that becomes the archive nobody has to remember.
                    </li>
                    <li className="flex items-start gap-3">
                        <span
                            aria-hidden="true"
                            className="mt-0.5 flex size-5 shrink-0 items-center justify-center rounded-full bg-background/15 text-background"
                        >
                            <svg
                                width={12}
                                height={12}
                                viewBox="0 0 24 24"
                                fill="none"
                                stroke="currentColor"
                                strokeWidth={2}
                                strokeLinecap="round"
                                strokeLinejoin="round"
                            >
                                <path d="M20 6 9 17l-5-5"/>
                            </svg>
                        </span>
                        Your own private workspace: one account, one organization.
                    </li>
                </ul>
            </div>
            <p className="relative text-xs text-background/50">
                Built with Jac · your data stays in your workspace
            </p>
        </div>;
}
