"""The task sheet's property rows: a label and a value that reads as plain text
until hovered, plus the ghost control styles every row shares."""

glob:pub GHOST_SELECT: str = "h-8 w-full min-w-0 justify-between border-transparent bg-transparent px-2 font-normal shadow-none hover:bg-accent data-[state=open]:bg-accent [&>svg:last-child]:opacity-0 hover:[&>svg:last-child]:opacity-100 data-[state=open]:[&>svg:last-child]:opacity-100",
     GHOST_INPUT: str = "h-8 border-transparent bg-transparent px-2 hover:bg-bg-hover md:text-[13px] text-[13px] [&::-webkit-calendar-picker-indicator]:opacity-0 hover:[&::-webkit-calendar-picker-indicator]:opacity-100 focus:[&::-webkit-calendar-picker-indicator]:opacity-100",
     GHOST_DATE: str = "h-8! w-full justify-start border-transparent! bg-transparent! px-2! text-[13px]! font-normal! hover:bg-bg-hover!";

def:pub PropRow(label: str, children: any = None, top: bool = False) -> JsxElement {
    return
        <div
            className={"grid min-h-8 grid-cols-[6rem_minmax(0,1fr)] gap-x-2 "
                + ("items-start" if top else "items-center")}
        >
            <dt
                className={"text-[13px] text-text-tertiary "
                    + ("pt-1.5" if top else "")}
            >
                {label}
            </dt>
            <dd className="m-0 min-w-0">{children}</dd>
        </div>;
}
