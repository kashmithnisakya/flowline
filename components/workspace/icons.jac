"""Inline stroke icons for the workspace and GitHub pages, drawn in
currentColor and hidden from assistive tech; the control carries the label.
"""

def:pub IconPlus(size: int = 14, className: str = "") -> JsxElement {
    return
        <svg
            width={size}
            height={size}
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth={2}
            strokeLinecap="round"
            strokeLinejoin="round"
            className={className}
            aria-hidden="true"
        >
            <path d="M12 5v14"/>
            <path d="M5 12h14"/>
        </svg>;
}

def:pub IconChevron(size: int = 14, className: str = "") -> JsxElement {
    return
        <svg
            width={size}
            height={size}
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth={2}
            strokeLinecap="round"
            strokeLinejoin="round"
            className={className}
            aria-hidden="true"
        >
            <path d="m6 9 6 6 6-6"/>
        </svg>;
}

def:pub IconMore(size: int = 16, className: str = "") -> JsxElement {
    return
        <svg
            width={size}
            height={size}
            viewBox="0 0 24 24"
            fill="currentColor"
            className={className}
            aria-hidden="true"
        >
            <circle cx={5} cy={12} r={1.8}/>
            <circle cx={12} cy={12} r={1.8}/>
            <circle cx={19} cy={12} r={1.8}/>
        </svg>;
}

def:pub IconSearch(size: int = 14, className: str = "") -> JsxElement {
    return
        <svg
            width={size}
            height={size}
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth={2}
            strokeLinecap="round"
            strokeLinejoin="round"
            className={className}
            aria-hidden="true"
        >
            <circle cx={11} cy={11} r={7}/>
            <path d="m20 20-3.5-3.5"/>
        </svg>;
}

def:pub IconCheck(size: int = 14, className: str = "") -> JsxElement {
    return
        <svg
            width={size}
            height={size}
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth={2.2}
            strokeLinecap="round"
            strokeLinejoin="round"
            className={className}
            aria-hidden="true"
        >
            <path d="M20 6 9 17l-5-5"/>
        </svg>;
}

def:pub IconLock(size: int = 14, className: str = "") -> JsxElement {
    return
        <svg
            width={size}
            height={size}
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth={2}
            strokeLinecap="round"
            strokeLinejoin="round"
            className={className}
            aria-hidden="true"
        >
            <rect x={5} y={11} width={14} height={10} rx={2}/>
            <path d="M8 11V7a4 4 0 0 1 8 0v4"/>
        </svg>;
}

def:pub IconX(size: int = 12, className: str = "") -> JsxElement {
    return
        <svg
            width={size}
            height={size}
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth={2}
            strokeLinecap="round"
            className={className}
            aria-hidden="true"
        >
            <path d="M18 6 6 18"/>
            <path d="m6 6 12 12"/>
        </svg>;
}

def:pub IconSync(size: int = 14, className: str = "") -> JsxElement {
    return
        <svg
            width={size}
            height={size}
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth={2}
            strokeLinecap="round"
            strokeLinejoin="round"
            className={className}
            aria-hidden="true"
        >
            <path d="M21 12a9 9 0 0 1-15.5 6.2L3 16"/>
            <path d="M3 12a9 9 0 0 1 15.5-6.2L21 8"/>
            <path d="M21 3v5h-5"/>
            <path d="M3 21v-5h5"/>
        </svg>;
}

def:pub IconExternal(size: int = 12, className: str = "") -> JsxElement {
    return
        <svg
            width={size}
            height={size}
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth={2}
            strokeLinecap="round"
            strokeLinejoin="round"
            className={className}
            aria-hidden="true"
        >
            <path d="M15 3h6v6"/>
            <path d="M10 14 21 3"/>
            <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>
        </svg>;
}

# GitHub's mark, filled; a fixed path, so it renders the same at any size.
def:pub IconGithub(size: int = 16, className: str = "") -> JsxElement {
    return
        <svg
            width={size}
            height={size}
            viewBox="0 0 24 24"
            fill="currentColor"
            className={className}
            aria-hidden="true"
        >
            <path
                d="M12 .5C5.65.5.5 5.65.5 12a11.5 11.5 0 0 0 7.86 10.92c.58.1.79-.25.79-.56v-2c-3.2.7-3.88-1.37-3.88-1.37-.52-1.33-1.28-1.69-1.28-1.69-1.05-.72.08-.7.08-.7 1.16.08 1.77 1.19 1.77 1.19 1.03 1.77 2.7 1.26 3.36.96.1-.75.4-1.26.73-1.55-2.55-.29-5.24-1.28-5.24-5.68 0-1.25.45-2.28 1.19-3.08-.12-.29-.52-1.46.11-3.05 0 0 .97-.31 3.17 1.18a11 11 0 0 1 5.77 0c2.2-1.49 3.17-1.18 3.17-1.18.63 1.59.23 2.76.11 3.05.74.8 1.19 1.83 1.19 3.08 0 4.41-2.69 5.39-5.25 5.67.41.36.78 1.06.78 2.14v3.17c0 .31.21.67.8.56A11.5 11.5 0 0 0 23.5 12C23.5 5.65 18.35.5 12 .5Z"
            />
        </svg>;
}
