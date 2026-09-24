"""The step panel's header on the step's wash: its badge, how much work sits
there, the owner and the blurb, and a close button when the panel floats."""

import from ...models { StepView }
import from .kinds { colorKey }
import from ..common.StepBadge { StepBadge, stepWash, stepInk }

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
        <div className={"flex items-start gap-2 px-4 pt-3.5 pb-3 " + stepWash(c)}>
            <div className="flex min-w-0 flex-1 flex-col items-start gap-1.5">
                <h2 className="flex max-w-full min-w-0">
                    <StepBadge name={step.name} color={c} kind={step.kind}/>
                </h2>
                <p className={"num text-xs font-medium " + stepInk(c)}>
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
