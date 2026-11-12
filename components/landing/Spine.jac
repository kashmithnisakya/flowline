"""The landing page's spine: one vertical line through its numbered sections. A
section draws its own stretch of line and its node, so the line stays one line
across a full-bleed band. `tone` is lp-step-first, lp-step-ai or lp-step-end.
"""

def:pub SpineStep(anchor: str, tone: str = "", children: any = None) -> JsxElement {
    return
        <section id={anchor} className={"lp-step " + tone}>
            <span className="lp-node" aria-hidden="true"/>
            {children}
        </section>;
}

# A section's label, heading (its children) and body sentence.
def:pub StepCopy(label: str, body: str = "", children: any = None) -> JsxElement {
    return
        <div className="flex flex-col gap-3.5">
            <p className="lp-eyebrow">{label}</p>
            <h2 className="lp-h2">{children}</h2>
            {if body {
                <p key="body" className="lp-body">{body}</p>
            }}
        </div>;
}
