"""One step on the tour's flow line diagram, drawn like the flow line page's
node: a soft card holding the step's badge, with its owner role under it."""

import from ..common.StepBadge { StepBadge }

glob NODE_W: int = 116,
     NODE_H: int = 54;

def:pub FlowNode(step: dict[str, any]) -> JsxElement {
    x = int(step["x"]);
    y = int(step["y"]);
    return
        <g>
            <rect
                x={x}
                y={y}
                width={NODE_W}
                height={NODE_H}
                rx={16}
                style={{"fill": "var(--card)", "stroke": "var(--border)"}}
            />
            <foreignObject x={x + 8} y={y + 7} width={NODE_W - 16} height={24}>
                <div className="flex">
                    <StepBadge
                        name={step["name"]}
                        color={step["color"]}
                        kind={step["kind"]}
                        size="sm"
                    />
                </div>
            </foreignObject>
            {if step["owner"] {
                <text
                    key="owner"
                    x={x + 11}
                    y={y + 45}
                    className="text-xs"
                    style={{"fill": "var(--subtle)"}}
                >
                    {step["owner"]}
                </text>
            }}
        </g>;
}
