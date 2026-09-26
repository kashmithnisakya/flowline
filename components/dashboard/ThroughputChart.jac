"""Throughput: tasks moved to Done per week as bars, the newest capped with
its value. Each week is a focusable hover zone; its tooltip adds how many
tasks were added that week."""

import from .Panel { Panel }
import from .ChartAxes { niceTop, YAxis, Gridlines, XLabels }
import from .ChartTip { SeriesKey, ChartTip }

glob DONE_COLOR: str = "var(--series-done)";

def:pub ThroughputChart(
    labels: list[str], finished: list[int], added: list[int]
) -> JsxElement {
    has hover: int = -1;

    n = len(finished);
    top = niceTop(finished);
    legend = <span
        className="inline-flex items-center gap-1.5 text-xs text-muted-foreground"
    >
        <SeriesKey color={DONE_COLOR} bar={True}/>
        Moved to Done
    </span>;
    return
        <Panel id="throughput" title="Done per week" aside={legend}>
            <div className="flex gap-2 pt-2">
                <YAxis values={finished} plotH="h-44"/>
                <div className="relative h-44 flex-1">
                    <Gridlines/>
                    <div
                        className="absolute inset-0 flex"
                        onMouseLeave={lambda { hover = -1; }}
                    >
                        {for (i, v) in enumerate(finished) {
                            <div
                                key={str(i)}
                                tabIndex={0}
                                className={"relative flex h-full flex-1 items-end justify-center rounded-sm focus-visible:-outline-offset-2 "
                                    + ("bg-muted/60" if i == hover else "")}
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
                                {if i == n - 1 and v > 0 {
                                    <span
                                        key="cap"
                                        className="pointer-events-none absolute -translate-y-1 num text-xs font-medium"
                                        style={{"bottom": str(v * 100.0 / top) + "%"}}
                                    >
                                        {str(v)}
                                    </span>
                                }}
                                <div
                                    className="w-3/5 max-w-6 rounded-t-[3px]"
                                    style={{
                                        "height": str(v * 100.0 / top) + "%",
                                        "background": DONE_COLOR,
                                        "opacity": "1"
                                            if hover < 0 or hover == i
                                            else "0.55"
                                    }}
                                />
                            </div>
                        }}
                    </div>
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
            </div>
            <XLabels labels={labels} gutter="ml-9"/>
        </Panel>;
}
