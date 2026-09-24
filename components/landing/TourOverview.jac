"""The tour's Overview: what needs someone now beside this week's figures,
as the Overview page lays them out. Sample data."""

import from .TourNeeds { TourNeeds }

glob WEEK: list[dict[str, str]] = [
         {"label": "moved to Done", "value": "6"},
         {"label": "tasks added", "value": "9"},
         {"label": "open tasks", "value": "23"},
         {"label": "blocked now", "value": "1"}
     ];

def:pub TourOverview -> JsxElement {
    return
        <div
            className="grid gap-6 rounded-3xl border bg-card p-4 sm:p-5 md:grid-cols-[minmax(0,3fr)_minmax(0,2fr)]"
        >
            <TourNeeds/>
            <div className="grid content-start gap-3">
                <h4 className="text-sm font-semibold">This week</h4>
                <dl className="grid grid-cols-2 gap-2.5">
                    {for w in WEEK {
                        <div
                            key={w["label"]}
                            className="flex flex-col gap-0.5 rounded-xl bg-muted/60 px-3.5 py-3"
                        >
                            <dd className="num text-2xl leading-8 font-semibold">
                                {w["value"]}
                            </dd>
                            <dt className="order-first text-xs text-muted-foreground">
                                {w["label"]}
                            </dt>
                        </div>
                    }}
                </dl>
            </div>
        </div>;
}
