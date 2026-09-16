"""The week as a rail of days with their entry counts: a column beside the log
on a wide screen, a scrolling row above it on a phone. The selected day gets
a 2px primary bar (Day view only) and today's name is set in primary. An empty
weekend folds into one row.
"""

glob DAY_SHORT: list[str] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
     MONTH_SHORT: list[str] = [
         "Jan",
         "Feb",
         "Mar",
         "Apr",
         "May",
         "Jun",
         "Jul",
         "Aug",
         "Sep",
         "Oct",
         "Nov",
         "Dec"
     ];

# ["2026-09-14", ..., "2026-09-20"] -> "14 to 20 Sep" ("28 Sep to 4 Oct").
def weekLabel(days: list[str]) -> str {
    first = days[0];
    last = days[len(days) - 1];
    a = str(int(first[8:10]));
    b = str(int(last[8:10]));
    ma = MONTH_SHORT[int(first[5:7]) - 1];
    mb = MONTH_SHORT[int(last[5:7]) - 1];
    if ma == mb {
        return a + " to " + b + " " + mb;
    }
    return a + " " + ma + " to " + b + " " + mb;
}


def:pub DayRail(
    weekDays: list[str],
    counts: list[int],
    selectedDate: str,
    today: str,
    viewMode: str,
    onSelectDate: Callable[[str], None]
) -> JsxElement {
    has scroller: Ref[any] = Ref();

    # Keep the picked day in view when the phone row scrolls sideways, moving
    # only as far as it takes so Monday stays put while it fits.
    can with [selectedDate, viewMode] entry {
        box = scroller.current;
        if box and box.scrollWidth > box.clientWidth {
            picked = box.querySelector("[aria-pressed=true]");
            if picked {
                pr = picked.getBoundingClientRect();
                br = box.getBoundingClientRect();
                if pr.left < br.left {
                    box.scrollLeft = box.scrollLeft - (br.left - pr.left) - 8;
                } elif pr.right > br.right {
                    box.scrollLeft = box.scrollLeft + (pr.right - br.right) + 8;
                }
            }
        }
    }

    if len(weekDays) < 7 {
        return <nav className="hidden"/>;
    }
    weekend = weekDays[5:];
    foldWeekend = (
        counts[5] == 0
        and counts[6] == 0
        and selectedDate not in weekend
        and today not in weekend
    );
    shown = [
        i
        for i in range(7)
        if i < 5 or not foldWeekend
    ];
    return
        <nav
            aria-label="Days"
            className="surface min-w-0 p-1.5 lg:sticky lg:top-20 lg:self-start lg:p-2.5"
        >
            <p
                className="num hidden px-1 pb-2 text-[12.5px] font-medium text-foreground lg:block"
            >
                {weekLabel(weekDays)}
            </p>
            <div
                ref={scroller}
                className="flex gap-1 overflow-x-auto lg:grid lg:gap-0.5 lg:overflow-visible"
            >
                {for i in shown {
                    <button
                        key={weekDays[i]}
                        type="button"
                        aria-pressed={"true"
                            if viewMode == "day" and weekDays[i] == selectedDate
                            else "false"}
                        aria-label={DAY_SHORT[i]
                            + " "
                            + str(int(weekDays[i][8:10]))
                            + (", today" if weekDays[i] == today else "")
                            + ", "
                            + str(counts[i])
                            + (" entry" if counts[i] == 1 else " entries")}
                        className={"flex min-w-[4.75rem] shrink-0 flex-col items-start rounded-md px-2.5 py-1.5 text-left text-[13.5px] whitespace-nowrap transition-colors lg:min-w-0 lg:flex-row lg:items-center lg:justify-between lg:gap-3 lg:px-2 lg:py-[7px] "
                            + (
                                "bg-accent font-semibold text-foreground shadow-[inset_0_-2px_0_var(--primary)] lg:shadow-[inset_2px_0_0_var(--primary)]"
                                    if viewMode == "day" and weekDays[i] == selectedDate
                                    else (
                                        "font-semibold text-primary hover:bg-accent"
                                            if weekDays[i] == today
                                            else "text-muted-foreground hover:bg-accent hover:text-foreground"
                                    )
                            )}
                        onClick={lambda { onSelectDate(weekDays[i]); }}
                    >
                        <span>{DAY_SHORT[i] + " " + str(int(weekDays[i][8:10]))}</span>
                        <span
                            className={"num min-h-4 text-xs leading-4 font-normal "
                                + (
                                    "text-muted-foreground"
                                        if viewMode == "day"
                                            and weekDays[i] == selectedDate
                                        else "text-subtle"
                                )}
                        >
                            {str(counts[i]) if counts[i] > 0 else ""}
                        </span>
                    </button>
                }}
                {if foldWeekend {
                    <button
                        key="weekend"
                        type="button"
                        aria-pressed="false"
                        className="flex min-w-[4.75rem] shrink-0 items-center rounded-md px-2.5 py-1.5 text-left text-[12.5px] text-subtle transition-colors hover:bg-accent hover:text-foreground lg:min-w-0 lg:px-2 lg:py-[7px]"
                        onClick={lambda { onSelectDate(weekDays[5]); }}
                    >
                        Weekend
                    </button>
                }}
            </div>
        </nav>;
}
