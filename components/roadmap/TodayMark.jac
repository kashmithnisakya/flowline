"""Today's line inside one row's timeline cell, drawn per row so the sticky
task column always covers it."""

def:pub TodayMark(left: str) -> JsxElement {
    return
        <span
            className="pointer-events-none absolute inset-y-0 z-10 w-0.5 -translate-x-1/2 bg-primary"
            style={{"left": left}}
            aria-hidden="true"
        />;
}
