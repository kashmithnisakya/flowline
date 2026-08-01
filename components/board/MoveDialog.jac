"""The move handoff dialog, everything optional.

Review asks for a reviewer, a review ETA and the PR link; Blocked and
Changes Requested ask for a note. Skipping is always fine.
"""

import from ...models { MemberView }
import from ..log.DatePicker { DatePicker }
import from ..ui.button { Button }
import from ..ui.dialog {
    Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter
}
import from ..ui.input { Input }
import from ..ui.label { Label }
import from ..ui.textarea { Textarea }
import from ..ui.select {
    Select, SelectTrigger, SelectValue, SelectContent, SelectItem
}

def:pub MoveDialog(
    open: bool,
    status: str,
    taskTitle: str,
    members: list[MemberView],
    form: dict[str, str],
    saving: bool,
    onField: Callable[[str, str], None],
    onOpenChange: Callable[[bool], None],
    onSave: Callable[[], None]
) -> JsxElement {
    isReview = status == "Review";

    <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="sm:max-w-md">
            <DialogHeader>
                <DialogTitle>{"Review handoff" if isReview else ("Moved to " + status)}</DialogTitle>
                <DialogDescription>
                    "{taskTitle}" landed in {status}. All of this is optional.
                </DialogDescription>
            </DialogHeader>
            <div className="grid gap-4 py-2">
                {if isReview {
                    <div key="review" className="grid gap-4">
                        <div className="grid gap-1.5">
                            <Label>Reviewer</Label>
                            <Select
                                value={form["reviewer"]}
                                onValueChange={lambda (v: str) { onField("reviewer", v); }}
                            >
                                <SelectTrigger><SelectValue placeholder="Who reviews it?" /></SelectTrigger>
                                <SelectContent>
                                    <SelectItem value="none">No reviewer</SelectItem>
                                    {for m in members {
                                        <SelectItem key={m.id} value={m.id}>{m.name}</SelectItem>
                                    }}
                                </SelectContent>
                            </Select>
                        </div>
                        <div className="grid gap-1.5">
                            <Label>Review by</Label>
                            <div>
                                <DatePicker
                                    value={form["review_due"]}
                                    onChange={lambda (d: str) { onField("review_due", d); }}
                                />
                            </div>
                        </div>
                        <div className="grid gap-1.5">
                            <Label>PR link</Label>
                            <Input
                                placeholder="https://github.com/..."
                                value={form["pr"]}
                                onChange={lambda (e: ChangeEvent) { onField("pr", e.target.value); }}
                            />
                        </div>
                    </div>
                } else {
                    <div key="note" className="grid gap-1.5">
                        <Label>{"What is blocking it?" if status == "Blocked" else "What needs to change?"}</Label>
                        <Textarea
                            value={form["note"]}
                            onChange={lambda (e: ChangeEvent) { onField("note", e.target.value); }}
                        />
                    </div>
                }}
            </div>
            <DialogFooter>
                <Button variant="outline" onClick={lambda { onOpenChange(False); }}>
                    Skip
                </Button>
                <Button onClick={onSave} disabled={saving}>
                    Save
                </Button>
            </DialogFooter>
        </DialogContent>
    </Dialog>
}
