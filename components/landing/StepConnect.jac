"""Step 4: GitHub moves the work. The panel shows a repository's rules with a
sample setting each. A rule's switch is a picture of the state, not a control."""

import from .Spine { SpineStep, StepCopy }

glob RULES: list[list[str]] = [
         ["A label is added", "Moves the task along the arrow you set", "on"],
         ["A pull request is merged", "Moves the task to Done", "on"],
         ["A reviewer requests changes", "Sends the task back to Doing", "on"],
         ["A task reaches Done", "Closes its GitHub issue", ""]
     ];

def:pub StepConnect -> JsxElement {
    return
        <SpineStep anchor="github">
            <div className="lp-step-grid">
                <StepCopy
                    label="Step 4, connect"
                    body="Install the GitHub App on the repositories you pick and their issues become tasks. Then choose, per repository and per arrow, what moves what. Everything stays off until you turn it on."
                >
                    GitHub moves the work when you let it.
                </StepCopy>
                <div className="lp-panel text-[13.5px]">
                    {for r in RULES {
                        <div key={r[0]} className="lp-row">
                            <span className="min-w-0 flex-1">
                                {r[0]}
                                <span className="meta block">{r[1]}</span>
                            </span>
                            <span
                                role="img"
                                aria-label={"On" if r[2] else "Off"}
                                className={"relative h-[18px] w-8 shrink-0 rounded-full "
                                    + ("bg-primary" if r[2] else "bg-border-strong")}
                            >
                                <span
                                    className={"absolute top-0.5 size-3.5 rounded-full bg-white "
                                        + ("left-4" if r[2] else "left-0.5")}
                                />
                            </span>
                        </div>
                    }}
                </div>
            </div>
        </SpineStep>;
}
