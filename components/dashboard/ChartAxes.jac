"""Shared chart parts: the axis top, the y labels, the gridlines and the week
labels. Marks are stretched to the plot and every label is HTML over it, so
text never scales. max() over a list is NaN on the client, hence the loop."""

# A clean axis top at or above the peak (1.2, 1.5, 2 ... 10 times a power of
# ten), whole and even so the midline tick is whole too.
def:pub niceTop(values: list[int]) -> int {
    peak = 0;
    for v in values {
        if v > peak {
            peak = v;
        }
    }
    if peak <= 2 {
        return 2;
    }
    step = 1;
    while step * 10 <= peak {
        step = step * 10;
    }
    for m in [12, 15, 20, 25, 30, 40, 50, 60, 80, 100] {
        top = m * step // 10;
        if (m * step) % 10 == 0 and top >= peak and top % 2 == 0 {
            return top;
        }
    }
    return 10 * step;
}

# The axis for `values`: its niceTop, the midline and zero.
def:pub YAxis(values: list[int], plotH: str) -> JsxElement {
    top = niceTop(values);
    return
        <div
            className={"relative w-7 shrink-0 text-right num text-xs text-subtle "
                + plotH}
            aria-hidden="true"
        >
            <span className="absolute right-0 top-0 -translate-y-1/2">{str(top)}</span>
            <span className="absolute right-0 top-1/2 -translate-y-1/2">
                {str(top // 2)}
            </span>
            <span className="absolute right-0 bottom-0 translate-y-1/2">0</span>
        </div>;
}

def:pub Gridlines -> JsxElement {
    return
        <div className="pointer-events-none absolute inset-0" aria-hidden="true">
            <div className="absolute inset-x-0 top-0 border-t border-dashed"/>
            <div className="absolute inset-x-0 top-1/2 border-t border-dashed"/>
            <div className="absolute inset-x-0 bottom-0 border-t"/>
        </div>;
}

# Every week up to 8 is labelled, then every 2nd or 4th counted back from
# the newest; below `sm` only every other printed label shows.
def:pub XLabels(labels: list[str], gutter: str) -> JsxElement {
    n = len(labels);
    step = 1 if n <= 8 else (2 if n <= 16 else 4);
    return
        <div
            className={"mt-2 flex num text-xs text-subtle " + gutter}
            aria-hidden="true"
        >
            {for (i, lab) in enumerate(labels) {
                <div
                    key={str(i)}
                    className={"flex-1 text-center whitespace-nowrap "
                        + (
                            ""
                                if (n - 1 - i) % (step * 2) == 0
                                else "invisible sm:visible"
                        )}
                >
                    {lab if (n - 1 - i) % step == 0 else ""}
                </div>
            }}
        </div>;
}
