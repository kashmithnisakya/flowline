"""One step on the diagram: its pill and count, then the blurb and owner (mid
zoom and up), then the first task titles (high). Padding and rows add up to
geometry.nodeHeight (6 + 24 + 2 + 18 + 6), so the drawn node is the hit box."""

import from ...models { StepView }
import from .NodePorts { NodePorts }
import from .NodeTitles { NodeTitles }
import from .NodeMeta { NodeMeta }
import from ..common.StepBadge { StepBadge }
import from .CountChip { CountChip }

glob RING: dict[str, str] = {
         "sky": "ring-2 ring-step-sky-solid",
         "indigo": "ring-2 ring-step-indigo-solid",
         "amber": "ring-2 ring-step-amber-solid",
         "rose": "ring-2 ring-step-rose-solid",
         "emerald": "ring-2 ring-step-emerald-solid",
         "slate": "ring-2 ring-step-slate-solid"
     };

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
    c = step.color if step.color in RING else "slate";
    hover = " cursor-pointer hover:shadow-md" if not editing and not selected else "";
    if target {
        hover = " cursor-pointer hover:ring-2 hover:ring-primary";
    }
    return
        <button
            type="button"
            data-step={step.id}
            title={step.name + (" · " + step.blurb if step.blurb else "")}
            className={"group absolute flex flex-col overflow-hidden rounded-2xl bg-card px-2.5 py-1.5 text-left transition-[box-shadow,opacity] duration-150 "
                + (("z-20 " + RING[c]) if selected else "z-10 ring-1 ring-border")
                + (" shadow-md" if dragging else " shadow-xs")
                + hover
                + (" opacity-40" if dim else "")}
            style={{
                "left": str(rect[0]) + "px",
                "top": str(rect[1]) + "px",
                "width": str(rect[2]) + "px",
                "height": str(rect[3]) + "px"
            }}
            onClick={lambda (e: MouseEvent) {
                e.stopPropagation();
                if onSelect {
                    onSelect(step.id);
                }
            }}
        >
            <span className="flex h-6 min-w-0 items-center gap-2">
                <span className="flex min-w-0 flex-1">
                    <StepBadge name={step.name} color={c} kind={step.kind} size="sm"/>
                </span>
                {if detail != "low" {
                    <CountChip
                        key="count"
                        count={step.task_count}
                        kind={step.kind}
                        color={c}
                    />
                }}
            </span>
            {if detail != "low" {
                <NodeMeta
                    key="meta"
                    blurb={step.blurb}
                    owner={step.owner if showOwner else ""}
                />
            }}
            {if showTitles {
                <NodeTitles
                    key="titles"
                    titles={titles}
                    more={step.task_count - len(titles)}
                />
            }}
            {if editing {
                <NodePorts key="ports" shown={portsOn}/>
            }}
        </button>;
}
