"""The lines between nodes, drawn under them. A line is clickable (a wider,
invisible stroke above it) so it can be selected and deleted."""

import from ....lib.canvas { findNode, edgePath }

def:pub CanvasEdges(
    nodes: list[dict[str, any]],
    edges: list[dict[str, str]],
    selEdge: str,
    onEdge: Callable[[str], None]
) -> JsxElement {
    return
        <svg aria-hidden="true" className="absolute inset-0 size-full overflow-visible">
            <defs>
                <marker
                    id="arrowhead"
                    viewBox="0 0 10 10"
                    refX={9}
                    refY={5}
                    markerWidth={7}
                    markerHeight={7}
                    orient="auto"
                >
                    <path d="M0 0 L10 5 L0 10 z" fill="var(--text-tertiary)"/>
                </marker>
            </defs>
            {for e in edges {
                <g key={e["id"]}>
                    <path
                        d={edgePath(
                            findNode(nodes, e["from"]), findNode(nodes, e["to"])
                        )}
                        fill="none"
                        stroke={"var(--accent)"
                            if selEdge == e["id"]
                            else "var(--text-tertiary)"}
                        strokeWidth={2.4 if selEdge == e["id"] else 1.6}
                        markerEnd="url(#arrowhead)"
                    />
                    <path
                        d={edgePath(
                            findNode(nodes, e["from"]), findNode(nodes, e["to"])
                        )}
                        fill="none"
                        stroke="transparent"
                        strokeWidth={14}
                        className="cursor-pointer"
                        style={{"pointerEvents": "stroke"}}
                        onClick={lambda { onEdge(e["id"]); }}
                    />
                </g>
            }}
        </svg>;
}
