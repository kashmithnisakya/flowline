"""One node on an agent's canvas. Drag it by its header; the round ports on
its sides connect it. A prompt node is dashed teal because the model writes it,
and a node lights while a flow runs through it."""

import from .NodeHeader { NodeHeader }
import from .NodePort { NodePort }

def:pub CanvasNode(
    item: dict[str, any],
    title: str,
    text: str,
    tag: str,
    selected: bool,
    state: str,
    linking: bool,
    onSelect: Callable[[], None],
    onMove: Callable[[float, float], None],
    onDropped: Callable[[], None],
    onOut: Callable[[], None],
    onIn: Callable[[], None]
) -> JsxElement {
    ring = " ring-2 ring-ring" if selected else "";
    look = " border-dashed border-ai" if item["type"] == "prompt" else "";
    run = " outline outline-3 outline-ai-wash border-ai"
        if state == "running"
        else (" border-(--ok)" if state == "done" else "");
    return
        <div
            data-node={item["id"]}
            tabIndex={0}
            className={"absolute w-[190px] rounded-md border bg-card text-card-foreground"
                + look
                + run
                + ring}
            style={{"left": str(item["x"]) + "px", "top": str(item["y"]) + "px"}}
            onClick={lambda { onSelect(); }}
        >
            <NodePort
                side="in"
                label={"Connect into " + title}
                linking={linking}
                onClick={onIn}
            />
            <NodeHeader
                title={title}
                ai={item["type"] == "prompt"}
                x={float(item["x"])}
                y={float(item["y"])}
                onSelect={onSelect}
                onMove={onMove}
                onDropped={onDropped}
            />
            <div className="px-2.5 py-2 text-[13px] break-words">
                {text}
                {if tag {
                    <span
                        key="tag"
                        className="num meta ml-1.5 rounded-sm border px-1 font-mono"
                    >
                        {tag}
                    </span>
                }}
            </div>
            <NodePort
                side="out"
                label={"Connect from " + title}
                linking={linking}
                onClick={onOut}
            />
        </div>;
}
