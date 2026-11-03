"""This week's moves to Done, one thin bar per day on one baseline. Only the
week's peak and today carry a number; hover or focus gives any day's tip. `days`
rows are dicts: name, label, value, future (outlined, never drawn as zero), today."""

import from .ChartTip { ChartTip }

glob DONE_COLOR: str = "var(--series-done)";

def:pub DayChart(days: list[dict[str, any]]) -> JsxElement {
    has hover: int = -1;

    n = len(days);
    peak = 0;
    for d in days {
        if not d["future"] and d["value"] > peak {
            peak = d["value"];
        }
    }
    top = peak if peak > 0 else 1;
    return
        <div>
            <div
                className="relative flex h-28 border-b border-border-strong pt-5"
                onMouseLeave={lambda { hover = -1; }}
            >
                {for (i, d) in enumerate(days) {
                    <div
                        key={d["name"]}
                        tabIndex={-1 if d["future"] else 0}
                        className={"flex h-full flex-1 flex-col items-center justify-end rounded-t-sm focus-visible:-outline-offset-2 "
                            + ("bg-bg-hover" if i == hover else "")}
                        aria-label={d["name"]
                            + (
                                ": still ahead"
                                    if d["future"]
                                    else ": " + str(d["value"]) + " moved to Done"
                            )}
                        onMouseEnter={lambda { hover = -1 if d["future"] else i; }}
                        onFocus={lambda { hover = i; }}
                        onBlur={lambda { hover = -1; }}
                    >
                        {if d["future"] {
                            <div
                                key="ahead"
                                className="h-3.5 w-[18px] shrink-0 rounded-t-[4px] border border-dashed border-input"
                            />
                        } else {
                            <div key="bar" className="contents">
                                {if d["today"] or (peak > 0 and d["value"] == peak) {
                                    <span
                                        key="val"
                                        className="num mb-1 shrink-0 text-xs text-text-secondary"
                                    >
                                        {str(d["value"])}
                                    </span>
                                }}
                                <div
                                    className="w-[18px] shrink-0 rounded-t-[4px]"
                                    style={{
                                        "height": str(d["value"] * 100.0 / top) + "%",
                                        "background": DONE_COLOR
                                    }}
                                />
                            </div>
                        } }
                    </div>
                }}
                {if hover >= 0 and hover < n {
                    <ChartTip
                        key="tip"
                        week={days[hover]["name"]}
                        prefix=""
                        i={hover}
                        n={n}
                        rows={[
                            {
                                "color": DONE_COLOR,
                                "bar": True,
                                "value": days[hover]["value"],
                                "label": "moved to Done"
                            }
                        ]}
                    />
                }}
            </div>
            <div className="mt-1.5 flex text-xs text-text-tertiary" aria-hidden="true">
                {for d in days {
                    <span
                        key={d["name"]}
                        className={"flex-1 text-center whitespace-nowrap "
                            + ("font-medium text-text-primary" if d["today"] else "")}
                    >
                        {"Today" if d["today"] else d["label"]}
                    </span>
                }}
            </div>
        </div>;
}
