"""The task sheet's top bar: the route through this step, Move, a menu for the
rarely used actions, and Close."""

import from ..MoveMenu { MoveMenu }
import from ...common.StepName { StepName }
import from ...common.CommandPalette { PageIcon }
import from ...ui.dropdown_menu {
    DropdownMenu,
    DropdownMenuTrigger,
    DropdownMenuContent,
    DropdownMenuItem
}
import from ...common.glyphs { Spinner }

glob ICON_BUTTON: str = "inline-flex size-7 items-center justify-center rounded-md text-muted-foreground hover:bg-accent hover:text-foreground";

def Arrow -> JsxElement {
    return
        <svg
            width={14}
            height={14}
            viewBox="0 0 16 16"
            aria-hidden="true"
            className="shrink-0 text-wire"
        >
            <path
                d="M3 8h9.5M9 4.5 12.5 8 9 11.5"
                fill="none"
                stroke="currentColor"
                strokeWidth={1.6}
                strokeLinecap="round"
                strokeLinejoin="round"
            />
        </svg>;
}

def:pub SheetHead(
    prevLabel: str,
    hereLabel: str,
    hereColor: str,
    nextLabel: str,
    moveOpen: bool,
    onMoveOpen: Callable[[bool], None],
    hereKey: str,
    columnKeys: list[str],
    columnLabels: list[str],
    colors: list[str],
    steps: list[any],
    onPick: Callable[[str], None],
    deleting: bool,
    saving: bool,
    onDelete: Callable[[], None],
    onClose: Callable[[], None]
) -> JsxElement {
    return
        <div className="flex min-h-12 shrink-0 items-center gap-2 border-b pr-3 pl-5">
            <div
                className="flex min-w-0 flex-1 items-center gap-1.5 overflow-hidden text-[12.5px] whitespace-nowrap text-muted-foreground"
            >
                {if prevLabel {
                    <span key="prev" className="min-w-0 truncate">{prevLabel}</span>
                }}
                {if prevLabel {
                    <Arrow key="prevarrow"/>
                }}
                {if hereLabel {
                    <StepName
                        key="here"
                        name={hereLabel}
                        color={hereColor}
                        className="max-w-40 shrink-0 font-semibold text-foreground"
                    />
                }}
                {if nextLabel {
                    <Arrow key="nextarrow"/>
                }}
                {if nextLabel {
                    <span key="next" className="min-w-0 truncate">{nextLabel}</span>
                }}
            </div>
            <div className="flex shrink-0 items-center gap-1">
                {if len(columnKeys) > 0 {
                    <MoveMenu
                        key="move"
                        open={moveOpen}
                        onOpenChange={onMoveOpen}
                        current={hereKey}
                        keys={columnKeys}
                        labels={columnLabels}
                        colors={colors}
                        steps={steps}
                        onPick={onPick}
                        showLabel={True}
                        align="end"
                        triggerClass="inline-flex h-7 items-center gap-1.5 rounded-md border bg-card px-2 text-[12.5px] font-semibold text-foreground hover:bg-accent focus-visible:outline-2 focus-visible:outline-ring"
                    />
                }}
                <DropdownMenu>
                    <DropdownMenuTrigger
                        aria-label="More actions"
                        className={ICON_BUTTON}
                    >
                        {if deleting {
                            <Spinner key="sp"/>
                        } else {
                            <PageIcon key="more" name="more" size={16}/>
                        } }
                    </DropdownMenuTrigger>
                    <DropdownMenuContent
                        align="end"
                        collisionPadding={16}
                        className="w-44"
                    >
                        <DropdownMenuItem
                            variant="destructive"
                            disabled={saving}
                            onClick={lambda { onDelete(); }}
                        >
                            Delete task
                        </DropdownMenuItem>
                    </DropdownMenuContent>
                </DropdownMenu>
                <button
                    type="button"
                    aria-label="Close"
                    className={ICON_BUTTON}
                    onClick={lambda { onClose(); }}
                >
                    <svg width={16} height={16} viewBox="0 0 16 16" aria-hidden="true">
                        <path
                            d="m4 4 8 8M12 4l-8 8"
                            stroke="currentColor"
                            strokeWidth={1.6}
                            strokeLinecap="round"
                        />
                    </svg>
                </button>
            </div>
        </div>;
}
