"""Inline SVG glyphs repeated across the app: the busy spinner every in-flight
button shows, and the warning triangle error notes and advisory chips carry.
"""

def:pub Spinner(className: str = "") -> JsxElement {
    return
        <svg
            className={"animate-spin" + (" " + className if className else "")}
            width={14}
            height={14}
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth={2}
            strokeLinecap="round"
            aria-hidden="true"
        >
            <path d="M21 12a9 9 0 1 1-6.219-8.56"/>
        </svg>;
}


def:pub WarnIcon(size: int = 14, className: str = "") -> JsxElement {
    return
        <svg
            className={className}
            width={size}
            height={size}
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth={2}
            strokeLinecap="round"
            strokeLinejoin="round"
            aria-hidden="true"
        >
            <path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 20h16a2 2 0 0 0 1.73-2Z"/>
            <path d="M12 9v4"/>
            <path d="M12 17h.01"/>
        </svg>;
}
