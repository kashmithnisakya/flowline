"""The Overview's four figures in one panel, two by two when narrow. `figures`
rows are label, value and alarm (a number that needs someone reads in danger);
`placeholder` keeps the labels and draws a block for each value."""

import from ..ui.skeleton { Skeleton }

glob FIGURE_LABELS: list[str] = [
         "Done this week",
         "Added this week",
         "Open",
         "Overdue"
     ],
     # Hairlines between cells, per cell, for both the 2 and the 4 column grid.
     RULES: list[str] = [
         "border-r border-b @min-[36rem]:border-b-0",
         "border-b @min-[36rem]:border-r @min-[36rem]:border-b-0",
         "border-r",
         ""
     ];

def:pub OverviewFigures(
    figures: list[dict[str, any]], placeholder: bool = False
) -> JsxElement {
    cells = [{"label": l, "value": "", "alarm": False} for l in FIGURE_LABELS]
        if placeholder
        else figures;
    return
        <dl
            className="surface grid grid-cols-2 rounded-xl @min-[36rem]:grid-cols-4"
            aria-busy={placeholder}
        >
            {for (i, c) in enumerate(cells) {
                <div
                    key={c["label"]}
                    className={"border-border-subtle px-4 py-3.5 " + RULES[i]}
                >
                    <dt className="meta">{c["label"]}</dt>
                    <dd
                        className={"page-title num text-[26px] "
                            + ("text-danger" if c["alarm"] else "")}
                    >
                        {c["value"] or <Skeleton className="my-1.5 h-5 w-10"/>}
                    </dd>
                </div>
            }}
        </dl>;
}
