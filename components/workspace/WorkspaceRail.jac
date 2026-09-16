"""The workspace rail: the organization's name over its sections, each with a
count. A column at md and up, one scrolling row on a phone. Items are real
links, so a section opens in a new tab too; a plain click stays in place.
"""

import from "react" { useEffect }

def:pub WorkspaceRail(
    orgName: str,
    items: list[dict[str, str]],
    current: str,
    onSelect: Callable[[str], None]
) -> JsxElement {
    has navRef: Ref[any] = Ref();

    # Counts arrive after the first paint and widen the row, so they are part
    # of what the scroll position depends on.
    widths = "|".join([item["count"] for item in items]);

    # On a phone the row scrolls sideways; keep the current section in view,
    # so a deep link to Preferences does not open on a clipped label.
    useEffect(
        lambda {
            nav: any = navRef.current;
            if nav and nav.scrollWidth > nav.clientWidth {
                el: any = nav.querySelector("[aria-current=page]");
                if el {
                    box: any = nav.getBoundingClientRect();
                    at: any = el.getBoundingClientRect();
                    if at.right > box.right or at.left < box.left {
                        nav.scrollLeft = nav.scrollLeft + at.left - box.left - 16;
                    }
                }
            }
        },
        [current, widths]
    );

    return
        <nav
            ref={navRef}
            aria-label="Workspace sections"
            className="-mx-4 flex gap-1 overflow-x-auto border-b px-4 pb-2 sm:-mx-6 sm:px-6 md:sticky md:top-20 md:mx-0 md:flex-col md:gap-0.5 md:overflow-visible md:border-b-0 md:px-0 md:pb-0"
        >
            {if orgName {
                <div
                    key="org"
                    className="hidden truncate px-2 pt-0.5 pb-2.5 text-sm font-bold [font-stretch:108%] md:block"
                    title={orgName}
                >
                    {orgName}
                </div>
            }}
            {for item in items {
                <a
                    key={item["key"]}
                    href={"/workspace?tab=" + item["key"]}
                    aria-current={"page" if current == item["key"] else None}
                    className={"group flex shrink-0 items-center justify-between gap-4 rounded-md px-2 py-1.5 text-[13.5px] whitespace-nowrap transition-colors duration-150 "
                        + (
                            "bg-accent font-semibold text-foreground"
                                if current == item["key"]
                                else "text-muted-foreground hover:bg-accent hover:text-foreground"
                        )}
                    onClick={lambda (e: MouseEvent) { if not (
                        e.metaKey or e.ctrlKey or e.shiftKey
                    ) {
                        e.preventDefault();
                        onSelect(item["key"]);
                    }}}
                >
                    <span>{item["label"]}</span>
                    {if item["count"] {
                        <span
                            key="n"
                            className={"num text-xs font-normal "
                                + (
                                    "text-muted-foreground"
                                        if current == item["key"]
                                        else "text-subtle group-hover:text-muted-foreground"
                                )}
                        >
                            {item["count"]}
                        </span>
                    }}
                </a>
            }}
        </nav>;
}
