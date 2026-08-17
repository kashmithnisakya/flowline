"""The step header both board layouts share: colour dot, name, overdue
signal and count. A legacy status column has no step colour, so it borrows
the kind's default and reads like the workflow legend in both themes.
"""

import from ..workflow.kinds { DOT_VAR, COUNT_TINT, colorKey }
import from ..ui.badge { Badge }

# Mirrors KIND_COLORS in constants.jac (kept local: see CLAUDE.md on
# glob-only modules and client exports).
glob KIND_DEFAULT: dict[str, str] = {
         "start": "sky",
         "active": "indigo",
         "handoff": "amber",
         "blocked": "rose",
         "done": "emerald"
     };


def kindDot(kind: str) -> str {
    return DOT_VAR[colorKey(KIND_DEFAULT[kind] if kind in KIND_DEFAULT else "slate")];
}


def:pub LaneHeader(
    label: str,
    kind: str,
    color: str = "",
    count: int = 0,
    overdueCount: int = 0,
    className: str = ""
) -> JsxElement {
    return
        <div
            className={"flex shrink-0 items-center justify-between px-1 py-1" + (
                (" " + className) if className else ""
            )}
        >
            <span className="flex min-w-0 items-center gap-1.5 text-sm font-semibold">
                <span
                    className="h-2 w-2 shrink-0 rounded-full"
                    style={{
                        "background": (
                            DOT_VAR[colorKey(color)] if color else kindDot(kind)
                        )
                    }}
                />
                <span className="truncate" title={label}>{label}</span>
            </span>
            <span className="flex shrink-0 items-center gap-1.5">
                {if overdueCount > 0 {
                    <span
                        key="overdue"
                        className="text-[11px] font-semibold tabular-nums text-destructive"
                        title={str(overdueCount) + " overdue"}
                    >
                        {str(overdueCount) + " over"}
                    </span>
                }}
                <Badge
                    variant="secondary"
                    className={"tabular-nums " + (
                        COUNT_TINT[colorKey(color)] if color else ""
                    )}
                    aria-label={str(count) + (" task" if count == 1 else " tasks")}
                >
                    {count}
                </Badge>
            </span>
        </div>;
}
