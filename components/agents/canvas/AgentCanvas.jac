"""The canvas: a scrolling dot grid with the agent's nodes over SVG lines. A
line is clickable to select it. Everything is data in, gestures out."""

import from ....models { AgentView, StepView, RoleView }
import from ....lib.canvas {
    CANVAS_W,
    CANVAS_H,
    findNode,
    edgePath,
    nodeTitle,
    nodeText
}
import from ....lib.agents { toolKind }
import from .CanvasEdges { CanvasEdges }
import from .CanvasNode { CanvasNode }

def:pub AgentCanvas(
    agent: AgentView,
    nodes: list[dict[str, any]],
    edges: list[dict[str, str]],
    steps: list[StepView],
    roles: list[RoleView],
    sel: str,
    selEdge: str,
    link: str,
    states: dict[str, str],
    onSelect: Callable[[str], None],
    onMove: Callable[[str, float, float], None],
    onDropped: Callable[[], None],
    onOut: Callable[[str], None],
    onIn: Callable[[str], None],
    onEdge: Callable[[str], None]
) -> JsxElement {
    return
        <div
            className="relative min-h-[470px] overflow-auto rounded-md border bg-card"
            style={{
                "backgroundImage": "radial-gradient(var(--border-strong) 1px, transparent 1px)",
                "backgroundSize": "20px 20px"
            }}
        >
            <div
                data-canvas="1"
                className="relative"
                style={{"width": str(CANVAS_W) + "px", "height": str(CANVAS_H) + "px"}}
            >
                <CanvasEdges
                    nodes={nodes}
                    edges={edges}
                    selEdge={selEdge}
                    onEdge={onEdge}
                />
                {for n in nodes {
                    <CanvasNode
                        key={n["id"]}
                        item={n}
                        title={nodeTitle(n["type"])}
                        text={nodeText(agent, n, steps, roles)}
                        tag={toolKind(n["cfg"]["tool"]) if n["type"] == "tool" else ""}
                        selected={sel == n["id"]}
                        state={states[n["id"]] or ""}
                        linking={link != "" and link != n["id"]}
                        onSelect={lambda { onSelect(n["id"]); }}
                        onMove={lambda (x: float, y: float) { onMove(n["id"], x, y); }}
                        onDropped={onDropped}
                        onOut={lambda { onOut(n["id"]); }}
                        onIn={lambda { onIn(n["id"]); }}
                    />
                }}
            </div>
        </div>;
}
