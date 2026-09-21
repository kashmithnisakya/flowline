"""The Overview's "This week" panel: four figures as a quiet two by two
ledger, then moves to Done per day (`chartState` is chart, loading or none;
`onRetry` adds Try again to the chart note). An empty `figures` list shows
`note` instead: nothing to count, no zeros."""

import from .HistoryCharts { DayChart }
import from ..ui.skeleton { Skeleton }

# The four figures in order, for the placeholder ledger before they land.
glob FIGURE_LABELS: list[str] = [
         "moved to Done",
         "tasks added",
         "log entries",
         "open tasks"
     ];

def:pub ThisWeek(
    figures: list[dict[str, any]],
    days: list[dict[str, any]],
    chartState: str = "chart",
    chartNote: str = "",
    note: str = "",
    onRetry: any = None,
    # The first load: the ledger with its labels and skeleton figures, and
    # the day chart's box when the last visit drew one (else its note line).
    placeholder: bool = False,
    placeholderChart: bool = True
) -> JsxElement {
    return
        <section
            className="surface min-w-0"
            aria-labelledby="this-week"
            aria-busy={placeholder}
        >
            <div className="flex items-baseline gap-2 px-3.5 pt-3 pb-2">
                <h2 id="this-week" className="section-title text-[15px]">This week</h2>
            </div>
            {if placeholder {
                <div key="ph">
                    <dl className="grid grid-cols-2 border-t">
                        {for (i, label) in enumerate(FIGURE_LABELS) {
                            <div
                                key={label}
                                className={"flex flex-col-reverse gap-0.5 border-b px-3.5 py-2.5 "
                                    + ("border-r" if i % 2 == 0 else "")}
                            >
                                <dt className="text-[12.5px] text-muted-foreground">
                                    {label}
                                </dt>
                                <dd className="flex h-7 items-center">
                                    <Skeleton className="h-4 w-8"/>
                                </dd>
                            </div>
                        }}
                    </dl>
                    <div className="px-3.5 pt-1 pb-3">
                        {if placeholderChart {
                            <Skeleton key="chart" className="mt-4 h-[118px] w-full"/>
                        }}
                        <div className="mt-2 flex h-4 items-center">
                            <Skeleton className="h-3 w-72 max-w-full"/>
                        </div>
                    </div>
                </div>
            } elif len(figures) == 0 {
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
                            <Skeleton key="sk" className="mt-4 h-[118px] w-full"/>
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
            }  }
        </section>;
}
