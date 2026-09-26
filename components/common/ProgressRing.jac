"""A checklist's progress as a small ring. Pairs with the "2/5" count beside
it, so the ring is a glance and the number is the detail; the ring alone
never carries the information.
"""

def:pub ProgressRing(done: int = 0, total: int = 0, size: int = 14) -> JsxElement {
    r = 6.0;
    c = 2.0 * 3.14159265 * r;
    frac = (done / total) if total > 0 else 0.0;
    return
        <svg
            className="shrink-0 -rotate-90 text-text-tertiary"
            width={size}
            height={size}
            viewBox="0 0 16 16"
            aria-hidden="true"
        >
            <circle
                cx={8}
                cy={8}
                r={r}
                fill="none"
                stroke="currentColor"
                strokeWidth={2}
                opacity={0.25}
            />
            <circle
                cx={8}
                cy={8}
                r={r}
                fill="none"
                stroke="currentColor"
                strokeWidth={2}
                strokeLinecap="round"
                strokeDasharray={str(c)}
                strokeDashoffset={str(c * (1.0 - frac))}
            />
        </svg>;
}
