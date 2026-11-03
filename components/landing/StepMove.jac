"""Step 2: every move writes itself down. The panel is one sample task's travel,
newest first; a line AI wrote gets the dashed ring."""

import from .Spine { SpineStep, StepCopy }

glob TRAVEL: list[list[str]] = [
         ["Moved to Review", " by Tomas Reyes", "Nov 3", ""],
         ["Code review requested changes", ", back to Doing", "Oct 30", "lp-travel-ai"],
         ["Moved to Review", " by Tomas Reyes", "Oct 30", ""],
         ["Moved to Doing", " by Tomas Reyes", "Oct 27", ""],
         ["Imported", " from GitHub issue #422", "Oct 26", ""]
     ];

def:pub StepMove -> JsxElement {
    return
        <SpineStep anchor="move">
            <div className="lp-step-grid">
                <StepCopy
                    label="Step 2, move"
                    body="Drag a task to its next step and the line, the roadmap and the overview all follow. Each move lands in the task's travel log with who and when, so the update is already written before anyone asks for it."
                >
                    Every move writes itself down.
                </StepCopy>
                <div className="lp-panel px-6 py-5">
                    <p className="mb-0.5 text-[14px] font-semibold">
                        Rate limit the coupon lookup
                    </p>
                    <p className="meta mb-4">Travel so far</p>
                    <ul className="lp-travel">
                        {for (i, e) in enumerate(TRAVEL) {
                            <li key={str(i)} className={e[3]}>
                                <span className="min-w-0 flex-1">
                                    <span className="font-medium">{e[0]}</span>
                                    {e[1]}
                                </span>
                                <span
                                    className="num shrink-0 text-[12px] text-text-tertiary"
                                >
                                    {e[2]}
                                </span>
                            </li>
                        }}
                    </ul>
                </div>
            </div>
        </SpineStep>;
}
