"""A hero demo row: a focusable, draggable DemoLine that moves its task to the
next step on click, Enter or Space. `picked` rings the task whose travel the
demo shows."""

import from .DemoLine { DemoLine }

glob:pub DEMO_DRAG: str = "text/x-flowline-demo";

def:pub DemoRow(
    task: dict[str, any],
    index: int,
    color: str,
    done: bool,
    next: str,
    picked: bool,
    onAdvance: Callable[[bool], None]
) -> JsxElement {
    has dragging: bool = False;

    def start(e: DragEvent) {
        dt = e.dataTransfer;
        if dt {
            dt.setData(DEMO_DRAG, task["title"]);
            dt.effectAllowed = "move";
        }
        dragging = True;
    }

    def key(e: KeyboardEvent) {
        if e.key == "Enter" or e.key == " " {
            e.preventDefault();
            onAdvance(True);
        }
    }

    return
        <div
            id={"demo-row-" + str(index)}
            role="button"
            tabIndex={0}
            draggable={True}
            aria-label={str(task["title"])
                + ". Press Enter to move it to "
                + next
                + "."}
            onDragStart={start}
            onDragEnd={lambda { dragging = False; }}
            onClick={lambda { onAdvance(False); }}
            onKeyDown={key}
            className={"cursor-grab rounded-xl px-2.5 py-2 outline-none select-none hover:bg-accent/60 focus-visible:ring-2 focus-visible:ring-ring active:cursor-grabbing "
                + ("bg-accent " if picked else "")
                + ("opacity-50" if dragging else "")}
        >
            <DemoLine task={task} color={color} done={done}/>
        </div>;
}
