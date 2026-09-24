"""Burn-up: scope and done as running totals per week. Scope is the indigo
series and done the green one, both series tokens, so the two lines stay
apart in either theme. Each week is a focusable hover zone with a tooltip."""

import from .Panel { Panel }
import from .ChartAxes { niceTop, YAxis, Gridlines, XLabels }
import from .ChartTip { SeriesKey, ChartTip }
import from .BurnUpPlot { BurnUpPlot }

glob SCOPE_COLOR: str = "var(--series-active)",
     DONE_COLOR: str = "var(--series-done)";

def:pub BurnUpChart(
    labels: list[str], scope: list[int], done: list[int]
) -> JsxElement {
    has hover: int = -1;

    n = len(scope);
    top = niceTop(scope);
    series: list[dict[str, any]] = [
        {"label": "Scope", "color": SCOPE_COLOR, "values": scope},
        {"label": "Done", "color": DONE_COLOR, "values": done}
    ];
    legend = <div className="flex items-center gap-3.5 text-xs text-muted-foreground">
        {for s in series {
            <span key={s["label"]} className="inline-flex items-center gap-1.5">
                <SeriesKey color={s["color"]}/>
                {s["label"]}
            </span>
        }}
    </div>;
    return
        <Panel id="burn-up" title="Burn-up" aside={legend}>
            <div className="flex gap-2 pt-2">
                <YAxis values={scope} plotH="h-44"/>
                <div className="relative mr-10 h-44 flex-1">
                    <Gridlines/>
                    <BurnUpPlot series={series} top={top} hover={hover}/>
                    <div
                        className="absolute inset-0 flex"
                        onMouseLeave={lambda { hover = -1; }}
                    >
                        {for (i, lab) in enumerate(labels) {
                            <div
                                key={str(i)}
                                tabIndex={0}
                                className="h-full flex-1 rounded-sm focus-visible:bg-muted/60 focus-visible:-outline-offset-2"
                                aria-label={"Week of "
                                    + lab
                                    + ": scope "
                                    + str(scope[i])
                                    + ", done "
                                    + str(done[i])}
                                onMouseEnter={lambda { hover = i; }}
                                onFocus={lambda { hover = i; }}
                                onBlur={lambda { hover = -1; }}
                            />
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
                                    "color": s["color"],
                                    "bar": False,
                                    "value": s["values"][hover],
                                    "label": s["label"]
                                } for s in series
                            ]}
                        />
                    }}
                </div>
            </div>
            <XLabels labels={labels} gutter="ml-9 mr-10"/>
        </Panel>;
}
