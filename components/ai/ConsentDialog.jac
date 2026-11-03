"""The question before AI responsibilities are turned on: what will leave this
server, and that turning them off again keeps every setting."""

import from ..ui.button { Button }
import from ..ui.dialog {
    Dialog,
    DialogContent,
    DialogHeader,
    DialogTitle,
    DialogDescription,
    DialogFooter
}
import from ..common.AiMark { AiMark }
import from .WhatIsSent { WhatIsSent }

def:pub ConsentDialog(
    open: bool,
    saving: bool,
    onOpenChange: Callable[[bool], None],
    onConfirm: Callable[[], None]
) -> JsxElement {
    return
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="bg-popover sm:max-w-[500px]">
                <DialogHeader>
                    <AiMark large={True} className="mb-1"/>
                    <DialogTitle>Turn on AI responsibilities?</DialogTitle>
                    <DialogDescription>
                        A role's responsibilities start running when a task moves onto its step. Turning this off again pauses them and keeps their settings.
                    </DialogDescription>
                </DialogHeader>
                <WhatIsSent/>
                <DialogFooter>
                    <Button
                        variant="ghost"
                        disabled={saving}
                        onClick={lambda { onOpenChange(False); }}
                    >
                        Keep it off
                    </Button>
                    <Button disabled={saving} onClick={lambda { onConfirm(); }}>
                        Turn on
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>;
}
