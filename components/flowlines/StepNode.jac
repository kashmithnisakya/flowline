"""One step on the diagram: a plain card with its status icon and name, then its
owner and count (mid zoom and up), then the first task titles (high). Border,
padding and rows add up to geometry's node height, so the drawn card is the hit
box; the AI chip hangs below it, outside the hit box and the card's button."""

import from ...models { StepView }
import from .NodePorts { NodePorts }
import from .NodeTitles { NodeTitles }
import from .NodeMeta { NodeMeta }
import from .StepAiChip { StepAiChip }
import from .kinds { colorKey }
import from ..common.StepBadge { StepIcon }

def:pub StepNode(
    step: StepView,
    rect: list[float],
    detail: str,
    titles: list[str],
    showTitles: bool = False,
    showOwner: bool = True,
    selected: bool = False,
    portsOn: bool = False,
    target: bool = False,
    editing: bool = False,
    dragging: bool = False,
    dim: bool = False,
    onSelect: Callable[[str], None] = None
) -> JsxElement {
    hover = "";
    if target {
        hover = " cursor-pointer hover:ring-2 hover:ring-ring";
    } elif not selected {
        hover = " hover:border-foreground" + ("" if editing else " cursor-pointer");
    }
    return
        <div
            data-step={step.id}
            className={"absolute transition-opacity duration-150 "
                + ("z-20" if selected else "z-10")
                + (" opacity-40" if dim else "")}
            style={{
                "left": str(rect[0]) + "px",
                "top": str(rect[1]) + "px",
                "width": str(rect[2]) + "px",
                "height": str(rect[3]) + "px"
            }}
        >
            <button
                type="button"
                title={step.name + (", " + step.blurb if step.blurb else "")}
                className={"group relative flex h-full w-full items-start gap-2 rounded-xl border bg-card px-3 py-[7px] text-left transition-[border-color,box-shadow] duration-150 "
                    + (
                        "border-foreground ring-1 ring-foreground"
                            if selected
                            else "border-border-strong"
                    )
                    + (" shadow-md" if dragging else "")
                    + hover}
                onClick={lambda (e: MouseEvent) {
                    e.stopPropagation();
                    if onSelect {
                        onSelect(step.id);
                    }
                }}
            >
                <span className="flex h-5 shrink-0 items-center">
                    <StepIcon color={colorKey(step.color)} kind={step.kind}/>
                </span>
                <span className="flex min-w-0 flex-1 flex-col overflow-hidden">
                    <span className="truncate text-[13px] leading-5 font-semibold">
                        {step.name}
                    </span>
                    {if detail != "low" {
                        <NodeMeta key="meta" step={step} showOwner={showOwner}/>
                    }}
                    {if showTitles {
                        <NodeTitles
                            key="titles"
                            titles={titles}
                            more={step.task_count - len(titles)}
                        />
                    }}
                </span>
                {if editing {
                    <NodePorts key="ports" shown={portsOn}/>
                }}
            </button>
            {if len(step.ai) > 0 {
                <StepAiChip key="ai" names={step.ai} compact={detail == "low"}/>
            }}
        </div>;
}
