"""The Overview's "This week" panel: four figures as soft tiles, two by two,
then moves to Done per day (`chartState` is chart, loading or none). An
empty `figures` shows `note` instead."""

import from .Panel { Panel }
import from .DayChart { DayChart }
import from ..ui.skeleton { Skeleton }

glob FIGURE_LABELS: list[str] = [
         "moved to Done",
         "tasks added",
         "open tasks",
         "blocked now"
     ];

def Tile(label: str, value: str) -> JsxElement {
    return
        <div className="flex flex-col gap-0.5 rounded-xl bg-muted/60 px-3.5 py-3">
            <dd className="num text-2xl leading-8 font-semibold">
                {value or <Skeleton className="my-2 h-4 w-8"/>}
            </dd>
            <dt className="order-first text-xs text-muted-foreground">{label}</dt>
        </div>;
}

def:pub ThisWeek(
    figures: list[dict[str, any]],
    days: list[dict[str, any]],
    chartState: str = "chart",
    chartNote: str = "",
    note: str = "",
    placeholder: bool = False
) -> JsxElement {
    tiles = [{"label": l, "value": ""} for l in FIGURE_LABELS]
        if placeholder
        else figures;
    return
        <Panel id="this-week" title="This week" busy={placeholder}>
            {if len(tiles) == 0 {
                <p key="note" className="text-sm text-muted-foreground">{note}</p>
            } else {
                <div key="body">
                    <dl className="grid grid-cols-2 gap-2.5">
                        {for t in tiles {
                            <Tile
                                key={t["label"]}
                                label={t["label"]}
                                value={t["value"]}
                            />
                        }}
                    </dl>
                    {if chartState == "chart" and not placeholder {
                        <DayChart key="chart" days={days}/>
                    } elif chartState != "none" {
                        <Skeleton
                            key="sk"
                            className="mt-5 h-[124px] w-full rounded-xl"
                        />
                    } }
                    <p
                        className="mt-3 flex flex-wrap items-baseline gap-x-2 text-xs text-muted-foreground"
                    >
                        {chartNote}
                    </p>
                </div>
            } }
        </Panel>;
}
