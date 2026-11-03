"""The flow line toolbar's edit-mode actions: add a step, and the menu that
renames or deletes the whole line."""

import from ..ui.button { Button }
import from ..ui.dropdown_menu {
    DropdownMenu,
    DropdownMenuTrigger,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuSeparator
}

def:pub EditActions(
    disabled: bool = False,
    onAdd: Callable[[], None] = None,
    onRename: Callable[[], None] = None,
    onWipe: Callable[[], None] = None
) -> JsxElement {
    return
        <>
            <Button
                variant="outline"
                size="sm"
                className="h-[30px]"
                disabled={disabled}
                onClick={lambda { if onAdd { onAdd(); }}}
            >
                <svg
                    width={14}
                    height={14}
                    viewBox="0 0 16 16"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={1.7}
                    strokeLinecap="round"
                    aria-hidden="true"
                >
                    <path d="M8 3v10M3 8h10"/>
                </svg>
                Add step
            </Button>
            <DropdownMenu>
                <DropdownMenuTrigger
                    asChild={False}
                    aria-label="More flow line actions"
                    className="flex size-[30px] items-center justify-center rounded-md text-text-secondary transition-colors outline-none hover:bg-bg-hover hover:text-text-primary focus-visible:ring-2 focus-visible:ring-ring"
                >
                    <svg width={16} height={16} viewBox="0 0 16 16" aria-hidden="true">
                        <circle cx={3.5} cy={8} r={1.3} fill="currentColor"/>
                        <circle cx={8} cy={8} r={1.3} fill="currentColor"/>
                        <circle cx={12.5} cy={8} r={1.3} fill="currentColor"/>
                    </svg>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end" className="w-48">
                    <DropdownMenuItem onSelect={lambda { if onRename { onRename(); }}}>
                        Rename flow line
                    </DropdownMenuItem>
                    <DropdownMenuSeparator/>
                    <DropdownMenuItem
                        variant="destructive"
                        onSelect={lambda { if onWipe { onWipe(); }}}
                    >
                        Delete flow line
                    </DropdownMenuItem>
                </DropdownMenuContent>
            </DropdownMenu>
        </>;
}
