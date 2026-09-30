"""What a column grip shows around itself: a guide line down the board while
hovered (accent while dragging) and, before a drag, a tooltip saying how
to use it. `height` runs from the grip to the board's end on screen."""

def:pub ColumnGuide(hover: bool, dragging: bool, height: float) -> JsxElement {
    return
        <>
            {if hover or dragging {
                <span
                    key="guide"
                    aria-hidden="true"
                    className={"pointer-events-none absolute top-0 left-1/2 w-px -translate-x-1/2 "
                        + ("bg-(--focus-ring)" if dragging else "bg-border-strong")}
                    style={{"height": str(height) + "px"}}
                />
            }}
            {if hover and not dragging {
                <span
                    key="tip"
                    role="tooltip"
                    className="pointer-events-none absolute top-full left-1/2 mt-2 -translate-x-1/2 rounded-md border bg-popover px-2 py-1 text-xs font-normal whitespace-nowrap text-popover-foreground shadow-md"
                >
                    Drag to resize, double-click to fit
                </span>
            }}
        </>;
}
