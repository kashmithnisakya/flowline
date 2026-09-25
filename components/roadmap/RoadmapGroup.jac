"""One step's rows under a plain header bar: the step as its icon and name, and
how many of its tasks are on the roadmap. `group` is a dict from the page
(key, name, color, kind, and items: {t, first, last} per task)."""

import from ..common.StepBadge { StepBadge }
import from .RoadmapRow { RoadmapRow }

def:pub RoadmapGroup(
    group: dict[str, any], win: dict[str, any], onOpen: Callable[[str], None]
) -> JsxElement {
    color: str = group["color"];
    items: list[dict[str, any]] = group["items"];
    blocked = group["kind"] == "blocked";
    return
        <div role="group" aria-label={group["name"]} className="pt-3">
            <div className="relative flex h-9 items-center rounded-md bg-bg-surface">
                <span className="sticky left-0 z-20 flex items-center gap-2 px-2">
                    <StepBadge
                        name={group["name"]}
                        color={color}
                        kind={group["kind"]}
                        size="sm"
                    />
                    <span className="num text-[13px] text-text-tertiary">
                        {str(len(items))}
                    </span>
                </span>
            </div>
            {for it in items {
                <RoadmapRow
                    key={it["t"].id}
                    t={it["t"]}
                    first={it["first"]}
                    last={it["last"]}
                    color={color}
                    blocked={blocked or it["t"].status == "Blocked"}
                    win={win}
                    onOpen={onOpen}
                />
            }}
        </div>;
}
