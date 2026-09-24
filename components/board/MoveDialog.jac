"""The move handoff dialog, everything optional: Review asks for a reviewer,
ETA and PR link; Blocked and Changes Requested ask for a note.
"""

import from ...models { MemberView }
import from ..common.DatePicker { DatePicker }
import from ..ui.button { Button }
import from ..ui.dialog {
    Dialog,
    DialogContent,
    DialogHeader,
    DialogTitle,
    DialogDescription,
    DialogFooter
}
import from ..ui.input { Input }
import from ..ui.label { Label }
import from ..ui.textarea { Textarea }
import from ..ui.select {
    Select,
    SelectTrigger,
    SelectValue,
    SelectContent,
    SelectItem
}
import from ..common.glyphs { Spinner }
import from ..common.KindGlyph { KindGlyph }

def:pub MoveDialog(
    open: bool,
    status: str,
    # The landing step's KIND. The dialog used to branch on the literal name
    # "Review", which stopped being true the moment orgs named their own
    # steps; a handoff is a handoff whatever it is called.
    kind: str = "handoff",
    taskTitle: str,
    members: list[MemberView],
    form: dict[str, str],
    saving: bool,
    onField: Callable[[str, str], None],
    onOpenChange: Callable[[bool], None],
    onSave: Callable[[], None],
    # The moved card, which gets focus back on close: its old element left
    # the lane it was in, so Radix would drop focus on the page.
    taskId: str = ""
) -> JsxElement {
    has focusId: str = "";

    can with taskId entry {
        if taskId {
            focusId = taskId;
        }
    }

    isReview = kind == "handoff";

    return
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent
                className="sm:max-w-md"
                onCloseAutoFocus={lambda (e: Event) {
                    card: any = document.querySelector(
                        '[data-task-card="' + focusId + '"]'
                    );
                    if focusId and card {
                        e.preventDefault();
                        card.focus({"preventScroll": True});
                    }
                }}
            >
                <DialogHeader>
                    <div className="flex items-start gap-3">
                        <span
                            className={"mt-0.5 shrink-0 "
                                + ("text-subtle" if isReview else "text-destructive")}
                        >
                            <KindGlyph
                                kind={"handoff" if isReview else "blocked"}
                                size={16}
                            />
                        </span>
                        <div className="grid gap-1.5 text-left">
                            <DialogTitle>
                                {"Review handoff"
                                    if isReview
                                    else ("Moved to " + status)}
                            </DialogTitle>
                            <DialogDescription>
                                "{taskTitle}" landed in {status}. All of this is optional.
                            </DialogDescription>
                        </div>
                    </div>
                </DialogHeader>
                <div className="grid gap-4 py-2">
                    {if isReview {
                        <div key="review" className="grid gap-4">
                            <div className="grid gap-1.5">
                                <Label>Reviewer</Label>
                                <Select
                                    value={form["reviewer"]}
                                    onValueChange={lambda (v: str) { onField(
                                        "reviewer", v
                                    ); }}
                                >
                                    <SelectTrigger className="w-full">
                                        <SelectValue placeholder="Who reviews it?"/>
                                    </SelectTrigger>
                                    <SelectContent>
                                        <SelectItem value="none">
                                            No reviewer
                                        </SelectItem>
                                        {for m in members {
                                            <SelectItem key={m.id} value={m.id}>
                                                {m.name}
                                            </SelectItem>
                                        }}
                                    </SelectContent>
                                </Select>
                            </div>
                            <div className="grid gap-1.5">
                                <Label>Review by</Label>
                                <div>
                                    <DatePicker
                                        value={form["review_due"]}
                                        onChange={lambda (d: str) { onField(
                                            "review_due", d
                                        ); }}
                                    />
                                </div>
                            </div>
                            <div className="grid gap-1.5">
                                <Label>PR link</Label>
                                <Input
                                    placeholder="https://github.com/..."
                                    value={form["pr"]}
                                    onChange={lambda (e: ChangeEvent) { onField(
                                        "pr", e.target.value
                                    ); }}
                                />
                            </div>
                        </div>
                    } else {
                        <div key="note" className="grid gap-1.5">
                            <Label>
                                {"What is blocking it?"
                                    if status == "Blocked"
                                    else "What needs to change?"}
                            </Label>
                            <Textarea
                                value={form["note"]}
                                onChange={lambda (e: ChangeEvent) { onField(
                                    "note", e.target.value
                                ); }}
                            />
                        </div>
                    } }
                </div>
                <DialogFooter>
                    <Button variant="outline" onClick={lambda { onOpenChange(False); }}>
                        Skip
                    </Button>
                    <Button onClick={onSave} disabled={saving}>
                        {if saving {
                            <Spinner key="sp"/>
                        }}
                        {"Saving…" if saving else "Save"}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>;
}
