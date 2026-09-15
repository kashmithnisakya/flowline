"""The row overflow menu: an edit action, then the destructive one after a
separator. Non-modal, so a dialog opened from an item never inherits the
menu's pointer lock on the page.
"""

import from ..ui.button { Button }
import from ..ui.dropdown_menu {
    DropdownMenu,
    DropdownMenuTrigger,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuSeparator
}
import from .icons { IconMore }

def:pub RowActions(
    label: str,
    onEdit: Callable[[], None],
    onDanger: Callable[[], None],
    editLabel: str = "Edit",
    dangerLabel: str = "Archive"
) -> JsxElement {
    return
        <DropdownMenu modal={False}>
            <DropdownMenuTrigger asChild={True}>
                <Button
                    variant="ghost"
                    size="icon-sm"
                    aria-label={label}
                    className="text-subtle hover:text-foreground aria-expanded:text-foreground"
                >
                    <IconMore/>
                </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-44 p-1.5">
                <DropdownMenuItem
                    className="px-2 py-1.5 text-[13px]"
                    onSelect={lambda { onEdit(); }}
                >
                    {editLabel}
                </DropdownMenuItem>
                <DropdownMenuSeparator/>
                <DropdownMenuItem
                    variant="destructive"
                    className="px-2 py-1.5 text-[13px]"
                    onSelect={lambda { onDanger(); }}
                >
                    {dangerLabel + "…"}
                </DropdownMenuItem>
            </DropdownMenuContent>
        </DropdownMenu>;
}
