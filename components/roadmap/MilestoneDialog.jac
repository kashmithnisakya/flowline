"""Create/edit dialog for a roadmap milestone.

The form is a plain dict owned by the page plus a single onField(key, value)
callback, the same shape TaskDialog uses. Dates are optional on purpose: a
milestone with no dates is a named bucket, and the page lists it under
Unscheduled instead of the timeline.
"""

import from ..ui.badge { Badge }
import from ..ui.button { Button }
import from ..ui.dialog {
    Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter
}
import from ..ui.input { Input }
import from ..ui.label { Label }
import from ..ui.textarea { Textarea }
import from ..ui.select {
    Select, SelectTrigger, SelectValue, SelectContent, SelectItem
}

# The client does not import constants.jac; it keeps its own copy, which
# must stay in step with MILESTONE_STATUSES on the server.
glob MILESTONE_STATUSES: list[str] = ["Planned", "In Progress", "Done"];

glob COLOR_KEYS: list[str] = [
    "violet", "sky", "emerald", "amber", "rose", "slate"
];

glob SWATCH: dict[str, str] = {
    "violet": "bg-violet-500",
    "sky": "bg-sky-500",
    "emerald": "bg-emerald-500",
    "amber": "bg-amber-500",
    "rose": "bg-rose-500",
    "slate": "bg-slate-500"
};

def swatchClass(color: str) -> str {
    return SWATCH[color] if color in COLOR_KEYS else SWATCH["slate"];
}

def:pub MilestoneDialog(
    open: bool,
    editing: bool,
    form: dict[str, str],
    saving: bool,
    confirmingDelete: bool,
    onField: Callable[[str, str], None],
    onOpenChange: Callable[[bool], None],
    onSave: Callable[[], None],
    onDelete: Callable[[], None]
) -> JsxElement {
    # ISO dates compare correctly as strings, and the server refuses an
    # inverted range outright, so say so before the round trip.
    invertedRange = bool(
        form["start_date"] and form["due_date"]
        and form["due_date"] < form["start_date"]
    );

    return <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="sm:max-w-lg">
            <DialogHeader>
                <DialogTitle>{"Edit milestone" if editing else "New milestone"}</DialogTitle>
            </DialogHeader>
            <div className="grid gap-4 py-2">
                <div className="grid gap-2">
                    <Label>Title</Label>
                    <Input
                        placeholder="Beta hardening"
                        value={form["title"]}
                        onChange={lambda (e: ChangeEvent) { onField("title", e.target.value); }}
                    />
                </div>
                <div className="grid gap-2">
                    <Label>What this phase covers</Label>
                    <Textarea
                        value={form["description"]}
                        onChange={lambda (e: ChangeEvent) { onField("description", e.target.value); }}
                    />
                </div>
                <div className="grid grid-cols-2 gap-3">
                    <div className="grid gap-2">
                        <Label>Start date</Label>
                        <Input
                            type="date"
                            value={form["start_date"]}
                            onChange={lambda (e: ChangeEvent) { onField("start_date", e.target.value); }}
                        />
                    </div>
                    <div className="grid gap-2">
                        <Label>Target date</Label>
                        <Input
                            type="date"
                            value={form["due_date"]}
                            onChange={lambda (e: ChangeEvent) { onField("due_date", e.target.value); }}
                        />
                    </div>
                </div>
                <p className="text-xs text-muted-foreground">
                    Both dates are optional. Without either, the milestone sits under
                    Unscheduled rather than on the timeline.
                </p>
                {if invertedRange {
                    <p key="inverted" className="text-xs text-destructive">
                        The target date is before the start date.
                    </p>
                }}
                <div className="grid grid-cols-2 gap-3">
                    <div className="grid gap-2">
                        <Label>Status</Label>
                        <Select
                            value={form["status"]}
                            onValueChange={lambda (v: str) { onField("status", v); }}
                        >
                            <SelectTrigger><SelectValue placeholder="Status" /></SelectTrigger>
                            <SelectContent>
                                {for s in MILESTONE_STATUSES {
                                    <SelectItem key={s} value={s}>{s}</SelectItem>
                                }}
                            </SelectContent>
                        </Select>
                    </div>
                    <div className="grid gap-2">
                        <Label>Colour</Label>
                        <div className="flex items-center gap-2 pt-1">
                            {for c in COLOR_KEYS {
                                <button
                                    key={c}
                                    type="button"
                                    title={c}
                                    aria-label={c}
                                    onClick={lambda { onField("color", c); }}
                                    className={
                                        "h-6 w-6 rounded-full transition " + swatchClass(c)
                                        + (
                                            " ring-2 ring-ring ring-offset-2 ring-offset-background"
                                            if form["color"] == c else " opacity-60 hover:opacity-100"
                                        )
                                    }
                                />
                            }}
                        </div>
                    </div>
                </div>
                {if editing {
                    <div key="danger" className="rounded-lg border border-destructive/40 bg-destructive/5 p-3">
                        <div className="flex items-center gap-2">
                            <Badge variant="destructive" className="font-normal">Delete</Badge>
                            <span className="text-xs text-muted-foreground">
                                Tasks stay on the board, they just leave this milestone.
                            </span>
                        </div>
                    </div>
                }}
            </div>
            <DialogFooter className="gap-2 sm:justify-between">
                {if editing {
                    <Button key="del" variant="destructive" onClick={onDelete} disabled={saving}>
                        {"Click again to delete" if confirmingDelete else "Delete milestone"}
                    </Button>
                } else {
                    <span key="spacer" />
                }}
                <div className="flex gap-2">
                    <Button variant="outline" onClick={lambda { onOpenChange(False); }}>
                        Cancel
                    </Button>
                    <Button
                        onClick={onSave}
                        disabled={saving or invertedRange or not form["title"].strip()}
                    >
                        Save
                    </Button>
                </div>
            </DialogFooter>
        </DialogContent>
    </Dialog>;
}
