"""A step kind drawn as a glyph, so meaning never rides on colour: start is an
open circle, active half filled, handoff a diamond with an arrow, blocked an
octagon with a bar, done a filled check. Knockouts paint --kind-knockout
(default the card), so a glyph on another ground sets that variable.
"""

def:pub KindGlyph(kind: str, size: int = 14, className: str = "") -> JsxElement {
    knock = "var(--kind-knockout, var(--card))";
    if kind == "start" {
        return
            <svg
                className={"shrink-0 " + className}
                width={size}
                height={size}
                viewBox="0 0 16 16"
                aria-hidden="true"
            >
                <circle
                    cx={8}
                    cy={8}
                    r={5.25}
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={1.8}
                />
            </svg>;
    }
    if kind == "handoff" {
        return
            <svg
                className={"shrink-0 " + className}
                width={size}
                height={size}
                viewBox="0 0 16 16"
                aria-hidden="true"
            >
                <path
                    d="M8 2.2 13.8 8 8 13.8 2.2 8z"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={1.8}
                    strokeLinejoin="round"
                />
                <path
                    d="M5.6 8h4.6M8.6 6.2 10.4 8 8.6 9.8"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={1.5}
                    strokeLinecap="round"
                    strokeLinejoin="round"
                />
            </svg>;
    }
    if kind == "blocked" {
        return
            <svg
                className={"shrink-0 " + className}
                width={size}
                height={size}
                viewBox="0 0 16 16"
                aria-hidden="true"
            >
                <path d="M5.5 2h5L14 5.5v5L10.5 14h-5L2 10.5v-5z" fill="currentColor"/>
                <path
                    d="M5 8h6"
                    style={{"stroke": knock}}
                    strokeWidth={1.8}
                    strokeLinecap="round"
                />
            </svg>;
    }
    if kind == "done" {
        return
            <svg
                className={"shrink-0 " + className}
                width={size}
                height={size}
                viewBox="0 0 16 16"
                aria-hidden="true"
            >
                <circle cx={8} cy={8} r={6} fill="currentColor"/>
                <path
                    d="m5.3 8.2 1.8 1.8 3.6-3.8"
                    fill="none"
                    style={{"stroke": knock}}
                    strokeWidth={1.7}
                    strokeLinecap="round"
                    strokeLinejoin="round"
                />
            </svg>;
    }
    return
        <svg
            className={"shrink-0 " + className}
            width={size}
            height={size}
            viewBox="0 0 16 16"
            aria-hidden="true"
        >
            <circle
                cx={8}
                cy={8}
                r={5.25}
                fill="none"
                stroke="currentColor"
                strokeWidth={1.8}
            />
            <path d="M8 2.75a5.25 5.25 0 0 1 0 10.5z" fill="currentColor"/>
        </svg>;
}
