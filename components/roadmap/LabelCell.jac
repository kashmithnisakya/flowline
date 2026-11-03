"""The roadmap's sticky task column: narrow on a phone so time still shows,
280px from `sm`. LABEL_OFFSET starts anything that must clear it."""

glob:pub LABEL_OFFSET: str = "left-36 sm:left-[280px]";

def:pub LabelCell(className: str = "", children: any = None) -> JsxElement {
    return
        <span
            className={"sticky left-0 z-20 w-36 shrink-0 border-r bg-card px-3 sm:w-[280px] "
                + className}
            data-roadmap-label="true"
        >
            {children}
        </span>;
}
