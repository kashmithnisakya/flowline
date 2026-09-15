"""The Overview's "This week" panel: four figures as a quiet two by two
ledger, then moves to Done per day (`chartState` is chart, loading or none;
`onRetry` adds Try again to the chart note). An empty `figures` list shows
`note` instead: nothing to count, no zeros."""

import from .HistoryCharts { DayChart }
import from ..ui.skeleton { Skeleton }

def:pub ThisWeek(
    figures: list[dict],
    days: list[dict],
    chartState: str = "chart",
    chartNote: str = "",
    note: str = "",
    onRetry: any = None
) -> JsxElement {
    return
        <section className="surface min-w-0" aria-labelledby="this-week">
            <div className="flex items-baseline gap-2 px-3.5 pt-3 pb-2">
                <h2 id="this-week" className="section-title text-[15px]">This week</h2>
            </div>
            {if len(figures) == 0 {
                <p
                    key="note"
                    className="px-3.5 pb-4 text-[13.5px] text-muted-foreground"
                >
                    {note}
                </p>
            } else {
                <div key="body">
                    <dl className="grid grid-cols-2 border-t">
                        {for (i, f) in enumerate(figures) {
                            <div
                                key={f["label"]}
                                className={"flex flex-col-reverse gap-0.5 border-b px-3.5 py-2.5 "
                                    + ("border-r" if i % 2 == 0 else "")}
                            >
                                <dt className="text-[12.5px] text-muted-foreground">
                                    {f["label"]}
                                </dt>
                                <dd
                                    className="font-mono text-xl leading-7 font-semibold tabular-nums"
                                >
                                    {f["value"]}
                                </dd>
                            </div>
                        }}
                    </dl>
                    <div className="px-3.5 pt-1 pb-3">
                        {if chartState == "chart" {
                            <DayChart key="chart" days={days}/>
                        } elif chartState == "loading" {
                            <Skeleton key="sk" className="mt-4 h-[134px] w-full"/>
                        } }
                        <p
                            className="mt-2 flex flex-wrap items-baseline gap-x-2 text-xs text-subtle"
                        >
                            {chartNote}
                            {if onRetry {
                                <button
                                    key="retry"
                                    type="button"
                                    className="text-[12.5px] text-primary underline underline-offset-[3px] hover:decoration-2"
                                    onClick={lambda { onRetry(); }}
                                >
                                    Try again
                                </button>
                            }}
                        </p>
                    </div>
                </div>
            } }
        </section>;
}
