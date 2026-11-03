"""The work sitting on one step, a sheet over the diagram's right side in view
mode (a bottom sheet on phones), then its AI, settings and rules. Rows open the
board's task sheet, so the panel is a way into the work, not a read-only list."""

import from "@jac/runtime" { Link }
import from ...models { StepView, TaskRow }
import from ...lib.dates { todayIso }
import from .StepSheetHead { StepSheetHead }
import from .StepAiCard { StepAiCard }
import from .StepFacts { StepFacts }
import from .StepTaskList { StepTaskList }
import from ..ui.button { Button }

def:pub StepTasksPanel(
    step: StepView,
    tasks: list[TaskRow],
    loading: bool,
    scope: str,
    className: str = "",
    place: str = "",
    # The rows are one page of the step; `total` is the whole step, so the
    # header keeps counting all of it while the list grows on demand.
    total: int = 0,
    hasMore: bool = False,
    loadingMore: bool = False,
    # A bottom sheet brings its own close button.
    closable: bool = True,
    onMore: Callable[[], None] = None,
    onOpenTask: Callable[[str], None] = None,
    onEdit: Callable[[], None] = None,
    onClose: Callable[[], None] = None
) -> JsxElement {
    count = total if total > len(tasks) else len(tasks);
    return
        <aside
            aria-label={step.name}
            data-panel="step-tasks"
            className={"pointer-events-auto flex max-h-full min-h-0 flex-col bg-card "
                + className}
            onClick={lambda (e: MouseEvent) { e.stopPropagation(); }}
        >
            <StepSheetHead
                step={step}
                place={place}
                closable={closable}
                onClose={onClose}
            />
            <div
                className="flex min-h-0 flex-1 flex-col gap-5 overflow-y-auto px-5 pt-4 pb-6"
            >
                {if step.blurb {
                    <p key="blurb" className="text-[13px] text-text-secondary">
                        {step.blurb}
                    </p>
                }}
                <StepTaskList
                    tasks={tasks}
                    count={count}
                    loading={loading}
                    scope={scope}
                    today={todayIso()}
                    hasMore={hasMore}
                    loadingMore={loadingMore}
                    onMore={onMore}
                    onOpenTask={onOpenTask}
                />
                {if len(step.ai) > 0 {
                    <StepAiCard key="ai" names={step.ai}/>
                }}
                <StepFacts step={step}/>
            </div>
            <div className="flex shrink-0 items-center gap-2 border-t px-5 py-3">
                <Link
                    to="/board"
                    className="text-[13px] font-medium underline decoration-border-strong underline-offset-[3px] hover:decoration-current"
                >
                    Open on Board
                </Link>
                {if onEdit {
                    <Button
                        key="edit"
                        variant="outline"
                        size="sm"
                        className="ml-auto"
                        onClick={lambda { onEdit(); }}
                    >
                        Edit step
                    </Button>
                }}
            </div>
        </aside>;
}
