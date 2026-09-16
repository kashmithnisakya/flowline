"""One header for every workspace section: title, a mono count, and the
section's actions at the right (they wrap to their own line on a phone).
"""

def:pub SectionHeader(title: str, count: str = "", children: any = None) -> JsxElement {
    return
        <div className="flex min-h-8 flex-wrap items-center gap-x-2.5 gap-y-3">
            <h1 className="page-title text-xl">{title}</h1>
            {if count {
                <span key="count" className="num text-[12.5px] text-subtle">
                    {count}
                </span>
            }}
            {if children {
                <div
                    key="actions"
                    className="flex w-full flex-wrap items-center gap-2 sm:ml-auto sm:w-auto"
                >
                    {children}
                </div>
            }}
        </div>;
}
