"""One task on the board as a row: the title block, then the data cells
from lg up or a meta line below it, and the move button (top right on a
phone). RowShell makes it clickable, keyboard-driven and draggable."""

import from ...models { TaskRow }
import from .RowShell { RowShell }
import from .TaskTitle { TaskTitle }
import from .TaskCells { TaskCells, ROW_COLUMNS }
import from .TaskMetaLine { TaskMetaLine }
import from .RowMove { RowMove }
import from .GitHubChip { GitHubChip, suggestsDone }
import from .taskFacts { alertLine }

def:pub TaskLine(
    task: TaskRow,
    today: str,
    dot: str,
    selected: bool,
    columnKey: str,
    doneKey: str,
    # The board's columns for the move menu: keys, labels, colors, steps.
    route: dict[str, any],
    onOpen: Callable[[TaskRow], None],
    onMove: Callable[[TaskRow, str], None],
    onDropBeside: Callable[[str, str, bool], None]
) -> JsxElement {
    has moveOpen: bool = False;

    return
        <RowShell
            taskId={task.id}
            onOpen={lambda { onOpen(task); }}
            onMoveKey={lambda { moveOpen = True; }}
            onDropBeside={onDropBeside}
            className={"relative flex cursor-pointer flex-col gap-1 rounded-xl py-2.5 pr-11 pl-3 outline-none select-none hover:bg-accent/60 focus-visible:ring-2 focus-visible:ring-ring lg:grid lg:min-h-12 lg:items-center lg:gap-x-3 lg:py-1.5 lg:pr-3 "
                + ROW_COLUMNS
                + (" bg-accent" if selected else "")}
        >
            <TaskTitle task={task} dot={dot} alert={alertLine(task, today)}/>
            <TaskMetaLine task={task} today={today}/>
            <span className="hidden lg:contents">
                <TaskCells task={task} today={today} color={dot}/>
            </span>
            <span className="absolute top-1.5 right-1.5 lg:static">
                <RowMove
                    task={task}
                    open={moveOpen}
                    onOpenChange={lambda (o: bool) { moveOpen = o; }}
                    columnKey={columnKey}
                    route={route}
                    onMove={onMove}
                />
            </span>
            {if suggestsDone(task) and doneKey {
                <div key="merged" className="pl-5 lg:col-span-full lg:pl-10">
                    <GitHubChip
                        task={task}
                        onMarkDone={lambda (tid: str) { onMove(task, doneKey); }}
                    />
                </div>
            }}
        </RowShell>;
}
