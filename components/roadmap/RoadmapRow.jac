"""One task on the roadmap: its title and dates in the sticky column, its
bar across the weeks. Past due says so in words, not only in red. `win` is
the window Timeline measured (origin, total, fromDate, lastDay, today...)."""

import from ...models { TaskRow }
import from ...lib.dates { prettyDay, dueTone, dueLabel }
import from .LabelCell { LabelCell }
import from .RoadmapBar { RoadmapBar }
import from .TodayMark { TodayMark }

def:pub RoadmapRow(
    t: TaskRow,
    first: str,
    last: str,
    color: str,
    blocked: bool,
    win: dict[str, any],
    onOpen: Callable[[str], None]
) -> JsxElement {
    today: str = win["today"];
    late = dueTone(t.due_date, t.status, today) == "overdue";
    lateWords = dueLabel(t.due_date, t.status, today) if late else "";
    dates = prettyDay(first)
        if first == last
        else prettyDay(first) + " – " + prettyDay(last);
    return
        <button
            type="button"
            data-task-card={t.id}
            className="group relative flex h-11 w-full items-center text-left outline-none"
            title={t.title + " · " + dates}
            aria-label={"Open "
                + t.title
                + ", "
                + dates
                + (", " + lateWords if late else "")}
            onClick={lambda { onOpen(t.id); }}
        >
            <span
                className="pointer-events-none absolute inset-0 z-30 hidden rounded-md outline-2 -outline-offset-2 outline-ring outline-solid group-focus-visible:block"
                aria-hidden="true"
            />
            <LabelCell
                className="flex h-full flex-col justify-center gap-0.5 group-hover:bg-accent"
            >
                <span className="truncate text-[13.5px] leading-tight font-medium">
                    {t.title}
                </span>
                <span
                    className={"truncate font-mono text-xs leading-tight tabular-nums "
                        + (
                            "font-medium text-destructive"
                                if late
                                else "text-muted-foreground"
                        )}
                >
                    {(prettyDay(last) + " · " + lateWords) if late else dates}
                </span>
            </LabelCell>
            <span className="relative h-full flex-1 group-hover:bg-accent/60">
                <RoadmapBar
                    first={first}
                    last={last}
                    win={win}
                    color={color}
                    late={late}
                    done={t.status == "Done"}
                    blocked={blocked}
                />
                {if win["showToday"] {
                    <TodayMark key="today" left={win["todayLeft"]}/>
                }}
            </span>
        </button>;
}
