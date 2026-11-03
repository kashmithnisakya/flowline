"""Step 3: hand a step to AI, in a full-bleed band where the spine turns dashed
teal. `dark` re-scopes every token, so the band sets its own ground and text.
Ask is not behind the AI switch and a review can send a task back, so each
fact below names which of the two it is about.
"""

import from .HandOffCards { HandOffCards }
import from .Spine { SpineStep, StepCopy }

def:pub StepHandOff -> JsxElement {
    return
        <div className="dark border-y bg-bg-sidebar text-foreground">
            <div className="lp-wrap">
                <SpineStep anchor="ai" tone="lp-step-ai">
                    <div className="mb-10 max-w-[760px]">
                        <StepCopy
                            label="Step 3, hand off"
                            body="Give a role an AI responsibility and it runs when a task lands on that role's step. Ask reads the workspace and answers with the tasks it used. A change Ask proposes is drawn dashed until you apply it."
                        >
                            Hand a step to AI.
                            <br/>
                            Keep the decision.
                        </StepCopy>
                    </div>
                    <HandOffCards/>
                    <ul className="lp-facts mt-8 gap-x-8 gap-y-2.5 text-[14px]">
                        <li>Responsibilities stay off until you turn them on</li>
                        <li>
                            A review sends a pull request's changes, never the whole repository
                        </li>
                        <li>Ask changes nothing until you press Apply</li>
                        <li>Runs on the model your server is set up with</li>
                    </ul>
                </SpineStep>
            </div>
        </div>;
}
