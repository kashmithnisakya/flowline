"""In the Overview's History: each person's task updates this week as a Monday
to Sunday strip (byDay). Days ahead are empty; today carries a primary ring."""

import from .Panel { Panel }
import from ..common.Avatar { Avatar }
import from ..ui.skeleton { Skeleton }

# A day cell's fill by update count: none, one, two or three, four and up.
def dayFill(count: int) -> str {
    if count <= 0 {
        return "transparent";
    }
    mix = "45%" if count == 1 else ("70%" if count <= 3 else "90%");
    return "color-mix(in oklab, var(--series-done) " + mix + ", var(--card))";
}

def DayStrip(byDay: list[int], dayNames: list[str], todayIndex: int) -> JsxElement {
    return
        <span className="inline-flex shrink-0 gap-1">
            {for (di, name) in enumerate(dayNames) {
                <span
                    key={name}
                    title={name
                        + (
                            ": ahead"
                                if di > todayIndex
                                else ": " + str(byDay[di]) + " updates"
                        )}
                    className={"size-3.5 rounded-[4px] border border-input"
                        + (
                            " outline outline-[1.5px] outline-offset-1 outline-primary"
                                if di == todayIndex
                                else ""
                        )}
                    style={{
                        "background": "transparent"
                            if di > todayIndex
                            else dayFill(byDay[di])
                    }}
                />
            }}
        </span>;
}

def:pub PeopleUpdates(
    rows: list[dict[str, any]],
    dayNames: list[str],
    todayIndex: int,
    placeholder: bool = False,
    placeholderRows: int = 5
) -> JsxElement {
    return
        <Panel
            id="updates-h"
            title="Updates this week"
            aside={<span className="meta">Mon to Sun</span>}
            busy={placeholder}
        >
            <ul className="flex flex-col gap-2.5">
                {for i in range(placeholderRows if placeholder else 0) {
                    <li key={"ph" + str(i)}>
                        <Skeleton className="h-6 w-full"/>
                    </li>
                }}
                {for r in rows {
                    <li key={r["id"]} className="flex items-center gap-2.5">
                        <Avatar name={r["name"]} color={r["color"]} size="sm"/>
                        <span className="min-w-0 flex-1 truncate text-[13px]">
                            {r["name"]}
                        </span>
                        <DayStrip
                            byDay={r["byDay"]}
                            dayNames={dayNames}
                            todayIndex={todayIndex}
                        />
                    </li>
                }}
            </ul>
            {if len(rows) == 0 and not placeholder {
                <p key="none" className="text-[13px] text-text-secondary">
                    No active people.
                </p>
            }}
        </Panel>;
}
