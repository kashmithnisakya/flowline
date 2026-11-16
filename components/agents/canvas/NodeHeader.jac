"""A node's header and drag handle. Pointer capture keeps the drag on the header
while the pointer leaves it; the position is clamped to the canvas."""

import from ....lib.canvas { NODE_W, NODE_H, CANVAS_W, CANVAS_H }
import from ...common.AiMark { AiMark }

def:pub NodeHeader(
    title: str,
    ai: bool,
    x: float,
    y: float,
    onSelect: Callable[[], None],
    onMove: Callable[[float, float], None],
    onDropped: Callable[[], None]
) -> JsxElement {
    has dragging: bool = False,
        offX: float = 0.0,
        offY: float = 0.0;

    def down(e: any) {
        e.preventDefault();
        e.currentTarget.setPointerCapture(e.pointerId);
        box = e.currentTarget.closest("[data-canvas]").getBoundingClientRect();
        offX = float(e.clientX) - float(box.left) - x;
        offY = float(e.clientY) - float(box.top) - y;
        dragging = True;
        onSelect();
    }

    def move(e: any) {
        if not dragging {
            return;
        }
        box = e.currentTarget.closest("[data-canvas]").getBoundingClientRect();
        nx = float(e.clientX) - float(box.left) - offX;
        ny = float(e.clientY) - float(box.top) - offY;
        onMove(
            min(max(nx, 0.0), CANVAS_W - NODE_W), min(max(ny, 0.0), CANVAS_H - NODE_H)
        );
    }

    def up(e: any) {
        if dragging {
            dragging = False;
            onDropped();
        }
    }

    return
        <div
            className="flex cursor-grab touch-none items-center gap-1.5 border-b px-2.5 py-1.5 text-[12px] text-muted-foreground active:cursor-grabbing"
            onPointerDown={down}
            onPointerMove={move}
            onPointerUp={up}
            onPointerCancel={up}
        >
            {if ai {
                <AiMark key="ai"/>
            }}
            <span className="font-medium text-foreground">{title}</span>
        </div>;
}
