"""The board's column labels from lg up, once above every step group, on the
same grid as a task row's cells. Each data column has a handle on its left
edge: drag it (or focus it and use the arrow keys) to resize, double-click
to fit its content. Widths stay in this browser."""

import from "react" { useEffect }
import from .TaskCells { GROUP_COLUMNS }
import from .ColumnHandle { ColumnHandle }
import from .columnWidths { clampWidth, fitWidth, loadWidths, keepWidths, applyWidths }

glob LABELS: list[str] = ["People", "Priority", "Checklist", "Due", "GitHub"];

def:pub ColumnHeads -> JsxElement {
    has widths: list[int] = loadWidths();

    # The Display menu's reset ends in a `flowline:columns` event.
    useEffect(
        lambda {
            w: any = window;
            onReset = lambda (e: any) { widths = loadWidths(); };
            w.addEventListener("flowline:columns", onReset);
            return lambda { w.removeEventListener("flowline:columns", onReset); };
        },
        []
    );

    def resize(idx: int, w: float, save: bool) {
        next_widths: list[int] = [];
        for (j, old) in enumerate(widths) {
            next_widths.append(clampWidth(w) if j == idx else old);
        }
        widths = next_widths;
        if save {
            keepWidths(next_widths);
        }
    }

    applyWidths(widths);
    return
        <div
            data-board-heads="true"
            className={"sticky top-14 z-30 hidden items-center gap-x-3 bg-bg-canvas px-2 py-1.5 text-[12px] font-medium text-text-tertiary lg:top-0 lg:grid "
                + GROUP_COLUMNS}
        >
            <span aria-hidden="true"/>
            <span aria-hidden="true">Task</span>
            {for (i, label) in enumerate(LABELS) {
                <span key={"h" + str(i)} className="relative min-w-0">
                    <ColumnHandle
                        label={label}
                        width={widths[i]}
                        onResize={lambda (w: float, save: bool) { resize(i, w, save); }}
                        onFit={lambda { resize(i, float(fitWidth(i)), True); }}
                    />
                    <span aria-hidden="true" className="block truncate">
                        <span data-col={str(i)}>{label}</span>
                    </span>
                </span>
            }}
            <span aria-hidden="true"/>
        </div>;
}
