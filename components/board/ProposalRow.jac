"""A task Ask has proposed, drawn dashed in the step it would land in. Nothing is
saved: pressing Apply in Ask creates it through the ordinary walker."""

import from ..common.AiMark { AiMark }
import from ..common.Avatar { AvatarStack }
import from ...lib.dates { prettyDay }
import from .TaskCells { ROW_COLUMNS }

def:pub ProposalRow(
    title: str, assignee: str, due: str, moving: bool, onOpenAsk: Callable[[], None]
) -> JsxElement {
    return
        <button
            type="button"
            data-proposal="true"
            onClick={lambda { onOpenAsk(); }}
            className={"my-1 flex w-full flex-col gap-1 rounded-md border border-dashed border-ai bg-ai-wash py-2 pr-2 pl-2 text-left lg:grid lg:h-10 lg:items-center lg:gap-x-3 lg:py-0 "
                + ROW_COLUMNS}
        >
            <span className="flex min-w-0 items-center gap-3 lg:col-span-2">
                <span className="flex w-4 shrink-0 justify-center">
                    <AiMark/>
                </span>
                <span className="min-w-0 truncate text-[13.5px] font-medium">
                    {title}
                </span>
                <span
                    data-proposal-note="true"
                    className="shrink-0 text-[12px] text-ai"
                >
                    {"Proposed move" if moving else "Proposed by Ask"}
                </span>
            </span>
            <span className="hidden lg:flex">
                {if assignee {
                    <AvatarStack key="who" names={[assignee]}/>
                }}
            </span>
            <span className="num hidden text-[12px] text-text-secondary lg:inline">
                {prettyDay(due) if due else ""}
            </span>
            <span data-col="2" className="hidden lg:inline"/>
            <span className="hidden text-[12px] text-ai lg:inline">
                Not applied yet
            </span>
        </button>;
}
