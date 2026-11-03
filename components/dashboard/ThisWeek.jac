"""This week by day, in the Overview's History: moves to Done per day
(`chartState` is chart, loading or none, with `chartNote` under it). A `note`
stands alone instead, as on a first run with nothing to count."""

import from .Panel { Panel }
import from .DayChart { DayChart }
import from ..ui.skeleton { Skeleton }

def:pub ThisWeek(
    days: list[dict[str, any]],
    chartState: str = "chart",
    chartNote: str = "",
    note: str = "",
    placeholder: bool = False
) -> JsxElement {
    return
        <Panel id="this-week" title="This week" busy={placeholder}>
            {if note {
                <p key="note" className="text-[13px] text-text-secondary">{note}</p>
            } else {
                <div key="body">
                    {if chartState == "chart" and not placeholder {
                        <DayChart key="chart" days={days}/>
                    } elif chartState != "none" {
                        <Skeleton key="sk" className="h-[124px] w-full rounded-md"/>
                    } }
                    <p className="meta mt-2.5">{chartNote}</p>
                </div>
            } }
        </Panel>;
}
