"""The arrow editor's buttons: delete the arrow, or cancel or save the draft."""

import from ..ui.button { Button }

def:pub EdgeActions(
    onSave: Callable[[], None] = None,
    onCancel: Callable[[], None] = None,
    onDelete: Callable[[], None] = None
) -> JsxElement {
    return
        <div className="flex items-center gap-2 pt-1">
            <Button
                size="sm"
                variant="ghost"
                className="-ml-2 h-7 text-danger hover:text-danger"
                onClick={lambda { if onDelete { onDelete(); }}}
            >
                Delete arrow
            </Button>
            <Button
                size="sm"
                variant="ghost"
                className="ml-auto h-7"
                onClick={lambda { if onCancel { onCancel(); }}}
            >
                Cancel
            </Button>
            <Button
                size="sm"
                className="h-7"
                onClick={lambda { if onSave { onSave(); }}}
            >
                Save
            </Button>
        </div>;
}
