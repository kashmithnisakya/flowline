"""This week's moves to Done, one column per day. `days` rows are dicts:
name, label, value, future (outlined, never drawn as zero) and today (the
label turns primary and reads "Today")."""

import from .ChartAxes { niceTop, YAxis, Gridlines }

def:pub DayChart(days: list[dict[str, any]]) -> JsxElement {
    past = [
        d
        for d in days
        if not d["future"]
    ];
    values = [d["value"] for d in past];
    top = niceTop(values);
    spoken = ", ".join([d["name"] + " " + str(d["value"]) for d in past]);
    return
        <div role="img" aria-label={"Tasks moved to Done: " + spoken + " so far"}>
            <div className="flex gap-2 pt-6">
                <YAxis values={values} plotH="h-24"/>
                <div className="relative h-24 flex-1">
                    <Gridlines/>
                    <div
                        className="absolute inset-0 flex gap-2 px-1"
                        aria-hidden="true"
                    >
                        {for d in days {
                            <div
                                key={d["name"]}
                                className="relative flex h-full flex-1 items-end justify-center"
                            >
                                {if d["future"] {
                                    <div
                                        key="ahead"
                                        className="h-3.5 w-full max-w-9 rounded-[4px] border border-dashed border-input"
                                    />
                                } else {
                                    <div
                                        key="bar"
                                        className={"w-full max-w-9 rounded-t-[4px] "
                                            + (
                                                "bg-series-done"
                                                    if d["value"] > 0
                                                    else ""
                                            )}
                                        style={{
                                            "height": str(d["value"] * 100.0 / top)
                                                + "%"
                                        }}
                                    />
                                } }
                                {if not d["future"] {
                                    <span
                                        key="val"
                                        className={"absolute mb-0.5 num text-xs "
                                            + ("" if d["value"] > 0 else "text-subtle")}
                                        style={{
                                            "bottom": str(d["value"] * 100.0 / top)
                                                + "%"
                                        }}
                                    >
                                        {str(d["value"])}
                                    </span>
                                }}
                            </div>
                        }}
                    </div>
                </div>
            </div>
            <div className="mt-1.5 ml-9 flex gap-2 px-1 text-xs" aria-hidden="true">
                {for d in days {
                    <span
                        key={d["name"]}
                        className={"flex-1 text-center whitespace-nowrap "
                            + (
                                "font-semibold text-primary"
                                    if d["today"]
                                    else "num text-subtle"
                            )}
                    >
                        {"Today" if d["today"] else d["label"]}
                    </span>
                }}
            </div>
        </div>;
}
