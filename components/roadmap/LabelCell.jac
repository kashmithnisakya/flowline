"""The roadmap's sticky task column: narrow on a phone so time still shows,
wider from `sm`. LABEL_OFFSET starts anything that must clear it."""

glob:pub LABEL_OFFSET: str = "left-36 sm:left-64";

def:pub LabelCell(className: str = "", children: any = None) -> JsxElement {
    return
        <span
            className={"sticky left-0 z-20 w-36 shrink-0 bg-background px-3 sm:w-64 "
                + className}
            data-roadmap-label="true"
        >
            {children}
        </span>;
}
