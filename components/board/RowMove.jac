"""A row's move control: the arrow button, and the step menu in its place
while open (M on a focused row opens it too). The menu mounts only while
open, so a long board renders one menu at most."""

import from ...models { TaskRow }
import from .MoveMenu { MoveMenu }

glob TRIGGER: str = "inline-flex size-8 shrink-0 items-center justify-center rounded-full text-subtle outline-none hover:bg-accent hover:text-foreground focus-visible:outline-2 focus-visible:outline-solid focus-visible:outline-ring";

def Arrow -> JsxElement {
    return
        <svg width={14} height={14} viewBox="0 0 16 16" aria-hidden="true">
            <path
                d="M3 8h9.5M9 4.5 12.5 8 9 11.5"
                fill="none"
                stroke="currentColor"
                strokeWidth={1.6}
                strokeLinecap="round"
                strokeLinejoin="round"
            />
        </svg>;
}

def:pub RowMove(
    task: TaskRow,
    open: bool,
    onOpenChange: Callable[[bool], None],
    columnKey: str,
    route: dict[str, any],
    onMove: Callable[[TaskRow, str], None]
) -> JsxElement {
    # The row may sit in another group after a move, so focus goes back to
    # it by id rather than through a ref.
    def refocus {
        tid = task.id;
        window.setTimeout(
            lambda {
                el: any = document.querySelector('[data-task-row="' + tid + '"]');
                if el {
                    el.focus({"preventScroll": True});
                }
            },
            0
        );
    }

    if open {
        return
            <MoveMenu
                open={True}
                onOpenChange={onOpenChange}
                current={columnKey}
                keys={route["keys"]}
                labels={route["labels"]}
                colors={route["colors"]}
                steps={route["steps"]}
                onPick={lambda (k: str) { onMove(task, k); }}
                triggerClass={TRIGGER}
                align="end"
                onClosed={refocus}
            />;
    }
    return
        <button
            type="button"
            tabIndex={-1}
            aria-haspopup="menu"
            aria-expanded="false"
            aria-label="Move to another step"
            className={TRIGGER}
            onClick={lambda (e: MouseEvent) {
                e.stopPropagation();
                onOpenChange(True);
            }}
            onKeyDown={lambda (e: KeyboardEvent) { e.stopPropagation(); }}
        >
            <Arrow/>
        </button>;
}
