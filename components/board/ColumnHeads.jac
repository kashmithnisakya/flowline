"""The board's column labels from lg up, once above every step group, on the
same grid as a task row's cells. The title and each data column have a
handle on their right edge: drag it (or use the arrow keys) to resize that
column alone, double-click to fit (the title goes back to filling the row)."""

import from "react" { useEffect }
import from .TaskCells { GROUP_COLUMNS }
import from .ColumnHandle { ColumnHandle }
import from .columnWidths {
    clampWidth,
    fitWidth,
    headWidth,
    loadWidths,
    keepWidths,
    applyWidths,
    MIN_WIDTH,
    MAX_WIDTH,
    MIN_TITLE,
    MAX_TITLE
}

glob LABELS: list[str] = [
         "Task",
         "People",
         "Priority",
         "Checklist",
         "Due",
         "GitHub"
     ];

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

    # While the title fills the row the columns hang off the right edge, so
    # the first resize fixes the title where it is and the dragged edge follows.
    def resize(idx: int, w: float, save: bool) {
        title = widths[0];
        if title == 0 and idx != 0 {
            title = clampWidth(0, headWidth(0));
        }
        next_widths: list[int] = [];
        for (j, old) in enumerate(widths) {
            if j == idx {
                next_widths.append(clampWidth(idx, w));
            } elif j == 0 {
                next_widths.append(title);
            } else {
                next_widths.append(old);
            }
        }
        widths = next_widths;
        if save {
            keepWidths(next_widths);
        }
    }

    # The title's fit is filling the row again.
    def fitColumn(idx: int) {
        if idx == 0 {
            next_widths: list[int] = [0];
            for j in range(1, len(widths)) {
                next_widths.append(widths[j]);
            }
            widths = next_widths;
            keepWidths(next_widths);
        } else {
            resize(idx, float(fitWidth(idx)), True);
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
            {for (i, label) in enumerate(LABELS) {
                <span
                    key={"h" + str(i)}
                    data-head={str(i)}
                    className="relative min-w-0"
                >
                    <ColumnHandle
                        label={label}
                        width={widths[i]}
                        lo={MIN_TITLE if i == 0 else MIN_WIDTH}
                        hi={MAX_TITLE if i == 0 else MAX_WIDTH}
                        onResize={lambda (w: float, save: bool) { resize(i, w, save); }}
                        onFit={lambda { fitColumn(i); }}
                    />
                    <span aria-hidden="true" className="block truncate">
                        <span data-col={str(i)}>{label}</span>
                    </span>
                </span>
            }}
            <span aria-hidden="true"/>
        </div>;
}
