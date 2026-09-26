"""The step panel's header: the step's icon and name, how much work sits
there, the owner and the blurb, and a close button when the panel floats.
Plain ground: the step's colour is carried by its icon."""

import from ...models { StepView }
import from .kinds { colorKey }
import from ..common.StepBadge { StepBadge }

def:pub StepPanelHead(
    step: StepView,
    count: int,
    loading: bool,
    scope: str,
    closable: bool = True,
    onClose: Callable[[], None] = None
) -> JsxElement {
    c = colorKey(step.color);
    owner = step.owner.strip() if step.owner else "";
    who = "Anyone" if owner == "anyone" else owner;
    counted = str(count) + (" task " if count == 1 else " tasks ") + scope;
    return
        <div
            className="flex items-start gap-2 border-b border-border-subtle px-4 pt-3.5 pb-3"
        >
            <div className="flex min-w-0 flex-1 flex-col items-start gap-1.5">
                <h2 className="flex max-w-full min-w-0">
                    <StepBadge name={step.name} color={c} kind={step.kind}/>
                </h2>
                <p className="num text-xs text-text-tertiary">
                    {"Loading" if loading else counted}
                    {if who {
                        <span key="who" className="font-sans">{" · " + who}</span>
                    }}
                </p>
                {if step.blurb {
                    <p key="blurb" className="text-xs text-muted-foreground">
                        {step.blurb}
                    </p>
                }}
            </div>
            {if closable {
                <button
                    key="close"
                    type="button"
                    aria-label="Close"
                    className="-mr-1.5 flex size-8 shrink-0 items-center justify-center rounded-full text-muted-foreground transition-colors hover:bg-card hover:text-foreground"
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
        </div>;
}
