"""Shown when filters match nothing: what happened, how much is hidden, and
one way out. An empty board with no explanation reads as a broken board.
"""

import from ..ui.button { Button }

def:pub FilteredEmpty(hidden: int, onClear: Callable[[], None]) -> JsxElement {
    return
        <div
            className="flex flex-col items-center gap-3 rounded-md border border-border-subtle px-6 py-14 text-center"
        >
            <p className="text-[13px] font-medium">No tasks match these filters</p>
            {if hidden > 0 {
                <p key="n" className="text-[13px] text-text-secondary">
                    {str(hidden) + (" task is hidden" if hidden == 1 else " tasks are hidden")}
                </p>
            }}
            <Button variant="secondary" size="lg" className="mt-1" onClick={onClear}>
                Clear filters
            </Button>
        </div>;
}
