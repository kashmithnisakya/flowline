"""One step of the product picture: its header bar, then its rows or the line
that stands for a folded Done. A phone's row keeps the title and the due date."""

import from ..common.AiMark { AiMark }
import from ..common.Avatar { AvatarStack }
import from ..common.StepBadge { StepIcon }
import from .shotData { ShotRow, ShotStep }

def Row(row: ShotRow, step: ShotStep) -> JsxElement {
    return
        <div className="lp-shot-row min-h-[38px] border-b border-border-subtle">
            <StepIcon color={step.color} kind={step.kind}/>
            <span className="flex min-w-0 items-center gap-2">
                <span className="truncate font-medium">{row.title}</span>
                {if row.high {
                    <svg
                        key="high"
                        className="size-[13px] shrink-0 text-danger"
                        viewBox="0 0 16 16"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth={1.5}
                        strokeLinecap="round"
                        strokeLinejoin="round"
                    >
                        <path d="M4 14V2.5M4 3h8l-1.8 3L12 9H4"/>
                    </svg>
                }}
                {if row.check {
                    <span
                        key="check"
                        className="num shrink-0 text-[12px] text-text-tertiary"
                    >
                        {row.check}
                    </span>
                }}
                {if row.note {
                    <span key="note" className="meta shrink-0 max-sm:hidden">
                        {row.note}
                    </span>
                }}
            </span>
            <span className="flex max-sm:hidden">
                <AvatarStack names={row.who}/>
            </span>
            <span className={"num text-[12px]" + (" text-danger" if row.late else "")}>
                {row.due}
            </span>
            <span className="num text-[12px] text-text-secondary max-sm:hidden">
                {row.gh}
            </span>
            <span className="flex max-sm:hidden">
                {if row.ai {
                    <span
                        key="ai"
                        className={"ai-chip"
                            + (" ai-chip-settled" if row.settled else "")}
                    >
                        <AiMark running={row.running}/>
                        {row.ai}
                    </span>
                }}
            </span>
        </div>;
}

def:pub ShotGroup(step: ShotStep) -> JsxElement {
    return
        <div>
            <div
                className="flex h-9 items-center gap-2 border-b border-border-subtle bg-bg-surface px-6 font-semibold whitespace-nowrap max-sm:px-4"
            >
                <StepIcon color={step.color} kind={step.kind}/>
                {step.name}
                <span className="num text-[12px] font-normal text-text-tertiary">
                    {str(step.count)}
                </span>
                <span className="meta font-normal">{step.owner}</span>
                {if step.ai {
                    <span key="ai" className="ai-chip font-normal">
                        <AiMark/>
                        Code review
                    </span>
                }}
            </div>
            {for r in step.rows {
                <Row key={r.title} row={r} step={step}/>
            }}
            {if step.folded {
                <div
                    key="folded"
                    className="lp-shot-row min-h-[38px] text-text-tertiary"
                >
                    <span/>
                    <span>{step.folded}</span>
                </div>
            }}
        </div>;
}
