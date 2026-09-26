"""One person on the Overview (id, name, color, open, done, byDay, total):
open work, Done this week, and a Monday to Sunday strip of the task updates
logged against them. Days ahead are dashed; today carries a primary ring."""

import from ..common.Avatar { Avatar }

glob PEOPLE_COLS: str = "grid grid-cols-[minmax(0,1fr)_auto] items-center gap-3 @min-[34rem]:grid-cols-[minmax(0,1fr)_3.5rem_6.5rem_9rem]";

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
        <span className="inline-flex gap-1" role="cell">
            {for (di, name) in enumerate(dayNames) {
                <span
                    key={name}
                    title={name
                        + (
                            ": ahead"
                                if di > todayIndex
                                else ": " + str(byDay[di]) + " updates"
                        )}
                    className={"size-3.5 rounded-[4px] border "
                        + ("border-input" if di > todayIndex else "border-input/60")
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

def:pub PeopleHeader -> JsxElement {
    return
        <div
            className={PEOPLE_COLS
                + " px-2 pb-1 text-xs text-muted-foreground @max-[34rem]:hidden"}
            role="row"
        >
            <span role="columnheader">Name</span>
            <span role="columnheader" className="text-right">Open</span>
            <span role="columnheader" className="text-right">Done this week</span>
            <span role="columnheader">Updates, Mon to Sun</span>
        </div>;
}

def:pub PersonRow(
    row: dict[str, any], dayNames: list[str], todayIndex: int
) -> JsxElement {
    return
        <div
            className={PEOPLE_COLS + " rounded-xl px-2 py-2 text-sm hover:bg-accent/60"}
            role="row"
        >
            <span className="flex min-w-0 items-center gap-3" role="cell">
                <Avatar name={row["name"]} color={row["color"]} size="md"/>
                <span className="min-w-0">
                    <span className="block truncate font-medium">{row["name"]}</span>
                    <span
                        className="block truncate text-xs text-muted-foreground @min-[34rem]:hidden"
                    >
                        {str(row["open"])
                            + " open · "
                            + str(row["done"])
                            + " done this week"}
                    </span>
                </span>
            </span>
            <span className="num text-right @max-[34rem]:hidden" role="cell">
                {str(row["open"])}
            </span>
            <span className="num text-right @max-[34rem]:hidden" role="cell">
                {str(row["done"])}
            </span>
            <DayStrip byDay={row["byDay"]} dayNames={dayNames} todayIndex={todayIndex}/>
        </div>;
}
