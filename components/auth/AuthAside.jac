"""The brand panel beside the auth card.

Mirrors the design's split layout. The design mock filled this space with a
customer quote and usage metrics; those were placeholders, so this states
what the product actually does instead of inventing social proof.
"""

def:pub AuthAside() -> JsxElement {
    <div className="hidden min-h-[560px] flex-col justify-between gap-12 rounded-3xl bg-foreground p-10 text-background lg:flex">
        <img
            src="/static/brand/logo-full-dark.svg"
            alt="standup"
            width={168}
            height={45}
        />
        <div className="space-y-6">
            <p className="font-display text-3xl font-bold leading-tight tracking-tight">
                Everything a standup does.
                <br />
                None of the 9:45.
            </p>
            <ul className="space-y-3 text-sm text-background/70">
                <li className="flex gap-3">
                    <span aria-hidden="true" className="text-primary">•</span>
                    A kanban board per project, so status is a glance instead of a meeting.
                </li>
                <li className="flex gap-3">
                    <span aria-hidden="true" className="text-primary">•</span>
                    A written daily log that becomes the archive nobody has to remember.
                </li>
                <li className="flex gap-3">
                    <span aria-hidden="true" className="text-primary">•</span>
                    Your own private workspace: one account, one organization.
                </li>
            </ul>
        </div>
        <p className="text-xs text-background/50">
            Built with Jac · your data stays in your workspace
        </p>
    </div>
}
