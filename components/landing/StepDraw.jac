"""Step 1: draw the line. The panel is the Simple template as a small diagram,
with Review's way back to Doing, then the two templates a workspace starts from.
"""

import from ..common.StepBadge { StepIcon }
import from .Spine { SpineStep, StepCopy }

glob STEPS: list[list[str]] = [
         ["To do", "start", "sky"],
         ["Doing", "active", "indigo"],
         ["Review", "handoff", "rose"],
         ["Done", "done", "emerald"]
     ],
     CHIP: str = "inline-flex min-h-[26px] items-center rounded-md border px-2 py-0.5 text-[12.5px]";

def:pub StepDraw -> JsxElement {
    return
        <SpineStep anchor="draw" tone="lp-step-first">
            <div className="lp-step-grid">
                <StepCopy
                    label="Step 1, draw"
                    body="Name the steps, connect them, loops included. Start from Simple or Software team, or draw your own. The board's groups are those steps, in order, so the two can never disagree."
                >
                    Draw the line your team already walks.
                </StepCopy>
                <div className="lp-panel lp-draw px-4 pt-7 pb-6 sm:px-6">
                    <ol className="lp-mini">
                        {for s in STEPS {
                            <li key={s[0]} className="lp-mini-node">
                                <StepIcon color={s[2]} kind={s[1]}/>
                                {s[0]}
                            </li>
                        }}
                    </ol>
                    <div className="lp-mini-loop" aria-hidden="true"/>
                    <p className="meta pt-1.5 text-center">
                        <span className="sr-only">
                            {"Review can send work back to Doing: "}
                        </span>
                        Changes requested
                    </p>
                    <div
                        className="mt-5 flex flex-wrap gap-2 border-t border-border-subtle pt-4"
                    >
                        <span className={CHIP + " border-foreground font-medium"}>
                            Simple, four steps
                        </span>
                        <span className={CHIP}>
                            Software team, seven steps and four roles
                        </span>
                    </div>
                </div>
            </div>
        </SpineStep>;
}
