"""One section of the Workspace page: a panel under its header, the anchor the
rail scrolls to. `flush` lays a table with its own surface straight into the
panel, so a row runs edge to edge under the header.
"""

import from .SectionHeader { SectionHeader }

glob:pub FLUSH: str = "overflow-hidden rounded-b-md [&_.surface]:rounded-none [&_.surface]:border-0";

def:pub SectionPanel(
    section: str,
    title: str,
    count: str = "",
    note: any = None,
    actions: any = None,
    flush: bool = False,
    children: any = None
) -> JsxElement {
    heading = "section-title-" + section;
    return
        <section
            id={"section-" + section}
            aria-labelledby={heading}
            className="surface scroll-mt-[116px] md:scroll-mt-[72px] lg:scroll-mt-6"
        >
            <SectionHeader
                id={heading}
                title={title}
                count={count}
                note={note}
                actions={actions}
            />
            <div className={FLUSH if flush else ""}>{children}</div>
        </section>;
}
