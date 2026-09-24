"""The interactive frame of a board row: a focusable, draggable button that
opens the task on click or Enter, opens its move menu on M, and places a
dragged task beside it by the half it is dropped on."""

glob:pub DRAG_TYPE: str = "text/x-flowline-task";

def:pub RowShell(
    taskId: str,
    className: str,
    onOpen: Callable[[], None],
    onMoveKey: Callable[[], None],
    onDropBeside: Callable[[str, str, bool], None],
    children: any = None
) -> JsxElement {
    has dragging: bool = False,
        hint: str = "";

    def half(e: DragEvent) -> str {
        r = e.currentTarget.getBoundingClientRect();
        return "above" if (e.clientY - r.top) < r.height / 2.0 else "below";
    }

    def start(e: DragEvent) {
        dt = e.dataTransfer;
        if dt {
            dt.setData(DRAG_TYPE, taskId);
            dt.effectAllowed = "move";
        }
        dragging = True;
    }

    def over(e: DragEvent) {
        if not dragging {
            e.preventDefault();
            e.stopPropagation();
            hint = half(e);
        }
    }

    def drop(e: DragEvent) {
        e.preventDefault();
        e.stopPropagation();
        hint = "";
        dt = e.dataTransfer;
        dragged = dt.getData(DRAG_TYPE) if dt else "";
        if dragged and dragged != taskId {
            onDropBeside(dragged, taskId, half(e) == "above");
        }
    }

    def key(e: KeyboardEvent) {
        k = str(e.key);
        if k == "Enter" or k == " " {
            e.preventDefault();
            onOpen();
        } elif (k == "m" or k == "M") and not (e.metaKey or e.ctrlKey or e.altKey) {
            e.preventDefault();
            onMoveKey();
        }
    }

    return
        <div
            data-task-row={taskId}
            role="button"
            tabIndex={0}
            draggable={True}
            onDragStart={start}
            onDragEnd={lambda { dragging = False; }}
            onDragOver={over}
            onDragLeave={lambda { hint = ""; }}
            onDrop={drop}
            onClick={lambda { onOpen(); }}
            onKeyDown={key}
            className={className + (" opacity-50" if dragging else "")}
        >
            {if hint {
                <span
                    key="hint"
                    className={"pointer-events-none absolute inset-x-3 h-0.5 rounded-full bg-primary "
                        + ("-top-px" if hint == "above" else "-bottom-px")}
                />
            }}
            {children}
        </div>;
}
