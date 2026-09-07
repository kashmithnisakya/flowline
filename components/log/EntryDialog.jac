"""Add/edit dialog for a log entry. The form is a plain dict owned by the
page. Create picks a member and a date (LogActivity needs both); edit shows
them as context because UpdateLogEntry cannot move a row between people or
days. Edit prefills every field: the walker overwrites, it does not merge."""

# constants.jac is server-only (imported by walkers); define the vocabulary locally.
glob STATUSES: list[str] = [
         "Backlog",
         "In Progress",
         "Review",
         "Changes Requested",
         "Done",
         "Blocked"
     ];

import from ...models { Project, MemberView }
import from .DatePicker { DatePicker }
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

glob FIELD: str = "w-full",
     WIDE: str = "grid gap-2 sm:col-span-2";

def:pub EntryDialog(
    open: bool,
    editing: bool,
    form: dict[str, str],
    members: list[MemberView],
    projects: list[Project],
    saving: bool,
    onField: Callable[[str, str], None],
    onOpenChange: Callable[[bool], None],
    onSave: Callable[[], None]
) -> JsxElement {
    canSave = (
        len(form["activity"].strip()) > 0
        and (editing or len(form["member"]) > 0)
        and not saving
    );
    return
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="p-6 sm:max-w-lg">
                <DialogHeader>
                    <DialogTitle>
                        {"Edit log entry" if editing else "Add log entry"}
                    </DialogTitle>
                    <DialogDescription>
                        {(form["member_name"] + " · " + form["date"])
                            if editing
                            else "Log work on behalf of a roster member. It lands in that day's log."}
                    </DialogDescription>
                </DialogHeader>
                <div className="grid gap-x-4 gap-y-3 py-2 sm:grid-cols-2">
                    {if not editing {
                        <div key="member" className="grid content-start gap-2">
                            <Label>Member</Label>
                            <Select
                                value={form["member"]}
                                onValueChange={lambda (v: str) { onField(
                                    "member", v
                                ); }}
                            >
                                <SelectTrigger className={FIELD}>
                                    <SelectValue placeholder="Pick a person"/>
                                </SelectTrigger>
                                <SelectContent>
                                    {for m in members {
                                        <SelectItem key={m.id} value={m.id}>
                                            {m.name}
                                        </SelectItem>
                                    }}
                                </SelectContent>
                            </Select>
                        </div>
                    }}
                    {if not editing {
                        <div key="date" className="grid content-start gap-2">
                            <Label>Date</Label>
                            <DatePicker
                                value={form["date"]}
                                onChange={lambda (d: str) { onField("date", d); }}
                                className={FIELD}
                            />
                        </div>
                    }}
                    <div className={WIDE}>
                        <Label>Activity</Label>
                        <Input
                            value={form["activity"]}
                            placeholder="What happened, e.g. Vendor call about sandbox access"
                            onChange={lambda (e: ChangeEvent) { onField(
                                "activity", e.target.value
                            ); }}
                        />
                    </div>
                    {if not editing {
                        <div key="project" className="grid content-start gap-2">
                            <Label>Project</Label>
                            <Select
                                value={form["project"]}
                                onValueChange={lambda (v: str) { onField(
                                    "project", v
                                ); }}
                            >
                                <SelectTrigger className={FIELD}>
                                    <SelectValue placeholder="No project"/>
                                </SelectTrigger>
                                <SelectContent>
                                    <SelectItem value="none">No project</SelectItem>
                                    {for p in projects {
                                        <SelectItem key={jid(p)} value={jid(p)}>
                                            {p.name}
                                        </SelectItem>
                                    }}
                                </SelectContent>
                            </Select>
                        </div>
                    }}
                    <div className="grid content-start gap-2">
                        <Label>Status</Label>
                        <Select
                            value={form["status"]}
                            onValueChange={lambda (v: str) { onField("status", v); }}
                        >
                            <SelectTrigger className={FIELD}>
                                <SelectValue placeholder="No status"/>
                            </SelectTrigger>
                            <SelectContent>
                                <SelectItem value="none">No status</SelectItem>
                                {for s in STATUSES {
                                    <SelectItem key={s} value={s}>{s}</SelectItem>
                                }}
                            </SelectContent>
                        </Select>
                    </div>
                    {if editing {
                        <div key="category" className="grid content-start gap-2">
                            <Label>Category</Label>
                            <Input
                                value={form["category"]}
                                onChange={lambda (e: ChangeEvent) { onField(
                                    "category", e.target.value
                                ); }}
                            />
                        </div>
                    } else {
                        <div key="categoryw" className={WIDE}>
                            <Label>Category</Label>
                            <Input
                                value={form["category"]}
                                placeholder="Optional, e.g. Ops"
                                onChange={lambda (e: ChangeEvent) { onField(
                                    "category", e.target.value
                                ); }}
                            />
                        </div>
                    } }
                    <div className="grid content-start gap-2">
                        <Label>Issue link</Label>
                        <Input
                            value={form["issue_link"]}
                            placeholder="https://…"
                            onChange={lambda (e: ChangeEvent) { onField(
                                "issue_link", e.target.value
                            ); }}
                        />
                    </div>
                    <div className="grid content-start gap-2">
                        <Label>PR link</Label>
                        <Input
                            value={form["pr_link"]}
                            placeholder="https://…"
                            onChange={lambda (e: ChangeEvent) { onField(
                                "pr_link", e.target.value
                            ); }}
                        />
                    </div>
                    <div className={WIDE}>
                        <Label>Note</Label>
                        <Textarea
                            value={form["notes"]}
                            rows={3}
                            onChange={lambda (e: ChangeEvent) { onField(
                                "notes", e.target.value
                            ); }}
                        />
                    </div>
                </div>
                <DialogFooter className="gap-2">
                    <Button variant="outline" onClick={lambda { onOpenChange(False); }}>
                        Cancel
                    </Button>
                    <Button onClick={onSave} disabled={not canSave}>
                        {if saving {
                            <Spinner key="sp"/>
                        }}
                        {"Saving…" if saving else ("Save" if editing else "Add entry")}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>;
}
