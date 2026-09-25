"""The transition editor's buttons: save, clear the wording, delete."""

import from ..ui.button { Button }

def:pub EdgeActions(
    clearable: bool = False,
    onSave: Callable[[], None] = None,
    onClear: Callable[[], None] = None,
    onDelete: Callable[[], None] = None
) -> JsxElement {
    return
        <div className="mt-2 flex items-center justify-between gap-1">
            <Button size="sm" onClick={lambda { if onSave { onSave(); }}}>Save</Button>
            <div className="flex items-center gap-1">
                {if clearable {
                    <Button
                        key="clear"
                        size="sm"
                        variant="ghost"
                        title="Take the wording, tag and trigger off this transition, keep the transition"
                        className="text-muted-foreground"
                        onClick={lambda { if onClear { onClear(); }}}
                    >
                        Clear
                    </Button>
                }}
                <Button
                    size="sm"
                    variant="ghost"
                    title="Remove this transition"
                    className="text-muted-foreground hover:text-destructive"
                    onClick={lambda { if onDelete { onDelete(); }}}
                >
                    Delete
                </Button>
            </div>
        </div>;
}
