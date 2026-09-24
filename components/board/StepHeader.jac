"""A step group's header: a bar tinted in the step colour holding the
collapse toggle, the step as a solid badge, its count and overdue count, and
an add button (Done has none: work arrives there by moving)."""

import from ..common.StepBadge { StepBadge, stepWash, stepInk }

def:pub StepHeader(
    label: str,
    color: str,
    kind: str,
    count: int,
    overdue: int,
    open: bool,
    onToggle: Callable[[], None],
    onAdd: Callable[[], None] | None = None
) -> JsxElement {
    ink = stepInk(color);
    return
        <div
            className={"sticky top-14 z-20 flex min-h-12 items-center gap-3 rounded-2xl py-2 pr-2 pl-2.5 md:top-0 "
                + stepWash(color)}
        >
            <button
                type="button"
                aria-expanded={open}
                onClick={onToggle}
                className="flex min-w-0 items-center gap-2.5 rounded-full outline-none focus-visible:ring-2 focus-visible:ring-ring"
            >
                <svg
                    width={12}
                    height={12}
                    viewBox="0 0 16 16"
                    aria-hidden="true"
                    className={ink
                        + " shrink-0 transition-transform"
                        + (" rotate-90" if open else "")}
                >
                    <path
                        d="m6 4 4 4-4 4"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth={2.2}
                        strokeLinecap="round"
                        strokeLinejoin="round"
                    />
                </svg>
                <StepBadge name={label} color={color} kind={kind}/>
                <span className={"text-sm font-semibold " + ink}>{str(count)}</span>
            </button>
            {if overdue > 0 {
                <span key="late" className="text-[13px] font-medium text-destructive">
                    {str(overdue) + " overdue"}
                </span>
            }}
            {if onAdd {
                <button
                    key="add"
                    type="button"
                    aria-label={"Add a task to " + label}
                    onClick={onAdd}
                    className={"ml-auto h-8 rounded-full bg-card/70 px-3.5 text-[13px] font-medium hover:bg-card "
                        + ink}
                >
                    + Add task
                </button>
            }}
        </div>;
}
