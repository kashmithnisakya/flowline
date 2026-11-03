"""A step sheet's header, for the step's tasks and for its inspector: the status
icon, the step's name, where it sits on the line and a close button."""

import from ...models { StepView }
import from .kinds { colorKey }
import from ..common.StepBadge { StepIcon }

def:pub StepSheetHead(
    step: StepView,
    place: str = "",
    closable: bool = True,
    onClose: Callable[[], None] = None
) -> JsxElement {
    return
        <div className="flex min-h-12 shrink-0 items-center gap-2 border-b pr-3 pl-5">
            <StepIcon color={colorKey(step.color)} kind={step.kind}/>
            <h2 className="section-title min-w-0 truncate text-sm">{step.name}</h2>
            {if place {
                <span key="place" className="meta whitespace-nowrap">{place}</span>
            }}
            {if closable {
                <button
                    key="close"
                    type="button"
                    aria-label="Close"
                    className="ml-auto flex size-7 shrink-0 items-center justify-center rounded-md text-text-secondary transition-colors hover:bg-bg-hover hover:text-text-primary"
                    onClick={lambda { if onClose { onClose(); }}}
                >
                    <svg
                        width={16}
                        height={16}
                        viewBox="0 0 16 16"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth={1.5}
                        strokeLinecap="round"
                        aria-hidden="true"
                    >
                        <path d="m4 4 8 8M12 4l-8 8"/>
                    </svg>
                </button>
            }}
        </div>;
}
