"""The Overview's charts over time, scoped by their own filter row. Drawn in
the first-load frame too, so the heading and `filters` never move; `history`
is None until the first read lands. A refetch keeps the charts, dimmed."""

import from .HistoryTable { HistoryTable }
import from .BurnUpChart { BurnUpChart }
import from .ThroughputChart { ThroughputChart }
import from .Panel { Panel }
import from ..ui.skeleton { Skeleton }
import from ..common.LoadFailed { LoadFailed }
import from ..common.Busy { Busy }
import from ...lib.dates { prettyDay }

def total(xs: list[int]) -> int {
    n = 0;
    for x in xs {
        n = n + x;
    }
    return n;
}

def:pub OverTime(
    history: any, filters: any, loading: bool, failed: bool, onRetry: any
) -> JsxElement {
    labels = [prettyDay(w) for w in history.weeks] if history else [];
    return
        <section className="min-w-0 space-y-3" aria-labelledby="over-time">
            <div className="flex flex-wrap items-center gap-2">
                <h2 id="over-time" className="section-title mr-auto">Over time</h2>
                <Busy active={loading and bool(history)}/>
                {filters}
            </div>
            {if failed and not history {
                <LoadFailed
                    key="fail"
                    title="Could not load the charts"
                    onRetry={onRetry}
                />
            } elif not history {
                <div key="sk" className="grid gap-4 @min-[52rem]:grid-cols-2">
                    <Skeleton className="h-72 w-full rounded-[20px]"/>
                    <Skeleton className="h-72 w-full rounded-[20px]"/>
                </div>
            } elif total(history.scope) == 0 {
                <Panel
                    key="empty"
                    id="over-time-empty"
                    title="No tasks in this range yet"
                >
                    <p className="text-sm text-muted-foreground">
                        The charts fill in as tasks are added and moved to Done.
                    </p>
                </Panel>
            } else {
                <div
                    key="charts"
                    className={"space-y-3 transition-opacity "
                        + ("opacity-60" if loading else "")}
                    aria-busy={loading}
                >
                    <div
                        className="grid gap-4 @min-[52rem]:grid-cols-2 @min-[52rem]:items-start"
                    >
                        <BurnUpChart
                            labels={labels}
                            scope={history.scope}
                            done={history.done}
                        />
                        {if total(history.finished) > 0 {
                            <ThroughputChart
                                key="tp"
                                labels={labels}
                                finished={history.finished}
                                added={history.added}
                            />
                        } else {
                            <Panel key="tpnone" id="throughput" title="Done per week">
                                <p className="text-sm text-muted-foreground">
                                    Nothing moved to Done in these weeks, so there are no bars to draw.
                                </p>
                            </Panel>
                        } }
                    </div>
                    <HistoryTable
                        labels={labels}
                        added={history.added}
                        finished={history.finished}
                        scope={history.scope}
                        done={history.done}
                    />
                </div>
            }   }
        </section>;
}
