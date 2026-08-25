"""Scroll-reveal wrapper for landing sections: children fade and rise in
the first time they enter the viewport. Reduced-motion visitors (and any
browser without IntersectionObserver) see everything immediately.
"""

import from "react" { useEffect }

def:pub Reveal(props: any) -> JsxElement {
    has shown: bool = False,
        boxRef: Ref[any] = Ref();

    useEffect(
        lambda {
            # The early exit returns a no-op cleanup rather than None: React
            # calls back anything that is not `undefined`.
            obs: any = 0;
            w: any = window;
            media: any = w.matchMedia("(prefers-reduced-motion: reduce)");
            el: any = boxRef.current;
            if bool(media.matches) or not el or not w.IntersectionObserver {
                shown = True;
            } else {
                obs = new(
                    w.IntersectionObserver,
                    lambda (entries: any) { if len(entries) > 0
                    and entries[0].isIntersecting {
                        shown = True;
                    }},
                    {"threshold": 0.08}
                );
                obs.observe(el);
            }
            return lambda { if obs { obs.disconnect(); }};
        },
        []
    );

    return
        <div
            ref={boxRef}
            className={"transition-[opacity,transform] duration-500 ease-out " + (
                "translate-y-0 opacity-100" if shown else "translate-y-3 opacity-0"
            )}
        >
            {props["children"]}
        </div>;
}
