"""The burn-up's marks: one 2px line per series, a dot on the newest and the
hovered week, and the end values beside the plot while the two ends sit
more than ~16px apart on the 176px plot (else the legend carries them)."""

import from .ChartTip { colX }

def valY(v: int, top: int) -> float {
    return 100.0 - v * 100.0 / top;
}

def linePath(values: list[int], top: int) -> str {
    n = len(values);
    return " ".join(
        [
            ("M" if i == 0 else "L") + str(colX(i, n)) + " " + str(valY(v, top))
            for (i, v) in enumerate(values)
        ]
    );
}

def Dot(i: int, n: int, v: int, top: int, color: str) -> JsxElement {
    return
        <div
            className="pointer-events-none absolute size-2 -translate-x-1/2 -translate-y-1/2 rounded-full"
            style={{
                "left": str(colX(i, n)) + "%",
                "top": str(valY(v, top)) + "%",
                "background": color,
                "boxShadow": "0 0 0 2px var(--card)"
            }}
        />;
}

def:pub BurnUpPlot(series: list[dict[str, any]], top: int, hover: int) -> JsxElement {
    n = len(series[0]["values"]) if len(series) > 0 else 0;
    ends = [s["values"][n - 1] for s in series] if n > 0 else [];
    apart = len(ends) == 2 and abs(ends[0] - ends[1]) * 176 >= top * 16;
    return
        <div className="pointer-events-none absolute inset-0">
            <svg
                className="absolute inset-0 h-full w-full overflow-visible"
                viewBox="0 0 100 100"
                preserveAspectRatio="none"
                aria-hidden="true"
            >
                {for s in series {
                    <path
                        key={s["label"]}
                        d={linePath(s["values"], top)}
                        fill="none"
                        stroke={s["color"]}
                        strokeWidth={2}
                        strokeLinejoin="round"
                        strokeLinecap="round"
                        vectorEffect="non-scaling-stroke"
                    />
                }}
            </svg>
            {if hover >= 0 and hover < n {
                <div
                    key="cross"
                    className="absolute inset-y-0 w-px bg-foreground/25"
                    style={{"left": str(colX(hover, n)) + "%"}}
                />
            }}
            {for s in (series if n > 0 else []) {
                <div key={s["label"]}>
                    <Dot
                        i={n - 1}
                        n={n}
                        v={s["values"][n - 1]}
                        top={top}
                        color={s["color"]}
                    />
                    {if hover >= 0 and hover < n - 1 {
                        <Dot
                            key="h"
                            i={hover}
                            n={n}
                            v={s["values"][hover]}
                            top={top}
                            color={s["color"]}
                        />
                    }}
                    {if apart {
                        <span
                            key="end"
                            className="absolute left-full ml-2.5 -translate-y-1/2 num text-xs font-medium"
                            style={{"top": str(valY(s["values"][n - 1], top)) + "%"}}
                        >
                            {str(s["values"][n - 1])}
                        </span>
                    }}
                </div>
            }}
        </div>;
}
