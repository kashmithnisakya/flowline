"""The Overview's quieter History, under the worklist: the burn-up and its table,
scoped by `filters`, beside the panels in `children` (projects, this week by
day, people's updates). `history` is None until the first read lands; drawn in
the first-load frame too, so the heading and `filters` never move."""

import from .HistoryTable { HistoryTable }
import from .BurnUpChart { BurnUpChart }
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
    history: any,
    filters: any,
    loading: bool,
    failed: bool,
    onRetry: any,
    children: any = None
) -> JsxElement {
    labels = [prettyDay(w) for w in history.weeks] if history else [];
    filled = bool(history) and total(history.scope if history else []) > 0;
    return
        <section
            className="min-w-0 space-y-3 border-t border-border-subtle pt-5"
            aria-labelledby="over-time"
        >
            <div className="flex flex-wrap items-center gap-2">
                <h2
                    id="over-time"
                    className="section-title mr-auto text-sm text-text-secondary"
                >
                    History
                </h2>
                <Busy active={loading and bool(history)}/>
                {filters}
            </div>
            <div
                className="grid gap-4 @min-[52rem]:grid-cols-2 @min-[52rem]:items-start"
            >
                {if failed and not history {
                    <LoadFailed
                        key="fail"
                        title="Could not load the charts"
                        onRetry={onRetry}
                    />
                } elif not history {
                    <Skeleton key="sk" className="h-72 w-full rounded-xl"/>
                } elif not filled {
                    <Panel
                        key="empty"
                        id="over-time-empty"
                        title="No tasks in this range yet"
                    >
                        <p className="text-[13px] text-text-secondary">
                            The charts fill in as tasks are added and moved to Done.
                        </p>
                    </Panel>
                } else {
                    <div
                        key="burn"
                        className={"min-w-0 transition-opacity "
                            + ("opacity-60" if loading else "")}
                        aria-busy={loading}
                    >
                        <BurnUpChart
                            labels={labels}
                            scope={history.scope}
                            done={history.done}
                        />
                    </div>
                }   }
                {children}
            </div>
            {if filled {
                <HistoryTable
                    key="table"
                    labels={labels}
                    added={history.added}
                    finished={history.finished}
                    scope={history.scope}
                    done={history.done}
                />
            }}
        </section>;
}
