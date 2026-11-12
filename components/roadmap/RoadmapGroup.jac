"""One step's rows under a plain header bar: the step's icon and name, and how
many of its tasks are on the roadmap. `group` is a dict from the page (key,
name, color, kind, and items: {t, first, last}); data-step is the line bar's
jump target."""

import from ..common.StepBadge { StepIcon }
import from .RoadmapRow { RoadmapRow }

def:pub RoadmapGroup(
    group: dict[str, any], win: dict[str, any], onOpen: Callable[[str], None]
) -> JsxElement {
    color: str = group["color"];
    kind: str = group["kind"];
    items: list[dict[str, any]] = group["items"];
    blocked = kind == "blocked";
    return
        <div
            role="group"
            aria-label={group["name"]}
            data-step={group["key"]}
            className="scroll-mt-4 max-lg:scroll-mt-16"
        >
            <div
                className="relative flex h-9 items-center border-b border-border-subtle bg-bg-surface"
            >
                <span
                    className="sticky left-0 z-20 flex items-center gap-2 px-3 text-[13px] font-semibold"
                >
                    <StepIcon color={color} kind={kind}/>
                    {group["name"]}
                    <span className="num font-normal text-text-tertiary">
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
                    blocked={blocked or it["t"].status == "Blocked"}
                    color={color}
                    kind={kind}
                    win={win}
                    onOpen={onOpen}
                />
            }}
        </div>;
}
