"""Ask once before something that cannot be taken back from the page:
archive a person or project, delete a role, disconnect GitHub. The body says
what happens to the work attached to it.
"""

import from ..ui.button { Button }
import from ..ui.dialog {
    Dialog,
    DialogContent,
    DialogHeader,
    DialogTitle,
    DialogDescription,
    DialogFooter
}
import from ..common.glyphs { Spinner }

def:pub ConfirmDialog(
    open: bool,
    title: str,
    body: str,
    confirmLabel: str,
    busy: bool,
    onConfirm: Callable[[], None],
    onOpenChange: Callable[[bool], None]
) -> JsxElement {
    return
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="bg-card p-5 sm:max-w-md" showCloseButton={False}>
                <DialogHeader>
                    <DialogTitle className="section-title">{title}</DialogTitle>
                    <DialogDescription className="leading-relaxed">
                        {body}
                    </DialogDescription>
                </DialogHeader>
                <DialogFooter className="mx-0 mb-0 mt-1 border-t-0 bg-transparent p-0">
                    <Button
                        variant="outline"
                        onClick={lambda { onOpenChange(False); }}
                        disabled={busy}
                    >
                        Cancel
                    </Button>
                    <Button variant="destructive" onClick={onConfirm} disabled={busy}>
                        {if busy {
                            <Spinner key="sp"/>
                        }}
                        {confirmLabel}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>;
}
