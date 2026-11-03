"""Deleting the whole flow line, spelled out: what goes and what stays. Templates
asks through it too (`forTemplate`): a template only lands on an empty flow line,
so this one has to go first."""

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

def:pub WipeDialog(
    open: bool,
    summary: str,
    wiping: bool = False,
    forTemplate: bool = False,
    onCancel: Callable[[], None] = None,
    onConfirm: Callable[[], None] = None
) -> JsxElement {
    return
        <Dialog
            open={open}
            onOpenChange={lambda (o: bool) { if not o and not wiping and onCancel {
                onCancel();
            }}}
        >
            <DialogContent className="bg-card sm:max-w-md">
                <DialogHeader>
                    <DialogTitle>
                        {"Start from a template?"
                            if forTemplate
                            else "Delete this flow line?"}
                    </DialogTitle>
                    <DialogDescription>
                        {(
                            "A template starts a new flow line, so this one goes first. "
                                if forTemplate
                                else ""
                        )
                            + summary}
                    </DialogDescription>
                </DialogHeader>
                <p className="text-sm text-muted-foreground">
                    Tasks keep their status and land by kind on whatever you design next. Roles and the flow line name stay. You start again from the template picker.
                </p>
                <DialogFooter>
                    <Button
                        variant="outline"
                        disabled={wiping}
                        onClick={lambda { if onCancel { onCancel(); }}}
                    >
                        Cancel
                    </Button>
                    <Button
                        variant="destructive"
                        disabled={wiping}
                        onClick={lambda { if onConfirm { onConfirm(); }}}
                    >
                        {if wiping {
                            <Spinner key="sp"/>
                        }}
                        {"Deleting" if wiping else "Delete flow line"}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>;
}
