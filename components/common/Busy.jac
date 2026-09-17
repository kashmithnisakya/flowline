"""A quiet in-flight mark for refetches: a 14px spinner that appears only once
`active` has held for 300ms, in a box that is always reserved so nothing on
the row shifts when it comes and goes.
"""

import from "react" { useEffect }
import from .glyphs { Spinner }

def:pub Busy(active: bool, className: str = "") -> JsxElement {
    has shown: bool = False;

    useEffect(
        lambda {
            timer: any = 0;
            if active {
                timer = window.setTimeout(lambda { shown = True; }, 300);
            } else {
                shown = False;
            }
            return lambda { if timer { window.clearTimeout(timer); }};
        },
        [active]
    );

    return
        <span
            className={"inline-flex size-3.5 shrink-0 items-center justify-center text-muted-foreground "
                + className}
            role="status"
            aria-label={"Updating" if shown else None}
        >
            {if shown {
                <Spinner key="sp"/>
            }}
        </span>;
}
