"""The resize grip on a data column's left edge, sitting in the gap before
it. The title column flexes, so dragging left widens the column and right
narrows it; the arrow keys step 8px the same way."""

import from .columnWidths { MIN_WIDTH, MAX_WIDTH }

def:pub ColumnHandle(
    label: str,
    width: int,
    onResize: Callable[[float, bool], None],
    onReset: Callable[[], None]
) -> JsxElement {
    has startX: float = -1.0,
        startW: float = 0.0,
        dragging: bool = False;

    def down(e: any) {
        e.preventDefault();
        e.currentTarget.setPointerCapture(e.pointerId);
        startX = float(e.clientX);
        startW = float(width);
        dragging = True;
    }

    def move(e: any) {
        if dragging {
            onResize(startW - (float(e.clientX) - startX), False);
        }
    }

    def up(e: any) {
        if dragging {
            dragging = False;
            onResize(startW - (float(e.clientX) - startX), True);
        }
    }

    def key(e: any) {
        step = 0;
        if e.key == "ArrowLeft" {
            step = 8;
        } elif e.key == "ArrowRight" {
            step = -8;
        }
        if step != 0 {
            e.preventDefault();
            onResize(float(width + step), True);
        }
    }

    return
        <span
            role="separator"
            aria-orientation="vertical"
            aria-label={"Resize " + label + " column"}
            aria-valuenow={width}
            aria-valuemin={MIN_WIDTH}
            aria-valuemax={MAX_WIDTH}
            tabIndex={0}
            title="Drag to resize, double-click to reset"
            onPointerDown={down}
            onPointerMove={move}
            onPointerUp={up}
            onPointerCancel={up}
            onDoubleClick={lambda { onReset(); }}
            onKeyDown={key}
            className="group/grip absolute top-1/2 -left-3 z-10 flex h-5 w-3 -translate-y-1/2 cursor-col-resize touch-none justify-center outline-none"
        >
            <span
                className={"h-full w-px rounded-full transition-colors "
                    + (
                        "bg-(--focus-ring)"
                            if dragging
                            else "bg-border group-hover/grip:bg-border-strong group-focus-visible/grip:bg-(--focus-ring)"
                    )}
            />
        </span>;
}
