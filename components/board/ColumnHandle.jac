"""The resize grip on a data column's left edge, sitting in the gap before
it. The title column flexes, so dragging left widens the column and right
narrows it; the arrow keys step 8px the same way. On hover or drag a guide
line runs down the board to the last row on screen."""

import from .columnWidths { MIN_WIDTH, MAX_WIDTH }
import from .ColumnGuide { ColumnGuide }

def:pub ColumnHandle(
    label: str,
    width: int,
    onResize: Callable[[float, bool], None],
    onFit: Callable[[], None]
) -> JsxElement {
    has startX: float = -1.0,
        startW: float = 0.0,
        dragging: bool = False,
        hover: bool = False,
        lineH: float = 0.0;

    # From the grip down to the end of the board or the viewport's bottom.
    def measure(e: any) {
        grip = e.currentTarget.getBoundingClientRect();
        board = e.currentTarget.closest("[data-board-heads]").parentElement;
        bottom = float(board.getBoundingClientRect().bottom);
        if bottom > float(window.innerHeight) {
            bottom = float(window.innerHeight);
        }
        lineH = bottom - float(grip.top);
    }

    def down(e: any) {
        e.preventDefault();
        e.currentTarget.setPointerCapture(e.pointerId);
        measure(e);
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
            onPointerEnter={lambda (e: any) {
                measure(e);
                hover = True;
            }}
            onPointerLeave={lambda { hover = False; }}
            onPointerDown={down}
            onPointerMove={move}
            onPointerUp={up}
            onPointerCancel={up}
            onDoubleClick={lambda { onFit(); }}
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
            <ColumnGuide hover={hover} dragging={dragging} height={lineH}/>
        </span>;
}
