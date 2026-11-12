"""The key row's Roles popover: the org's roles and who holds them. `roles` rows
are {id, name, dot, holders, none}, built by the page from the roster."""

import from ..ui.popover { Popover, PopoverTrigger, PopoverContent }

def:pub RolesPopover(roles: list[dict[str, any]]) -> JsxElement {
    return
        <Popover>
            <PopoverTrigger
                className="ml-auto inline-flex h-6 items-center gap-1.5 rounded-sm px-1.5 text-[12.5px] text-text-secondary transition-colors hover:bg-bg-hover hover:text-text-primary focus-visible:outline-2 focus-visible:outline-ring"
            >
                Roles
                <span className="num text-xs">{str(len(roles))}</span>
            </PopoverTrigger>
            <PopoverContent
                align="end"
                collisionPadding={16}
                className="w-72 gap-2.5 p-3"
            >
                <div className="flex items-baseline justify-between gap-2">
                    <h2 className="text-sm font-semibold">Roles</h2>
                    <a
                        href="/workspace?tab=roles"
                        className="text-xs text-text-secondary underline-offset-2 hover:text-text-primary hover:underline"
                    >
                        Manage roles
                    </a>
                </div>
                {if len(roles) == 0 {
                    <p key="none" className="text-[13px] text-text-secondary">
                        No roles yet. A role says who holds a step.
                    </p>
                } else {
                    <ul key="roles" className="flex flex-col gap-2">
                        {for rl in roles {
                            <li key={rl["id"]} className="flex min-w-0 flex-col">
                                <span
                                    className="flex min-w-0 items-center gap-1.5 text-[13px] font-medium"
                                >
                                    <span
                                        className={"step-swatch " + rl["dot"]}
                                        aria-hidden="true"
                                    />
                                    <span className="truncate">{rl["name"]}</span>
                                </span>
                                <span
                                    className={"pl-4 text-xs "
                                        + (
                                            "text-warning"
                                                if rl["none"]
                                                else "text-text-secondary"
                                        )}
                                >
                                    {rl["holders"]}
                                </span>
                            </li>
                        }}
                    </ul>
                } }
            </PopoverContent>
        </Popover>;
}
