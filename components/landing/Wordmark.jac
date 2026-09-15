"""The route mark (an open start node, one bend, a filled end node) beside the
flowline wordmark. Drawn inline in currentColor on --mark, so it follows the
theme without a second image; brand/logo.jac draws the same path.
"""

def:pub RouteMark(size: int = 20, className: str = "") -> JsxElement {
    return
        <svg
            className={"shrink-0 text-mark " + className}
            width={size}
            height={size}
            viewBox="0 0 24 24"
            fill="none"
            aria-hidden="true"
        >
            <circle cx={5} cy={17} r={3} stroke="currentColor" strokeWidth={2.2}/>
            <path
                d="M8 17h3.5a3 3 0 0 0 3-3v-4a3 3 0 0 1 1.5-2.6"
                stroke="currentColor"
                strokeWidth={2.2}
                strokeLinecap="round"
            />
            <circle cx={19} cy={7} r={3} fill="currentColor"/>
        </svg>;
}

def:pub Wordmark(className: str = "") -> JsxElement {
    return
        <span className={"inline-flex items-center gap-2 " + className}>
            <RouteMark/>
            <span
                className="text-base leading-none font-extrabold tracking-[-0.01em] text-foreground [font-stretch:125%]"
            >
                flowline
            </span>
        </span>;
}
