"""Done per week's plot: one thin bar per week on one baseline, this week lighter
because it is not over. Only the peak and this week carry a number; hover or
focus gives any week's tip, which adds how many tasks came in that week."""

import from .ChartTip { ChartTip }

glob DONE_COLOR: str = "var(--series-done)";

def:pub WeekBars(
    labels: list[str], finished: list[int], added: list[int]
) -> JsxElement {
    has hover: int = -1;

    n = len(finished);
    peak = 0;
    peakAt = -1;
    for (i, v) in enumerate(finished) {
        if v > 0 and v >= peak {
            peak = v;
            peakAt = i;
        }
    }
    top = peak if peak > 0 else 1;
    return
        <div>
            <div
                className="relative flex h-32 border-b border-border-strong pt-5"
                onMouseLeave={lambda { hover = -1; }}
            >
                {for (i, v) in enumerate(finished) {
                    <div
                        key={str(i)}
                        tabIndex={0}
                        className={"flex h-full flex-1 flex-col items-center justify-end rounded-t-sm focus-visible:-outline-offset-2 "
                            + ("bg-bg-hover" if i == hover else "")}
                        aria-label={"Week of "
                            + labels[i]
                            + ": "
                            + str(v)
                            + " done, "
                            + str(added[i])
                            + " added"}
                        onMouseEnter={lambda { hover = i; }}
                        onFocus={lambda { hover = i; }}
                        onBlur={lambda { hover = -1; }}
                    >
                        {if i == peakAt or i == n - 1 {
                            <span
                                key="val"
                                className="num mb-1 shrink-0 text-xs text-text-secondary"
                            >
                                {str(v)}
                            </span>
                        }}
                        <div
                            className="w-[18px] shrink-0 rounded-t-[4px]"
                            style={{
                                "height": str(v * 100.0 / top) + "%",
                                "background": DONE_COLOR,
                                "opacity": "0.55" if i == n - 1 else "1"
                            }}
                        />
                    </div>
                }}
                {if hover >= 0 and hover < n {
                    <ChartTip
                        key="tip"
                        week={labels[hover]}
                        i={hover}
                        n={n}
                        rows={[
                            {
                                "color": DONE_COLOR,
                                "bar": True,
                                "value": finished[hover],
                                "label": "moved to Done"
                            },
                            {
                                "color": "",
                                "bar": False,
                                "value": added[hover],
                                "label": "added"
                            }
                        ]}
                    />
                }}
            </div>
            <div
                className="mt-1.5 flex justify-between text-xs text-text-tertiary"
                aria-hidden="true"
            >
                <span className="num">{labels[0] if n > 0 else ""}</span>
                <span>This week so far</span>
            </div>
        </div>;
}
