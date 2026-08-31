"""Proof without testimonials: four true, checkable facts in a quiet strip
above the footer. The repo bans invented quotes and metrics, so the page
sells on what a developer can verify: the source, the hosting, the account
model and the isolation.
"""

def:pub ProofStrip -> JsxElement {
    return
        <section className="mx-auto max-w-[1180px] px-7 pt-24">
            <span
                className="text-xs font-semibold uppercase tracking-widest text-primary"
            >
                Proof
            </span>
            <h2
                className="font-display mt-3 max-w-2xl text-[clamp(1.5rem,3vw,2rem)] font-bold leading-tight tracking-[-0.035em]"
            >
                No testimonials. Just things you can check.
            </h2>
            <div className="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                <div
                    className="flex h-full flex-col gap-2.5 rounded-xl border bg-card p-5"
                >
                    <svg
                        width={20}
                        height={20}
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth={1.7}
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        className="text-primary"
                        aria-hidden="true"
                    >
                        <path d="M8 6 3 12l5 6"/>
                        <path d="m16 6 5 6-5 6"/>
                    </svg>
                    <h3 className="font-display text-base font-bold tracking-tight">
                        Open source
                    </h3>
                    <p className="text-xs leading-relaxed text-muted-foreground">
                        Read every line before you trust it with your team's work.
                    </p>
                    <a
                        href="https://github.com/kashmithnisakya/flowline"
                        target="_blank"
                        rel="noopener noreferrer"
                        className="mt-auto pt-1 text-xs font-semibold text-primary underline-offset-2 hover:underline"
                    >
                        View the source →
                    </a>
                </div>
                <div
                    className="flex h-full flex-col gap-2.5 rounded-xl border bg-card p-5"
                >
                    <svg
                        width={20}
                        height={20}
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth={1.7}
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        className="text-primary"
                        aria-hidden="true"
                    >
                        <rect x={4} y={4} width={16} height={7} rx={2}/>
                        <rect x={4} y={13} width={16} height={7} rx={2}/>
                        <path d="M8 7.5h.01"/>
                        <path d="M8 16.5h.01"/>
                    </svg>
                    <h3 className="font-display text-base font-bold tracking-tight">
                        Self-hosted
                    </h3>
                    <p className="text-xs leading-relaxed text-muted-foreground">
                        You run the server, so your data lives wherever you deploy it.
                    </p>
                </div>
                <div
                    className="flex h-full flex-col gap-2.5 rounded-xl border bg-card p-5"
                >
                    <svg
                        width={20}
                        height={20}
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth={1.7}
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        className="text-primary"
                        aria-hidden="true"
                    >
                        <circle cx={9} cy={8} r={3.5}/>
                        <path d="M3.5 20c.5-3.5 2.8-5.5 5.5-5.5s5 2 5.5 5.5"/>
                        <path d="M17 8h5"/>
                        <path d="M19.5 5.5v5"/>
                    </svg>
                    <h3 className="font-display text-base font-bold tracking-tight">
                        No teammate accounts
                    </h3>
                    <p className="text-xs leading-relaxed text-muted-foreground">
                        One sign-in for the whole roster. Nobody gets a password to forget.
                    </p>
                </div>
                <div
                    className="flex h-full flex-col gap-2.5 rounded-xl border bg-card p-5"
                >
                    <svg
                        width={20}
                        height={20}
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth={1.7}
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        className="text-primary"
                        aria-hidden="true"
                    >
                        <rect x={5} y={10} width={14} height={10} rx={2}/>
                        <path d="M8 10V7a4 4 0 0 1 8 0v3"/>
                    </svg>
                    <h3 className="font-display text-base font-bold tracking-tight">
                        Isolated by design
                    </h3>
                    <p className="text-xs leading-relaxed text-muted-foreground">
                        Every workspace is its own private graph. Structurally, not by policy.
                    </p>
                </div>
            </div>
        </section>;
}
