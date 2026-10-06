"""The first-load rows: the step groups the last loaded roadmap had in this
browser (ROADMAP_SHAPE_KEY, rows per group), else one group of `fallback`,
at the real row height so nothing moves when the data lands."""

import from ...lib.session { ROADMAP_SHAPE_KEY }
import from ..ui.skeleton { Skeleton }
import from .LabelCell { LabelCell }

glob PH_WIDTHS: list[str] = ["w-3/5", "w-2/5", "w-1/2", "w-[70%]"],
     PH_LEFT: list[str] = ["18%", "31%", "26%", "44%", "52%", "38%", "61%", "35%"],
     PH_BAR: list[str] = ["24px", "24px", "9%", "24px", "24px", "6%", "24px", "24px"];

def cachedGroups(fallback: int) -> list[int] {
    try {
        raw = localStorage.getItem(ROADMAP_SHAPE_KEY) or "";
        parsed: any = JSON.parse(raw) if raw else [];
        out: list[int] = [];
        total = 0;
        for n in parsed {
            m = int(n) if n else 0;
            m = 1 if m < 1 else (12 if m > 12 else m);
            if len(out) < 6 and total + m <= 30 {
                out.append(m);
                total = total + m;
            }
        }
        return out if len(out) > 0 else [fallback];
    } except Exception {
        return [fallback];
    }
}

def:pub RoadmapSkeleton(fallback: int) -> JsxElement {
    return
        <div aria-hidden="true">
            {for (gi, n) in enumerate(cachedGroups(fallback)) {
                <div key={"pg" + str(gi)} className="pt-3">
                    <div
                        className="relative flex h-9 items-center rounded-lg bg-muted px-2"
                    >
                        <Skeleton className="h-6 w-28 rounded-md"/>
                    </div>
                    {for i in range(n) {
                        <div
                            key={"ph" + str(i)}
                            className="flex h-11 w-full items-center"
                        >
                            <LabelCell
                                className="flex h-full flex-col justify-center gap-1"
                            >
                                <Skeleton
                                    className={"h-3.5 " + PH_WIDTHS[(gi + i) % 4]}
                                />
                                <Skeleton className="h-3 w-24"/>
                            </LabelCell>
                            <span className="relative h-full flex-1">
                                <Skeleton
                                    className="absolute top-1/2 h-4 -translate-y-1/2 rounded-md"
                                    style={{
                                        "left": PH_LEFT[(gi * 3 + i) % 8],
                                        "width": PH_BAR[(gi * 3 + i) % 8]
                                    }}
                                />
                            </span>
                        </div>
                    }}
                </div>
            }}
        </div>;
}
