"""An assignment cell: the current picks as plain text, a checkbox menu to
change them. Toggling several is one save: the menu commits when it closes,
and the caller offers the undo. Values the menu does not list (an archived
project someone is still on) ride along untouched.
"""

import from ..ui.dropdown_menu {
    DropdownMenu,
    DropdownMenuTrigger,
    DropdownMenuContent,
    DropdownMenuCheckboxItem,
    DropdownMenuItem,
    DropdownMenuSeparator
}
import from ..workspace.icons { IconChevron, IconCheck }

# Same members, order ignored: a menu that only reordered has nothing to save.
def sameSet(a: list[str], b: list[str]) -> bool {
    if len(a) != len(b) {
        return False;
    }
    for x in a {
        if x not in b {
            return False;
        }
    }
    return True;
}

def:pub AssignMenu(
    label: str,
    values: list[str],
    names: list[str],
    selected: list[str],
    emptyText: str,
    onCommit: Callable[[list[str]], any],
    footerLabel: str = "",
    onFooter: Callable[[], None] = None,
    noneText: str = "Nothing to pick yet",
    className: str = ""
) -> JsxElement {
    has open: bool = False,
        draft: list[str] = [],
        # The draft stays on screen while the save is in flight, so the cell
        # never flashes back to the old value between close and answer.
        pending: bool = False;

    async def change(next: bool) -> None {
        if next {
            draft = [v for v in selected];
            open = True;
            return;
        }
        open = False;
        wanted = [v for v in draft];
        if sameSet(wanted, selected) {
            return;
        }
        pending = True;
        await onCommit(wanted);
        pending = False;
    }

    def toggle(value: str) {
        if value in draft {
            draft = [
                v
                for v in draft
                if v != value
            ];
        } else {
            draft = draft + [value];
        }
    }

    shown = draft if (open or pending) else selected;
    picked: list[str] = [];
    for (i, v) in enumerate(values) {
        if v in shown {
            picked.append(names[i]);
        }
    }
    text = ", ".join(picked);
    return
        <DropdownMenu open={open} onOpenChange={change}>
            <DropdownMenuTrigger asChild={True}>
                <button
                    type="button"
                    aria-label={label}
                    className={"relative -left-1.5 inline-flex min-w-0 max-w-full items-center gap-1 rounded-md border border-transparent px-1.5 py-1 text-left text-[13.5px] transition-colors duration-150 hover:border-input hover:bg-card aria-expanded:border-input aria-expanded:bg-card "
                        + className}
                >
                    <span
                        className={"truncate "
                            + ("" if text else "text-muted-foreground")}
                    >
                        {text or emptyText}
                    </span>
                    <IconChevron size={12} className="shrink-0 text-subtle"/>
                </button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="start" className="w-56 p-1.5">
                {if len(values) == 0 {
                    <p key="none" className="px-2 py-1.5 text-[13px] text-subtle">
                        {noneText}
                    </p>
                }}
                {for (i, v) in enumerate(values) {
                    <DropdownMenuCheckboxItem
                        key={v}
                        checked={v in draft}
                        className="gap-2 py-1.5 pr-2 pl-2 text-[13px] [&_[data-slot=dropdown-menu-checkbox-item-indicator]]:hidden"
                        onSelect={lambda (e: Event) {
                            e.preventDefault();
                            toggle(v);
                        }}
                    >
                        <span
                            className={"flex size-4 shrink-0 items-center justify-center rounded-xs border "
                                + (
                                    "border-primary bg-primary text-primary-foreground"
                                        if v in draft
                                        else "border-input"
                                )}
                            aria-hidden="true"
                        >
                            {if v in draft {
                                <IconCheck key="tick" size={12}/>
                            }}
                        </span>
                        <span className="truncate">{names[i]}</span>
                    </DropdownMenuCheckboxItem>
                }}
                {if footerLabel {
                    <DropdownMenuSeparator key="sep"/>
                }}
                {if footerLabel {
                    <DropdownMenuItem
                        key="foot"
                        className="px-2 py-1.5 text-[13px] text-primary"
                        onSelect={lambda (e: Event) {
                            e.preventDefault();
                            change(False);
                            if onFooter {
                                onFooter();
                            }
                        }}
                    >
                        {footerLabel}
                    </DropdownMenuItem>
                }}
            </DropdownMenuContent>
        </DropdownMenu>;
}
