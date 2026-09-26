"""A step group's header: 36px on --bg-surface, holding the collapse chevron,
the step's status icon and name, its count, an overdue count when there is
one, and an add button that appears on hover or focus.

The bar used to be tinted in the step's colour and carried the step as a
solid pill, which made every group read as a coloured band. Colour now
appears only on the 14px status icon.
"""

import from ..common.StepBadge { StepIcon }

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
    return
        <div
            className="sticky top-[5.75rem] z-20 flex h-9 items-center gap-2 rounded-md bg-bg-surface pr-1 pl-2 lg:top-8"
        >
            <button
                type="button"
                aria-expanded={open}
                onClick={onToggle}
                className="-mx-1 flex min-w-0 items-center gap-2 rounded-md px-1 py-1 outline-none focus-visible:ring-2 focus-visible:ring-ring"
            >
                <svg
                    width={14}
                    height={14}
                    viewBox="0 0 16 16"
                    aria-hidden="true"
                    className={"shrink-0 text-text-tertiary transition-transform"
                        + (" rotate-90" if open else "")}
                >
                    <path
                        d="m6 4 4 4-4 4"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth={1.5}
                        strokeLinecap="round"
                        strokeLinejoin="round"
                    />
                </svg>
                <StepIcon color={color} kind={kind} size={14}/>
                <span className="truncate text-[13px] font-medium">{label}</span>
                <span className="num text-[13px] text-text-tertiary">{str(count)}</span>
            </button>
            {if overdue > 0 {
                <span key="late" className="text-[12px] font-medium text-danger">
                    {str(overdue) + " overdue"}
                </span>
            }}
            {if onAdd {
                <button
                    key="add"
                    type="button"
                    aria-label={"Add a task to " + label}
                    onClick={onAdd}
                    className="ml-auto flex size-7 shrink-0 items-center justify-center rounded-md text-text-tertiary opacity-0 transition-opacity outline-none group-hover/step:opacity-100 hover:bg-bg-hover hover:text-text-primary focus-visible:opacity-100 focus-visible:ring-2 focus-visible:ring-ring"
                >
                    <svg width={14} height={14} viewBox="0 0 16 16" aria-hidden="true">
                        <path
                            d="M8 3v10M3 8h10"
                            stroke="currentColor"
                            strokeWidth={1.5}
                            strokeLinecap="round"
                        />
                    </svg>
                </button>
            }}
        </div>;
}
