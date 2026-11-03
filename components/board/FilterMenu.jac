"""The board's one Filter menu: a submenu per facet showing its current value,
and Clear. Each facet is [label, value, allValue, options, onChange]."""

import from ..ui.dropdown_menu {
    DropdownMenu,
    DropdownMenuTrigger,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuRadioGroup,
    DropdownMenuRadioItem,
    DropdownMenuSeparator,
    DropdownMenuSub,
    DropdownMenuSubTrigger,
    DropdownMenuSubContent
}

# The label a value shows under, from an options list of [value, label].
def:pub optionLabel(options: list[list[str]], value: str) -> str {
    for o in options {
        if o[0] == value {
            return o[1];
        }
    }
    return value;
}

def:pub FilterMenu(
    facets: list[dict[str, any]],
    picked: int,
    anything: bool,
    onClear: Callable[[], None]
) -> JsxElement {
    return
        <DropdownMenu>
            <DropdownMenuTrigger
                className="toolbar-filter"
                data-active={"true" if picked > 0 else "false"}
            >
                <svg
                    width={14}
                    height={14}
                    viewBox="0 0 16 16"
                    aria-hidden="true"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={1.5}
                    strokeLinecap="round"
                >
                    <path d="M2.5 4.5h11M4.5 8h7M6.5 11.5h3"/>
                </svg>
                Filter
                {if picked > 0 {
                    <span key="n" className="num text-text-tertiary">
                        {str(picked)}
                    </span>
                }}
            </DropdownMenuTrigger>
            <DropdownMenuContent align="start" collisionPadding={16} className="w-60">
                {for f in facets {
                    <DropdownMenuSub key={f["label"]}>
                        <DropdownMenuSubTrigger>
                            <span>{f["label"]}</span>
                            <span
                                className="ml-auto max-w-28 truncate pl-3 text-[12px] text-text-tertiary"
                            >
                                {optionLabel(f["options"], f["value"])}
                            </span>
                        </DropdownMenuSubTrigger>
                        <DropdownMenuSubContent
                            className="max-h-80 w-56 overflow-y-auto"
                        >
                            <DropdownMenuRadioGroup
                                value={f["value"]}
                                onValueChange={f["onChange"]}
                            >
                                {for o in f["options"] {
                                    <DropdownMenuRadioItem key={o[0]} value={o[0]}>
                                        <span className="truncate">{o[1]}</span>
                                    </DropdownMenuRadioItem>
                                }}
                            </DropdownMenuRadioGroup>
                        </DropdownMenuSubContent>
                    </DropdownMenuSub>
                }}
                {if anything {
                    <DropdownMenuSeparator key="sep"/>
                }}
                {if anything {
                    <DropdownMenuItem key="clear" onClick={lambda { onClear(); }}>
                        Clear filters
                    </DropdownMenuItem>
                }}
            </DropdownMenuContent>
        </DropdownMenu>;
}
