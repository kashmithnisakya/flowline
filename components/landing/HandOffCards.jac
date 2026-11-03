"""Step 3's three samples: a review, an answer with its citation, and a proposed
change. They are pictures, so their link and buttons are inert text, never
controls that look live and do nothing.
"""

import from ..common.AiMark { AiMark }
import from ..common.StepBadge { StepIcon }

glob BTN: str = "inline-flex h-8 items-center rounded-md px-3 text-[13px] font-medium";

def:pub HandOffCards -> JsxElement {
    return
        <div
            role="group"
            aria-label="Sample AI results"
            className="grid grid-cols-[repeat(auto-fit,minmax(min(320px,100%),1fr))] items-start gap-4 text-[13.5px] leading-[1.45]"
        >
            <div className="ai-card gap-2.5 p-4">
                <div className="flex items-center gap-2 font-semibold">
                    <AiMark/>
                    Code review
                    <span
                        className="ml-auto text-[12.5px] font-normal text-text-secondary"
                    >
                        on the Review step
                    </span>
                </div>
                <p className="font-medium">Requested changes: 3 comments, 1 blocking</p>
                <p className="text-text-secondary">
                    The limiter resets on every deploy, so a restart lifts the limit. The blocking comment is on the cache key.
                </p>
                <span className="lp-link w-fit text-[12.5px]">View on GitHub</span>
            </div>
            <div className="lp-panel flex flex-col gap-2.5 p-4">
                <p
                    className="max-w-[88%] self-end rounded-[10px] bg-bg-surface px-2.5 py-1.5 text-[13px]"
                >
                    What is blocked right now, and why?
                </p>
                <p className="text-text-secondary">
                    One task. Apple Pay domain verification has waited since Nov 1 for Apple's domain file.
                </p>
                <span
                    className="lp-link inline-flex w-fit items-center gap-1.5 text-[12.5px]"
                >
                    <StepIcon color="slate" kind="blocked"/>
                    Apple Pay domain verification
                </span>
            </div>
            <div className="ai-card gap-2.5 p-4">
                <div className="flex items-center gap-2 font-semibold">
                    <AiMark/>
                    Proposed task
                </div>
                <p className="font-medium">Add backoff to the coupon lookup retry</p>
                <dl
                    className="grid grid-cols-[auto_minmax(0,1fr)] gap-x-3 gap-y-1 text-[12.5px]"
                >
                    <dt className="text-text-tertiary">Assignee</dt>
                    <dd className="font-medium">Tomas Reyes</dd>
                    <dt className="text-text-tertiary">Step</dt>
                    <dd className="font-medium">To do</dd>
                    <dt className="text-text-tertiary">Due</dt>
                    <dd className="num font-medium">Nov 13</dd>
                </dl>
                <div className="flex gap-2" aria-hidden="true">
                    <span className={BTN + " bg-primary text-primary-foreground"}>
                        Apply
                    </span>
                    <span className={BTN}>Dismiss</span>
                </div>
            </div>
        </div>;
}
