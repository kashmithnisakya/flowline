"""The nodes that can be added to a canvas. The When node is the agent's own
and cannot be added twice."""

import from ....lib.canvas { NODE_TYPES }

def:pub CanvasPalette(onAdd: Callable[[str], None]) -> JsxElement {
    return
        <div
            className="flex flex-row flex-wrap gap-2 md:flex-col"
            role="group"
            aria-label="Add a node"
        >
            <span className="meta w-full">Add a node</span>
            {for t in NODE_TYPES {
                <button
                    key={t[0]}
                    type="button"
                    className="flex min-w-[120px] flex-1 flex-col rounded-sm border bg-card px-2 py-1.5 text-left text-[13px] hover:bg-accent md:flex-none"
                    onClick={lambda { onAdd(t[0]); }}
                >
                    <span className="font-medium">{t[1]}</span>
                    <span className="meta">{t[2]}</span>
                </button>
            }}
        </div>;
}
