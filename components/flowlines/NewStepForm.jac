"""Naming a new step in the edit column: the step only exists once it has a name
of its own, never as a placeholder card."""

import from ..ui.button { Button }
import from ..ui.input { Input }

def:pub NewStepForm(
    name: str,
    saving: bool = False,
    onName: Callable[[str], None] = None,
    onCommit: Callable[[], None] = None,
    onCancel: Callable[[], None] = None
) -> JsxElement {
    return
        <div className="flex flex-col gap-3 overflow-y-auto p-5">
            <h2 className="section-title text-sm">New step</h2>
            <Input
                aria-label="Step name"
                className="h-8"
                value={name}
                placeholder="What should this step be called?"
                autoFocus={True}
                onChange={lambda (e: any) { if onName { onName(e.target.value); }}}
                onKeyDown={lambda (e: any) { if e.key == "Enter" and onCommit {
                    onCommit();
                }}}
            />
            <div className="flex gap-2">
                <Button
                    size="sm"
                    disabled={saving or not name.strip()}
                    onClick={lambda { if onCommit { onCommit(); }}}
                >
                    Add to canvas
                </Button>
                <Button
                    size="sm"
                    variant="ghost"
                    onClick={lambda { if onCancel { onCancel(); }}}
                >
                    Cancel
                </Button>
            </div>
            <p className="meta">
                Kind, colour and owner can be set once it is on the canvas.
            </p>
        </div>;
}
