"""The workspace rail: one link per section, and the page shows the chosen one.
A sticky column at md and up, one scrolling row on a phone. Items are real
links, so a section opens in a new tab too; a plain click switches in place.
"""

import from "react" { useEffect }

def:pub WorkspaceRail(
    items: list[list[str]], current: str, onSelect: Callable[[str], None]
) -> JsxElement {
    has navRef: Ref[any] = Ref();

    # On a phone the row scrolls sideways; keep the current section in view,
    # so a deep link to Preferences does not open on a clipped label.
    useEffect(
        lambda {
            nav: any = navRef.current;
            if nav and nav.scrollWidth > nav.clientWidth {
                el: any = nav.querySelector("[aria-current=location]");
                if el {
                    box: any = nav.getBoundingClientRect();
                    at: any = el.getBoundingClientRect();
                    if at.right > box.right or at.left < box.left {
                        nav.scrollLeft = nav.scrollLeft + at.left - box.left - 16;
                    }
                }
            }
        },
        [current]
    );

    return
        <nav
            ref={navRef}
            aria-label="Workspace sections"
            className="sticky top-14 z-30 -mx-4 flex gap-1 overflow-x-auto border-b bg-background px-4 py-2 sm:-mx-6 sm:px-6 md:top-[72px] md:z-auto md:mx-0 md:w-[160px] md:shrink-0 md:flex-col md:gap-px md:self-start md:overflow-visible md:border-b-0 md:bg-transparent md:px-0 md:py-0 lg:top-6"
        >
            <h1 className="page-title hidden px-2 pb-3 md:block">Workspace</h1>
            {for item in items {
                <a
                    key={item[0]}
                    href={"/workspace?tab=" + item[0]}
                    aria-current={"location" if current == item[0] else None}
                    className={"flex h-[30px] shrink-0 items-center rounded-md px-2 text-[13px] whitespace-nowrap transition-colors "
                        + (
                            "bg-bg-selected font-medium text-text-primary"
                                if current == item[0]
                                else "text-text-secondary hover:bg-bg-hover hover:text-text-primary"
                        )}
                    onClick={lambda (e: MouseEvent) { if not (
                        e.metaKey or e.ctrlKey or e.shiftKey
                    ) {
                        e.preventDefault();
                        onSelect(item[0]);
                    }}}
                >
                    {item[1]}
                </a>
            }}
        </nav>;
}
