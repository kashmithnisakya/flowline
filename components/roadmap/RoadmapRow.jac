"""One task on the roadmap: its status icon and title in the sticky column, its
bar across the weeks. The dates and any lateness live in the hover title and
the spoken label. `win` is the window Timeline measured."""

import from ...models { TaskRow }
import from ...lib.dates { prettyDay, dueTone, dueLabel }
import from ..common.StepBadge { StepIcon }
import from .LabelCell { LabelCell }
import from .RoadmapBar { RoadmapBar }
import from .TodayMark { TodayMark }

def:pub RoadmapRow(
    t: TaskRow,
    first: str,
    last: str,
    blocked: bool,
    color: str,
    kind: str,
    win: dict[str, any],
    onOpen: Callable[[str], None]
) -> JsxElement {
    today: str = win["today"];
    late = dueTone(t.due_date, t.status, today) == "overdue";
    lateWords = dueLabel(t.due_date, t.status, today) if late else "";
    dates = prettyDay(first)
        if first == last
        else prettyDay(first) + " to " + prettyDay(last);
    stuck = blocked and t.status != "Done";
    flags = (", " + lateWords if late else "") + (", blocked" if stuck else "");
    names = ", ".join(t.assignee_names);
    words = names + (", " if names and late else "");
    words = words + ("due " + prettyDay(t.due_date) if late else "");
    return
        <button
            type="button"
            data-task-card={t.id}
            className="group relative flex h-[34px] w-full items-center border-b border-border-subtle text-left outline-none"
            title={t.title + ": " + dates + flags}
            aria-label={"Open " + t.title + ", " + dates + flags}
            onClick={lambda { onOpen(t.id); }}
        >
            <span
                className="pointer-events-none absolute inset-0 z-30 hidden outline-2 -outline-offset-2 outline-ring outline-solid group-focus-visible:block"
                aria-hidden="true"
            />
            <LabelCell
                className="flex h-full items-center gap-2 group-hover:bg-[linear-gradient(var(--bg-hover),var(--bg-hover))]"
            >
                <StepIcon color={color} kind={kind}/>
                <span className="truncate text-[13px] font-medium">{t.title}</span>
            </LabelCell>
            <span className="relative h-full flex-1 group-hover:bg-bg-hover">
                <RoadmapBar
                    first={first}
                    last={last}
                    win={win}
                    who={words}
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
