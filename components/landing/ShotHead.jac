"""The product picture's project header and line bar, read off the sample steps."""

import from ..common.AiMark { AiMark }
import from ..common.StepBadge { StepIcon }
import from .shotData { SHOT_STEPS }

glob TAB: str = "inline-flex h-[30px] items-center rounded-md px-2.5 text-text-secondary";

def:pub ShotHead -> JsxElement {
    return
        <div className="border-b px-6 pt-3 max-sm:px-4">
            <div className="flex items-center gap-5">
                <span
                    className="flex items-center gap-2 text-[20px] font-semibold tracking-[-0.02em] whitespace-nowrap"
                >
                    <span className="size-2.5 shrink-0 rounded-[3px] bg-project-1"/>
                    Checkout rewrite
                </span>
                <span className="flex gap-0.5 max-sm:hidden">
                    <span
                        className="inline-flex h-[30px] items-center rounded-md bg-bg-selected px-2.5 font-medium"
                    >
                        Board
                    </span>
                    <span className={TAB}>Flow line</span>
                    <span className={TAB}>Roadmap</span>
                </span>
                <span className="ml-auto flex items-center gap-3">
                    <span className="meta whitespace-nowrap max-sm:hidden">
                        GitHub synced 4 min ago
                    </span>
                    <span
                        className="inline-flex h-8 items-center gap-1.5 rounded-md bg-primary px-3 text-[13px] font-medium whitespace-nowrap text-primary-foreground"
                    >
                        New task
                        <span className="kbd kbd-on-accent">N</span>
                    </span>
                </span>
            </div>
            <div className="line-bar overflow-hidden py-2.5">
                {for s in SHOT_STEPS {
                    <div key={s.name} className="line-step">
                        <span
                            className="flex h-[30px] items-center gap-1.5 px-2 font-medium whitespace-nowrap"
                        >
                            <StepIcon color={s.color} kind={s.kind}/>
                            {s.name}
                            <span
                                className="num text-[12px] font-normal text-text-tertiary"
                            >
                                {str(s.count)}
                            </span>
                            {if s.ai {
                                <AiMark key="ai" running={True}/>
                            }}
                        </span>
                    </div>
                }}
            </div>
        </div>;
}
