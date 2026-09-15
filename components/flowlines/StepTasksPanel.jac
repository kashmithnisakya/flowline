"""The work sitting on one step, floated over the diagram in view mode (a
bottom sheet on phones). Rows are buttons: clicking one opens the board's task
dialog, so the panel is a way into the work rather than a read-only list."""

import from ...models { StepView, TaskView }
import from .kinds { KIND_LABEL, KIND_TONE, colorKey }
import from ...lib.dates { todayIso, dueTone, dueLabel, prettyDay }
import from ..common.KindGlyph { KindGlyph }
import from ..common.StepName { StepName }
import from ..ui.skeleton { Skeleton }

# Due text by urgency, same three tones the board card uses.
glob DUE_TINT: dict[str, str] = {
         "overdue": "font-semibold text-destructive",
         "soon": "font-semibold text-warning",
         "": "text-muted-foreground"
     };


def:pub StepTasksPanel(
    step: StepView,
    tasks: list[TaskView],
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
    kindLabel = KIND_LABEL[step.kind] if step.kind in KIND_LABEL else step.kind;
    count = total if total > len(tasks) else len(tasks);
    noun = "task" if count == 1 else "tasks";
    today = todayIso();
    owner = step.owner.strip() if step.owner else "";
    ownerText = "Anyone" if owner == "anyone" else owner;

    return
        <div
            data-panel="step-tasks"
            className={"pointer-events-auto flex max-h-full min-h-0 flex-col bg-card "
                + className}
            onClick={lambda (e: MouseEvent) { e.stopPropagation(); }}
        >
            <div className="flex items-start gap-2 border-b px-4 pt-3.5 pb-3">
                <div className="flex min-w-0 flex-1 flex-col gap-1">
                    <h2 className="min-w-0 text-base leading-6 font-semibold">
                        <StepName name={step.name} color={colorKey(step.color)}/>
                    </h2>
                    <div
                        className="flex min-w-0 items-center gap-1.5 text-xs text-muted-foreground"
                    >
                        <KindGlyph
                            kind={step.kind}
                            size={14}
                            className={KIND_TONE[step.kind]
                                if step.kind in KIND_TONE
                                else "text-subtle"}
                        />
                        <span className="truncate">
                            {kindLabel + (" · " + ownerText if ownerText else "")}
                        </span>
                    </div>
                    <p className="text-xs text-muted-foreground">
                        {if loading {
                            <span key="l">Loading</span>
                        } else {
                            <span key="c">
                                <span className="num">{str(count)}</span>
                                {" " + noun + " " + scope}
                            </span>
                        } }
                    </p>
                    {if step.blurb {
                        <p key="blurb" className="text-xs text-subtle">{step.blurb}</p>
                    }}
                </div>
                {if closable {
                    <button
                        key="close"
                        type="button"
                        aria-label="Close"
                        className="-mr-1.5 flex size-8 shrink-0 items-center justify-center rounded-md text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
                        onClick={lambda { if onClose { onClose(); }}}
                    >
                        <svg
                            width={14}
                            height={14}
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth={2}
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            aria-hidden="true"
                        >
                            <path d="M18 6 6 18"/>
                            <path d="m6 6 12 12"/>
                        </svg>
                    </button>
                }}
            </div>
            <div className="flex min-h-0 flex-1 flex-col overflow-y-auto">
                {if loading {
                    <div key="loading" className="flex flex-col">
                        <div className="flex flex-col gap-2 border-b px-4 py-3">
                            <Skeleton className="h-4 w-3/5"/>
                            <Skeleton className="h-3 w-2/5"/>
                        </div>
                        <div className="flex flex-col gap-2 border-b px-4 py-3">
                            <Skeleton className="h-4 w-1/2"/>
                            <Skeleton className="h-3 w-1/3"/>
                        </div>
                        <div className="flex flex-col gap-2 border-b px-4 py-3">
                            <Skeleton className="h-4 w-2/3"/>
                            <Skeleton className="h-3 w-2/5"/>
                        </div>
                    </div>
                } elif len(tasks) == 0 {
                    <p
                        key="empty"
                        className="px-4 py-8 text-center text-sm text-muted-foreground"
                    >
                        Nothing is sitting on this step.
                    </p>
                } else {
                    <ul key="rows" className="flex flex-col">
                        {for t in tasks {
                            <li key={t.id} className="border-b">
                                <button
                                    type="button"
                                    className="flex w-full flex-col gap-0.5 px-4 py-2.5 text-left transition-colors duration-150 hover:bg-accent focus-visible:bg-accent"
                                    onClick={lambda { if onOpenTask {
                                        onOpenTask(t.id);
                                    }}}
                                >
                                    <span className="flex w-full items-baseline gap-3">
                                        <span
                                            className="min-w-0 flex-1 text-sm leading-5 font-medium"
                                        >
                                            {t.title}
                                        </span>
                                        {if t.due_date {
                                            <span
                                                key="due"
                                                className={"num shrink-0 text-xs whitespace-nowrap "
                                                    + DUE_TINT[
                                                        dueTone(
                                                            t.due_date, t.status, today
                                                        )
                                                    ]}
                                                title={"Due " + prettyDay(t.due_date)}
                                            >
                                                {dueLabel(t.due_date, t.status, today)}
                                            </span>
                                        }}
                                    </span>
                                    <span
                                        className="flex min-w-0 flex-wrap items-center gap-x-1 text-xs text-muted-foreground"
                                    >
                                        {if t.project_name {
                                            <span key="p">{t.project_name}</span>
                                        }}
                                        {if t.priority {
                                            <span
                                                key="pr"
                                                className={"text-destructive"
                                                    if t.priority == "High"
                                                    else ""}
                                            >
                                                {(" · " if t.project_name else "")
                                                    + t.priority}
                                            </span>
                                        }}
                                        {if len(t.assignee_names) > 0 {
                                            <span
                                                key="who"
                                                className="min-w-0 truncate"
                                            >
                                                {(
                                                    " · "
                                                        if t.project_name or t.priority
                                                        else ""
                                                )
                                                    + ", ".join(t.assignee_names)}
                                            </span>
                                        }}
                                    </span>
                                </button>
                            </li>
                        }}
                        {if hasMore or loadingMore {
                            <li key="more" className="px-4 py-2.5">
                                <button
                                    type="button"
                                    disabled={loadingMore}
                                    className="num w-full rounded-md border py-1.5 text-xs text-muted-foreground transition-colors hover:bg-accent hover:text-foreground disabled:opacity-60"
                                    onClick={lambda { if onMore { onMore(); }}}
                                >
                                    {"Loading"
                                        if loadingMore
                                        else "Show more ("
                                            + str(len(tasks))
                                            + " of "
                                            + str(count)
                                            + ")"}
                                </button>
                            </li>
                        }}
                    </ul>
                }  }
            </div>
            <div
                className="flex items-center justify-end border-t px-4 py-2.5 text-[13px]"
            >
                <a
                    href="/board"
                    className="inline-flex shrink-0 items-center gap-1 font-medium text-foreground underline-offset-2 hover:underline"
                >
                    Open on Board
                    <svg
                        width={12}
                        height={12}
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth={2}
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        aria-hidden="true"
                    >
                        <path d="M7 17 17 7"/>
                        <path d="M8 7h9v9"/>
                    </svg>
                </a>
            </div>
        </div>;
}
