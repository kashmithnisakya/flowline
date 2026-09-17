"""The swap from a page's first-load frame to its content: both sit in one
grid cell for 150ms, the frame fading out under the content fading in, so no
frame in between is blank. Mounted with the content already there (a cached
read) it draws the content plainly; once the frame has gone it never returns.
"""

import from "react" { useEffect }

def:pub Reveal(
    ready: bool, frame: any, className: str = "", children: any = None
) -> JsxElement {
    has framed: bool = not ready,
        crossfade: bool = not ready;

    useEffect(
        lambda {
            timer: any = 0;
            if ready and framed {
                timer = window.setTimeout(lambda { framed = False; }, 160);
            }
            return lambda { if timer { window.clearTimeout(timer); }};
        },
        [ready]
    );

    return
        <div className={"grid grid-cols-[minmax(0,1fr)] " + className}>
            {if framed {
                <div
                    key="frame"
                    data-reveal="frame"
                    aria-hidden={"true" if ready else None}
                    className={"min-w-0 [grid-area:1/1] "
                        + (
                            "pointer-events-none animate-out fade-out duration-150 fill-mode-forwards"
                                if ready
                                else ""
                        )}
                >
                    {frame}
                </div>
            }}
            {if ready {
                <div
                    key="body"
                    data-reveal="body"
                    className={"min-w-0 [grid-area:1/1] "
                        + ("animate-in fade-in duration-150" if crossfade else "")}
                >
                    {children}
                </div>
            }}
        </div>;
}
