"""Create/edit dialog for a project."""

import from ..ui.button { Button }
import from ..ui.dialog {
    Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter
}
import from ..ui.input { Input }
import from ..ui.label { Label }
import from ..ui.textarea { Textarea }

def:pub ProjectDialog(
    open: bool,
    editing: bool,
    name: str,
    description: str,
    saving: bool,
    onName: Callable[[str], None],
    onDescription: Callable[[str], None],
    onOpenChange: Callable[[bool], None],
    onSave: Callable[[], None]
) -> JsxElement {
    <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent>
            <DialogHeader>
                <DialogTitle>{"Edit project" if editing else "New project"}</DialogTitle>
            </DialogHeader>
            <div className="grid gap-4 py-2">
                <div className="grid gap-2">
                    <Label>Name</Label>
                    <Input
                        value={name}
                        onChange={lambda (e: ChangeEvent) { onName(e.target.value); }}
                    />
                </div>
                <div className="grid gap-2">
                    <Label>Description</Label>
                    <Textarea
                        value={description}
                        onChange={lambda (e: ChangeEvent) { onDescription(e.target.value); }}
                    />
                </div>
            </div>
            <DialogFooter>
                <Button variant="outline" onClick={lambda { onOpenChange(False); }}>
                    Cancel
                </Button>
                <Button onClick={onSave} disabled={saving or not name.strip()}>
                    Save
                </Button>
            </DialogFooter>
        </DialogContent>
    </Dialog>
}
