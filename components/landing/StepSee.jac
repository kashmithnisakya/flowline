"""Step 5: counted from the board. The panel is a sample of the Overview's queue
of what needs someone now."""

import from ..common.StepBadge { StepIcon }
import from .Spine { SpineStep, StepCopy }

def:pub StepSee -> JsxElement {
    return
        <SpineStep anchor="see">
            <div className="lp-step-grid">
                <StepCopy
                    label="Step 5, see"
                    body="The Overview shows what needs someone now and how the week went. The Roadmap lays dated tasks across twelve weeks. Neither asks anyone to fill anything in."
                >
                    Counted from the board, not typed in.
                </StepCopy>
                <div className="lp-panel text-[13.5px]">
                    <div
                        className="flex min-h-11 items-center border-b border-border-subtle px-4 text-[14px] font-semibold"
                    >
                        Needs someone now
                    </div>
                    <div className="lp-row">
                        <StepIcon color="indigo" kind="active"/>
                        <span className="min-w-0 flex-1">
                            Tax calculation for EU orders
                        </span>
                        <span className="num text-[12px] text-danger">Oct 30</span>
                    </div>
                    <div className="lp-row">
                        <StepIcon color="slate" kind="blocked"/>
                        <span className="min-w-0 flex-1">
                            Apple Pay domain verification
                        </span>
                        <span className="meta">Waiting</span>
                    </div>
                    <div className="lp-row">
                        <StepIcon color="rose" kind="handoff"/>
                        <span className="min-w-0 flex-1">
                            Move cart totals to the server
                        </span>
                        <span className="meta">In review</span>
                    </div>
                </div>
            </div>
        </SpineStep>;
}
