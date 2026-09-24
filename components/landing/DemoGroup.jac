"""One step of the hero demo: its header bar, then its tasks as rows. A task
dragged onto the group moves to this step."""

import from .demoData { ROUTE, TASKS }
import from .DemoHeader { DemoHeader }
import from .DemoRow { DemoRow, DEMO_DRAG }

def:pub DemoGroup(
    index: int,
    lanes: list[int],
    count: int,
    picked: str,
    onDrop: Callable[[str, int], None],
    onAdvance: Callable[[dict[str, any], int, bool], None]
) -> JsxElement {
    has over: bool = False;

    def drop(e: DragEvent) {
        e.preventDefault();
        over = False;
        dt = e.dataTransfer;
        title = dt.getData(DEMO_DRAG) if dt else "";
        if title {
            onDrop(title, index);
        }
    }

    def leave(e: DragEvent) {
        # Entering a row inside the group fires dragleave too.
        ct: any = e.currentTarget;
        if not ct.contains(e.relatedTarget) {
            over = False;
        }
    }

    step = ROUTE[index];
    next = ROUTE[(index + 1) % len(ROUTE)]["name"];
    return
        <section
            aria-label={step["name"]}
            className={"grid gap-1 rounded-3xl transition-colors duration-150"
                + (" bg-accent/50" if over else "")}
            onDragOver={lambda (e: DragEvent) {
                e.preventDefault();
                over = True;
            }}
            onDragLeave={leave}
            onDrop={drop}
        >
            <DemoHeader
                name={step["name"]}
                color={step["color"]}
                kind={step["kind"]}
                count={count}
            />
            {for (ti, t) in enumerate(TASKS) {
                if lanes[ti] == index {
                    <DemoRow
                        key={t["title"]}
                        task={t}
                        index={ti}
                        color={step["color"]}
                        done={step["kind"] == "done"}
                        next={next}
                        picked={picked == t["title"]}
                        onAdvance={lambda (keyboard: bool) { onAdvance(
                            t, ti, keyboard
                        ); }}
                    />
                }
            }}
        </section>;
}
