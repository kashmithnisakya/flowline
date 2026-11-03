"""The board toolbar: one Filter menu (active filters read as chips after it),
the slot for saved sets, then the title filter, Display and the count on the
right. Below md it folds into the title filter plus a Filters button."""

import from ...models { MemberView }
import from ..ui.button { Button }
import from .BoardSearch { BoardSearch }
import from .DisplayMenu { DisplayMenu }
import from .FilterMenu { FilterMenu, optionLabel }
import from .FilterSheet { FilterSheet }

def:pub FilterBar(
    members: list[MemberView],
    project: str,
    assignee: str,
    category: str,
    hideDone: bool,
    onAssignee: Callable[[str], None],
    onCategory: Callable[[str], None],
    onHideDone: Callable[[], None],
    categories: list[str] = [],
    tags: list[str] = [],
    tag: str = "All",
    estimate: str = "All",
    onTag: Callable[[str], None] = None,
    onEstimate: Callable[[str], None] = None,
    priority: str = "All",
    onPriority: Callable[[str], None] = None,
    query: str = "",
    onQuery: Callable[[str], None] = None,
    onClear: Callable[[], None] = None,
    shownCount: int = 0,
    hiddenCount: int = 0,
    doneDays: int = 7,
    hideEmpty: bool = False,
    onHideEmpty: Callable[[], None] = None,
    onExpandAll: Callable[[], None] = None,
    onCollapseAll: Callable[[], None] = None,
    # The saved sets menu, which the board owns.
    sets: any = None
) -> JsxElement {
    has sheetOpen: bool = False;

    people: list[list[str]] = [["All", "Everyone"]];
    for m in members {
        if not project or project in m.project_ids {
            people.append([m.id, m.name]);
        }
    }
    cats: list[list[str]] = [["All", "All categories"]];
    for c in categories {
        cats.append([c, c]);
    }
    tagRows: list[list[str]] = [["All", "All tags"]];
    for tg in tags {
        tagRows.append([tg, tg]);
    }
    facets: list[dict[str, any]] = [
        {
            "label": "People",
            "value": assignee,
            "options": people,
            "onChange": onAssignee
        },
        {
            "label": "Priority",
            "value": priority,
            "options": [
                ["All", "Any priority"],
                ["High", "High"],
                ["Medium", "Medium"],
                ["Low", "Low"]
            ],
            "onChange": onPriority
        },
        {
            "label": "Category",
            "value": category,
            "options": cats,
            "onChange": onCategory
        },
        {"label": "Tag", "value": tag, "options": tagRows, "onChange": onTag},
        {
            "label": "Estimate",
            "value": estimate,
            "options": [
                ["All", "Any estimate"],
                ["yes", "Estimated"],
                ["no", "Unestimated"]
            ],
            "onChange": onEstimate
        }
    ];
    active = [
        f
        for f in facets
        if f["value"] != "All"
    ];
    picked = len(active);
    anything = picked > 0 or bool(query.strip());
    countLabel = str(shownCount) + (" task" if shownCount == 1 else " tasks");
    if hiddenCount > 0 and anything {
        countLabel = countLabel + ", " + str(hiddenCount) + " hidden";
    }
    doneLabel = "Done from last " + str(doneDays) + " days";

    return
        <div className="min-w-0 flex-1">
            <div className="hidden flex-wrap items-center gap-2 md:flex">
                <FilterMenu
                    facets={facets}
                    picked={picked}
                    anything={anything}
                    onClear={onClear}
                />
                {sets}
                {for f in active {
                    <button
                        key={f["label"]}
                        type="button"
                        className="toolbar-filter gap-1!"
                        data-active="true"
                        aria-label={"Clear the " + f["label"].lower() + " filter"}
                        onClick={lambda { f["onChange"]("All"); }}
                    >
                        <span className="max-w-44 truncate">
                            {f["label"] + ": " + optionLabel(f["options"], f["value"])}
                        </span>
                        <span aria-hidden="true" className="text-subtle">×</span>
                    </button>
                }}
                <div className="ml-auto flex items-center gap-2">
                    <BoardSearch query={query} onQuery={onQuery} className="w-[210px]"/>
                    <DisplayMenu
                        hideDone={hideDone}
                        hideEmpty={hideEmpty}
                        doneLabel={doneLabel}
                        onHideDone={onHideDone}
                        onHideEmpty={onHideEmpty}
                        onExpandAll={onExpandAll}
                        onCollapseAll={onCollapseAll}
                    />
                    <span className="num text-xs whitespace-nowrap text-text-tertiary">
                        {countLabel}
                    </span>
                </div>
            </div>
            <div className="flex items-center gap-2 md:hidden">
                <BoardSearch
                    query={query}
                    onQuery={onQuery}
                    className="h-11 min-w-0 flex-1"
                />
                <Button
                    variant="outline"
                    className="h-11 shrink-0 gap-1.5"
                    onClick={lambda { sheetOpen = True; }}
                >
                    Filters
                    {if picked > 0 {
                        <span key="n" className="num text-xs text-muted-foreground">
                            {str(picked)}
                        </span>
                    }}
                </Button>
            </div>
            <FilterSheet
                open={sheetOpen}
                facets={facets}
                hideDone={hideDone}
                doneLabel={doneLabel}
                countLabel={countLabel}
                anything={anything}
                onOpenChange={lambda (o: bool) { sheetOpen = o; }}
                onHideDone={onHideDone}
                onClear={onClear}
            />
        </div>;
}
