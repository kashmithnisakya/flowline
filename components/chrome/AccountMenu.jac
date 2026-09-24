"""The account menu: who is signed in, the theme and Sign out. The sidebar
opens it from its account card (`card`), the phone header from an avatar."""

import from ...lib.theme { THEME_CHOICES }
import from ..common.Avatar { Avatar }
import from ..common.CommandPalette { PageIcon }
import from ..ui.dropdown_menu {
    DropdownMenu,
    DropdownMenuTrigger,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuLabel,
    DropdownMenuSeparator,
    DropdownMenuRadioGroup,
    DropdownMenuRadioItem
}

def:pub AccountMenu(
    orgName: str,
    account: str,
    themeChoice: str,
    onTheme: Callable[[str], None],
    onSignOut: Callable[[], None],
    card: bool = False
) -> JsxElement {
    name = orgName or "Your workspace";
    return
        <DropdownMenu>
            <DropdownMenuTrigger asChild={True}>
                {if card {
                    <button
                        key="card"
                        type="button"
                        aria-label="Account menu"
                        className="flex w-full items-center gap-2.5 rounded-xl bg-card p-2.5 text-left shadow-xs ring-1 ring-sidebar-border transition-colors hover:bg-accent"
                    >
                        <Avatar name={name} size="sm"/>
                        <span className="flex min-w-0 flex-1 flex-col">
                            <span className="truncate text-[13px] font-medium">
                                {name}
                            </span>
                            <span className="truncate text-xs text-muted-foreground">
                                {account}
                            </span>
                        </span>
                        <PageIcon name="more" className="text-subtle"/>
                    </button>
                } else {
                    <button
                        key="avatar"
                        type="button"
                        aria-label="Account menu"
                        className="inline-flex size-10 shrink-0 items-center justify-center rounded-full hover:bg-accent"
                    >
                        <Avatar name={name} size="sm"/>
                    </button>
                } }
            </DropdownMenuTrigger>
            <DropdownMenuContent
                align="end"
                side={"top" if card else "bottom"}
                sideOffset={6}
                className="w-60"
            >
                <DropdownMenuLabel className="flex flex-col gap-0.5 px-2 py-1.5">
                    <span className="truncate text-sm font-semibold">{name}</span>
                    <span
                        className="truncate text-xs font-normal text-muted-foreground"
                    >
                        {account}
                    </span>
                </DropdownMenuLabel>
                <DropdownMenuSeparator/>
                <DropdownMenuLabel
                    className="px-2 pt-1.5 pb-1 text-xs font-medium text-muted-foreground"
                >
                    Theme
                </DropdownMenuLabel>
                <DropdownMenuRadioGroup value={themeChoice} onValueChange={onTheme}>
                    {for choice in THEME_CHOICES {
                        <DropdownMenuRadioItem
                            key={choice[0]}
                            value={choice[0]}
                            className="px-2 py-1.5"
                        >
                            {choice[1]}
                        </DropdownMenuRadioItem>
                    }}
                </DropdownMenuRadioGroup>
                <DropdownMenuSeparator/>
                <DropdownMenuItem
                    className="gap-2 px-2 py-1.5"
                    onSelect={lambda { onSignOut(); }}
                >
                    <PageIcon name="signout" className="text-muted-foreground"/>
                    Sign out
                </DropdownMenuItem>
            </DropdownMenuContent>
        </DropdownMenu>;
}
