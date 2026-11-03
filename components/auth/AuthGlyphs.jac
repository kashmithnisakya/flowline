"""The sign-in form's small line glyphs: the expired clock, the password's eye and
the length rule's mark."""

def Glyph(
    size: int, weight: float, className: str = "", children: any = None
) -> JsxElement {
    return
        <svg
            className={className}
            width={size}
            height={size}
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth={weight}
            strokeLinecap="round"
            strokeLinejoin="round"
            aria-hidden="true"
        >
            {children}
        </svg>;
}

def:pub ClockGlyph -> JsxElement {
    return
        <Glyph size={14} weight={2.0} className="mt-0.5 shrink-0">
            <circle cx={12} cy={12} r={10}/>
            <path d="M12 6v6l4 2"/>
        </Glyph>;
}

def:pub EyeGlyph(crossed: bool) -> JsxElement {
    return
        <Glyph size={16} weight={2.0}>
            <path
                d="M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0"
            />
            <circle cx={12} cy={12} r={3}/>
            {if crossed {
                <path key="slash" d="m3 3 18 18"/>
            }}
        </Glyph>;
}

def:pub RuleGlyph(met: bool) -> JsxElement {
    return
        <Glyph size={12} weight={2.5}>
            <path d={"m5 12 5 5L20 7" if met else "M8 12h8"}/>
        </Glyph>;
}
