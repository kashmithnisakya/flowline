"""The move handoff dialog, everything optional: Review asks for a reviewer,
ETA and PR link; Blocked and Changes Requested ask for a note.
"""

import from ...models { MemberView }
import from ..log.DatePicker { DatePicker }
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
import from ..common.glyphs { Spinner, WarnIcon }

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
    onSave: Callable[[], None]
) -> JsxElement {
    isReview = kind == "handoff";

    return
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="sm:max-w-md">
                <DialogHeader>
                    <div className="flex items-start gap-3">
                        <div
                            className={"flex size-9 shrink-0 items-center justify-center rounded-lg " + (
                                # A handoff waits on someone; a stop needs
                                # attention. Same tokens as the step kinds.
                                "bg-warning/15 text-warning"
                                    if isReview
                                    else "bg-destructive/15 text-destructive"
                            )}
                        >
                            {if isReview {
                                <svg
                                    key="handoff"
                                    width={16}
                                    height={16}
                                    viewBox="0 0 24 24"
                                    fill="none"
                                    stroke="currentColor"
                                    strokeWidth={2}
                                    strokeLinecap="round"
                                    strokeLinejoin="round"
                                >
                                    <path d="M5 12h14"/>
                                    <path d="m12 5 7 7-7 7"/>
                                </svg>
                            } else {
                                <WarnIcon key="stop" size={16}/>
                            } }
                        </div>
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
                                    <SelectTrigger>
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
