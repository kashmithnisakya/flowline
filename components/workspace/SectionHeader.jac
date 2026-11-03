"""A workspace panel's header: title, a count, a note, and the section's actions
at the right (they wrap to their own line on a phone).
"""

def:pub SectionHeader(
    id: str, title: str, count: str = "", note: any = None, actions: any = None
) -> JsxElement {
    return
        <div
            className="flex min-h-11 flex-wrap items-center gap-x-2.5 gap-y-2 border-b px-4 py-2"
        >
            <h2 id={id} className="section-title">{title}</h2>
            {if count {
                <span key="count" className="num text-[13px] text-text-tertiary">
                    {count}
                </span>
            }}
            {note}
            {if actions {
                <div
                    key="actions"
                    className="flex w-full flex-wrap items-center gap-2 sm:ml-auto sm:w-auto"
                >
                    {actions}
                </div>
            }}
        </div>;
}
