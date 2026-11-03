"""The board's Display menu: the Done window, empty groups, folding every group
and the column widths."""

import from ..ui.dropdown_menu {
    DropdownMenu,
    DropdownMenuTrigger,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuCheckboxItem,
    DropdownMenuSeparator
}
import from ..common.Chevron { Chevron }
import from .columnWidths { resetWidths }

def:pub DisplayMenu(
    hideDone: bool,
    hideEmpty: bool,
    doneLabel: str,
    onHideDone: Callable[[], None],
    onHideEmpty: Callable[[], None],
    onExpandAll: Callable[[], None],
    onCollapseAll: Callable[[], None]
) -> JsxElement {
    return
        <DropdownMenu>
            <DropdownMenuTrigger className="toolbar-filter" data-active="false">
                Display
                <Chevron/>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" collisionPadding={16} className="w-56">
                <DropdownMenuCheckboxItem
                    checked={not hideDone}
                    onCheckedChange={lambda { onHideDone(); }}
                >
                    {doneLabel}
                </DropdownMenuCheckboxItem>
                <DropdownMenuCheckboxItem
                    checked={hideEmpty}
                    onCheckedChange={lambda { onHideEmpty(); }}
                >
                    Hide empty groups
                </DropdownMenuCheckboxItem>
                <DropdownMenuSeparator/>
                <DropdownMenuItem onClick={lambda { onExpandAll(); }}>
                    Expand all groups
                </DropdownMenuItem>
                <DropdownMenuItem onClick={lambda { onCollapseAll(); }}>
                    Collapse all groups
                </DropdownMenuItem>
                <DropdownMenuItem onClick={lambda { resetWidths(); }}>
                    Reset column widths
                </DropdownMenuItem>
            </DropdownMenuContent>
        </DropdownMenu>;
}
