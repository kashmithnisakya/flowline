"""The work sitting on one step, floated over the diagram in view mode (a
bottom sheet on phones). Rows are buttons: clicking one opens the board's task
dialog, so the panel is a way into the work rather than a read-only list."""

import from ...models { StepView, TaskRow }
import from ...lib.dates { todayIso }
import from .StepPanelHead { StepPanelHead }
import from .StepTaskRow { StepTaskRow }
import from ..ui.skeleton { Skeleton }

def:pub StepTasksPanel(
    step: StepView,
    tasks: list[TaskRow],
    loading: bool,
    scope: str,
    className: str = "",
    # The rows are one page of the step; `total` is the whole step, so the
    # header keeps counting all of it while the list grows on demand.
    total: int = 0,
    hasMore: bool = False,
    loadingMore: bool = False,
    # A bottom sheet brings its own close button.
    closable: bool = True,
    onMore: Callable[[], None] = None,
    onOpenTask: Callable[[str], None] = None,
    onClose: Callable[[], None] = None
) -> JsxElement {
    count = total if total > len(tasks) else len(tasks);
    today = todayIso();
    moreText = "Show more (" + str(len(tasks)) + " of " + str(count) + ")";
    return
        <div
            data-panel="step-tasks"
            className={"pointer-events-auto flex max-h-full min-h-0 flex-col bg-card "
                + className}
            onClick={lambda (e: MouseEvent) { e.stopPropagation(); }}
        >
            <StepPanelHead
                step={step}
                count={count}
                loading={loading}
                scope={scope}
                closable={closable}
                onClose={onClose}
            />
            <div className="flex min-h-0 flex-1 flex-col overflow-y-auto p-1.5">
                {if loading {
                    <div key="loading" className="flex flex-col">
                        {for w in ["w-3/5", "w-1/2", "w-2/3"] {
                            <div key={w} className="flex flex-col gap-2 px-2.5 py-2.5">
                                <Skeleton className={"h-4 " + w}/>
                                <Skeleton className="h-3 w-2/5"/>
                            </div>
                        }}
                    </div>
                } elif len(tasks) == 0 {
                    <p
                        key="empty"
                        className="px-4 py-8 text-center text-sm text-muted-foreground"
                    >
                        Nothing is sitting on this step.
                    </p>
                } else {
                    <ul key="rows" className="flex flex-col gap-0.5">
                        {for t in tasks {
                            <li key={t.id}>
                                <StepTaskRow
                                    task={t}
                                    today={today}
                                    onOpen={onOpenTask}
                                />
                            </li>
                        }}
                        {if hasMore or loadingMore {
                            <li key="more" className="px-1 py-1.5">
                                <button
                                    type="button"
                                    disabled={loadingMore}
                                    className="num w-full rounded-full py-1.5 text-xs text-muted-foreground transition-colors hover:bg-accent hover:text-foreground disabled:opacity-60"
                                    onClick={lambda { if onMore { onMore(); }}}
                                >
                                    {"Loading" if loadingMore else moreText}
                                </button>
                            </li>
                        }}
                    </ul>
                }  }
            </div>
            <div className="flex justify-end border-t px-4 py-2.5 text-[13px]">
                <a
                    href="/board"
                    className="inline-flex items-center gap-1 font-medium text-foreground underline-offset-2 hover:underline"
                >
                    Open on Board
                    <span aria-hidden="true">↗</span>
                </a>
            </div>
        </div>;
}
