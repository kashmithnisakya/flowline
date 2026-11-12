"""Done per week across every project, the last eight weeks whatever the History
filters say. `pending` is the first read in flight; `failed` offers a retry; a
range with nothing done says so rather than drawing an empty plot."""

import from .Panel { Panel, PANEL_LINK }
import from .WeekBars { WeekBars }
import from ..ui.skeleton { Skeleton }

def:pub ThroughputChart(
    labels: list[str],
    finished: list[int],
    added: list[int],
    pending: bool = False,
    failed: bool = False,
    onRetry: any = None
) -> JsxElement {
    anyDone = False;
    for v in finished {
        if v > 0 {
            anyDone = True;
        }
    }
    return
        <Panel
            id="throughput"
            title="Done per week"
            aside={<span className="meta">Last 8 weeks</span>}
            busy={pending}
        >
            {if failed {
                <p key="fail" className="text-[13px] text-text-secondary" role="status">
                    {"Could not load the weeks. "}
                    <button
                        type="button"
                        className={PANEL_LINK}
                        onClick={lambda { if onRetry { onRetry(); }}}
                    >
                        Try again
                    </button>
                </p>
            } elif pending {
                <Skeleton key="sk" className="h-[150px] w-full rounded-md"/>
            } elif anyDone {
                <WeekBars key="bars" labels={labels} finished={finished} added={added}/>
            } else {
                <p key="none" className="text-[13px] text-text-secondary">
                    Nothing moved to Done in these weeks, so there are no bars to draw.
                </p>
            }   }
        </Panel>;
}
