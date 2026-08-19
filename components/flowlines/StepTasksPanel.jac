"""The work sitting on one step, docked beside the diagram in view mode. Rows
are buttons: clicking one opens the board's task dialog, so the panel is a way
into the work rather than a read-only list."""

import from ...models { StepView, TaskView }
import from .kinds { KIND_LABEL, DOT_FILL, CARD_BAR, colorKey }
import from ...lib.dates { todayIso, dueTone, dueLabel, prettyDay }
import from ..ui.badge { Badge }
import from ..ui.skeleton { Skeleton }

# Due chip by urgency, same three tones the board card uses.
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
    onMore: Callable[[], None] = None,
    onOpenTask: Callable[[str], None] = None,
    onClose: Callable[[], None] = None
) -> JsxElement {
    tone = colorKey(step.color);
    kindLabel = KIND_LABEL[step.kind] if step.kind in KIND_LABEL else step.kind;
    count = total if total > len(tasks) else len(tasks);
    noun = "task" if count == 1 else "tasks";
    today = todayIso();

    return
        <div
            className={"pointer-events-auto flex max-h-full min-h-0 flex-col rounded-lg border bg-card shadow-lg animate-in fade-in slide-in-from-right-4 duration-300 " + className}
            onClick={lambda (e: MouseEvent) { e.stopPropagation(); }}
        >
            <div className="flex items-start gap-2 px-3.5 pt-3.5 pb-2.5">
                <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2 text-sm font-semibold">
                        <span
                            className={"h-2.5 w-2.5 shrink-0 rounded-full " + DOT_FILL[
                                tone
                            ]}
                        />
                        <span className="truncate" title={step.name}>{step.name}</span>
                        <span className="shrink-0 font-normal text-muted-foreground">
                            {"· " + kindLabel}
                        </span>
                    </div>
                    <div className="mt-0.5 text-xs tabular-nums text-muted-foreground">
                        {"Loading…"
                            if loading
                            else str(count) + " " + noun + " " + scope}
                    </div>
                </div>
                <button
                    type="button"
                    title="Close"
                    className="-mr-1 flex h-7 w-7 shrink-0 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
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
                    >
                        <path d="M18 6 6 18"/>
                        <path d="m6 6 12 12"/>
                    </svg>
                </button>
            </div>
            <div
                className="flex min-h-0 flex-col gap-2 overflow-y-auto px-3.5 pb-3 max-sm:max-h-96"
            >
                {if loading {
                    <div key="loading" className="flex flex-col gap-2">
                        <div
                            className={"flex flex-col gap-2 rounded-lg border bg-card p-3 " + CARD_BAR[
                                tone
                            ]}
                        >
                            <Skeleton className="h-4 w-3/5"/>
                            <div className="flex items-center gap-1.5">
                                <Skeleton className="h-5 w-20 rounded-full"/>
                                <Skeleton className="h-5 w-14 rounded-full"/>
                            </div>
                        </div>
                        <div
                            className={"flex flex-col gap-2 rounded-lg border bg-card p-3 " + CARD_BAR[
                                tone
                            ]}
                        >
                            <Skeleton className="h-4 w-2/5"/>
                            <div className="flex items-center gap-1.5">
                                <Skeleton className="h-5 w-16 rounded-full"/>
                                <Skeleton className="h-5 w-12 rounded-full"/>
                            </div>
                        </div>
                        <div
                            className={"flex flex-col gap-2 rounded-lg border bg-card p-3 " + CARD_BAR[
                                tone
                            ]}
                        >
                            <Skeleton className="h-4 w-1/2"/>
                            <div className="flex items-center gap-1.5">
                                <Skeleton className="h-5 w-24 rounded-full"/>
                                <Skeleton className="h-5 w-14 rounded-full"/>
                            </div>
                        </div>
                    </div>
                } elif len(tasks) == 0 {
                    <p
                        key="empty"
                        className="py-7 text-center text-sm text-muted-foreground"
                    >
                        Nothing is sitting on this step.
                    </p>
                } else {
                    <div key="rows" className="flex flex-col gap-2">
                        {for t in tasks {
                            <button
                                key={t.id}
                                type="button"
                                className={"flex w-full flex-col gap-1.5 rounded-lg border bg-card p-3 text-left transition-[transform,box-shadow,border-color] duration-150 hover:-translate-y-px hover:border-foreground/20 hover:shadow-md " + CARD_BAR[
                                    tone
                                ]}
                                onClick={lambda { if onOpenTask { onOpenTask(t.id); }}}
                            >
                                <span className="text-sm font-medium">{t.title}</span>
                                <span
                                    className="flex w-full flex-wrap items-center gap-1.5 text-xs text-muted-foreground"
                                >
                                    {if t.project_name {
                                        <Badge key="p" variant="secondary">
                                            {t.project_name}
                                        </Badge>
                                    }}
                                    {if t.priority {
                                        <Badge
                                            key="pr"
                                            variant={"destructive"
                                                if t.priority == "High"
                                                else "outline"}
                                        >
                                            {t.priority}
                                        </Badge>
                                    }}
                                    {if len(t.assignee_names) > 0 {
                                        <span key="who" className="truncate">
                                            {", ".join(t.assignee_names)}
                                        </span>
                                    }}
                                    {if t.due_date {
                                        <span
                                            key="due"
                                            className={"ml-auto shrink-0 whitespace-nowrap " + DUE_TINT[
                                                dueTone(t.due_date, t.status, today)
                                            ]}
                                            title={"Due " + prettyDay(t.due_date)}
                                        >
                                            {dueLabel(t.due_date, t.status, today)}
                                        </span>
                                    }}
                                </span>
                            </button>
                        }}
                        {if hasMore or loadingMore {
                            <button
                                key="more"
                                type="button"
                                disabled={loadingMore}
                                className="rounded-lg border border-dashed py-2 text-xs tabular-nums text-muted-foreground transition-colors hover:bg-accent hover:text-foreground disabled:opacity-60"
                                onClick={lambda { if onMore { onMore(); }}}
                            >
                                {"Loading…"
                                    if loadingMore
                                    else "Show more (" + str(len(tasks)) + " of " + str(
                                        count
                                    ) + ")"}
                            </button>
                        }}
                    </div>
                }  }
            </div>
            <div
                className="flex items-center justify-between gap-2 border-t px-3.5 py-2.5 text-xs text-muted-foreground"
            >
                <span>Click a task to open it here.</span>
                <a
                    href="/board"
                    className="inline-flex shrink-0 items-center gap-1 font-medium text-foreground underline-offset-2 hover:underline"
                >
                    Open on Board
                    <svg
                        width={11}
                        height={11}
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth={2}
                        strokeLinecap="round"
                        strokeLinejoin="round"
                    >
                        <path d="M7 17 17 7"/>
                        <path d="M8 7h9v9"/>
                    </svg>
                </a>
            </div>
        </div>;
}
