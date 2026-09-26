"""The board's column labels from lg up, once above every step group, on the
same grid as a task row's cells."""

import from .TaskCells { GROUP_COLUMNS }

glob LABELS: list[str] = [
         "",
         "Task",
         "People",
         "Priority",
         "Checklist",
         "Due",
         "GitHub",
         ""
     ];

def:pub ColumnHeads -> JsxElement {
    return
        <div
            aria-hidden="true"
            className={"sticky top-14 z-30 hidden items-center gap-x-3 bg-bg-canvas px-2 py-1.5 text-[12px] font-medium text-text-tertiary lg:top-0 lg:grid "
                + GROUP_COLUMNS}
        >
            {for (i, label) in enumerate(LABELS) {
                <span key={"h" + str(i)}>{label}</span>
            }}
        </div>;
}
