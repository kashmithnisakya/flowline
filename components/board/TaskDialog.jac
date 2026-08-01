"""Create/edit dialog for a kanban task.

The form is a plain dict owned by the page; assignees ride separately as
a list (tasks take several people in v2.5). Assignee chips group by
project membership, and picking someone outside the selected project
adds them to it on save. A Review status reveals the handoff fields.
"""

import from ...constants { STATUSES, PRIORITIES }
import from ...models { Project, MemberView }
import from ..log.DatePicker { DatePicker }
import from ..ui.button { Button }
import from ..ui.badge { Badge }
import from ..ui.dialog {
    Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter
}
import from ..ui.input { Input }
import from ..ui.label { Label }
import from ..ui.textarea { Textarea }
import from ..ui.select {
    Select, SelectTrigger, SelectValue, SelectContent, SelectItem
}

def:pub TaskDialog(
    open: bool,
    editing: bool,
    form: dict[str, str],
    projects: list[Project],
    members: list[MemberView],
    saving: bool,
    onField: Callable[[str, str], None],
    onOpenChange: Callable[[bool], None],
    onSave: Callable[[], None],
    onDelete: Callable[[], None],
    categories: list[str] = [],
    assignees: list[str] = [],
    onToggleAssignee: Callable[[str], None] = None
) -> JsxElement {
    selectedProject = form["project"];
    inProject = [
        m for m in members
        if selectedProject != "none" and selectedProject in m.project_ids
    ];
    outsiders = [m for m in members if m not in inProject];
    outsideSelected = False;
    for m in outsiders {
        if m.id in assignees and selectedProject != "none" {
            outsideSelected = True;
        }
    }

    <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="sm:max-w-lg">
            <DialogHeader>
                <DialogTitle>{"Edit task" if editing else "New task"}</DialogTitle>
            </DialogHeader>
            <div className="grid gap-4 py-2">
                <div className="grid gap-2">
                    <Label>Title</Label>
                    <Input
                        value={form["title"]}
                        onChange={lambda (e: ChangeEvent) { onField("title", e.target.value); }}
                    />
                </div>
                <div className="grid grid-cols-2 gap-3">
                    <div className="grid gap-2">
                        <Label>Project</Label>
                        <Select
                            value={form["project"]}
                            onValueChange={lambda (v: str) { onField("project", v); }}
                        >
                            <SelectTrigger><SelectValue placeholder="Project" /></SelectTrigger>
                            <SelectContent>
                                <SelectItem value="none">No project</SelectItem>
                                {for p in projects {
                                    <SelectItem key={jid(p)} value={jid(p)}>{p.name}</SelectItem>
                                }}
                            </SelectContent>
                        </Select>
                    </div>
                    <div className="grid gap-2">
                        <Label>Category</Label>
                        <Select
                            value={form["category"]}
                            onValueChange={lambda (v: str) { onField("category", v); }}
                        >
                            <SelectTrigger><SelectValue placeholder="Category" /></SelectTrigger>
                            <SelectContent>
                                {for c in categories {
                                    <SelectItem key={c} value={c}>{c}</SelectItem>
                                }}
                            </SelectContent>
                        </Select>
                    </div>
                    <div className="grid gap-2">
                        <Label>Priority</Label>
                        <Select
                            value={form["priority"]}
                            onValueChange={lambda (v: str) { onField("priority", v); }}
                        >
                            <SelectTrigger><SelectValue placeholder="Priority" /></SelectTrigger>
                            <SelectContent>
                                {for p in PRIORITIES {
                                    <SelectItem key={p} value={p}>{p}</SelectItem>
                                }}
                            </SelectContent>
                        </Select>
                    </div>
                    <div className="grid gap-2">
                        <Label>Status</Label>
                        <Select
                            value={form["status"]}
                            onValueChange={lambda (v: str) { onField("status", v); }}
                        >
                            <SelectTrigger><SelectValue placeholder="Status" /></SelectTrigger>
                            <SelectContent>
                                {for s in STATUSES {
                                    <SelectItem key={s} value={s}>{s}</SelectItem>
                                }}
                            </SelectContent>
                        </Select>
                    </div>
                </div>
                <div className="grid gap-2">
                    <Label>Assignees</Label>
                    {if len(members) > 0 {
                        <div key="chips" className="flex flex-wrap gap-1.5">
                            {for m in inProject {
                                <Badge
                                    key={m.id}
                                    variant={"default" if m.id in assignees else "outline"}
                                    className="cursor-pointer"
                                    onClick={lambda { if onToggleAssignee { onToggleAssignee(m.id); } }}
                                >
                                    {m.name}
                                </Badge>
                            }}
                            {for m in outsiders {
                                <Badge
                                    key={m.id}
                                    variant={"default" if m.id in assignees else "outline"}
                                    className={"cursor-pointer" + ("" if selectedProject == "none" else " opacity-70")}
                                    onClick={lambda { if onToggleAssignee { onToggleAssignee(m.id); } }}
                                >
                                    {m.name}
                                </Badge>
                            }}
                        </div>
                    } else {
                        <p key="none" className="text-xs text-muted-foreground">No members yet.</p>
                    }}
                    {if outsideSelected {
                        <p key="hint" className="text-xs text-muted-foreground">
                            Dimmed people are not on this project yet. Saving adds them to it.
                        </p>
                    }}
                </div>
                <div className="grid grid-cols-2 gap-3">
                    <div className="grid gap-2">
                        <Label>Due date</Label>
                        <div>
                            <DatePicker
                                value={form["due_date"]}
                                onChange={lambda (d: str) { onField("due_date", d); }}
                            />
                        </div>
                    </div>
                    <div className="grid gap-2">
                        <Label>GitHub issue (optional)</Label>
                        <Input
                            placeholder="https://github.com/..."
                            value={form["issue"]}
                            onChange={lambda (e: ChangeEvent) { onField("issue", e.target.value); }}
                        />
                    </div>
                </div>
                {if form["status"] == "Review" {
                    <div key="review" className="grid gap-3 rounded-lg border bg-muted/30 p-3">
                        <div className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                            Review handoff (optional)
                        </div>
                        <div className="grid grid-cols-2 gap-3">
                            <div className="grid gap-2">
                                <Label>Reviewer</Label>
                                <Select
                                    value={form["reviewer"]}
                                    onValueChange={lambda (v: str) { onField("reviewer", v); }}
                                >
                                    <SelectTrigger><SelectValue placeholder="Reviewer" /></SelectTrigger>
                                    <SelectContent>
                                        <SelectItem value="none">No reviewer</SelectItem>
                                        {for m in members {
                                            <SelectItem key={m.id} value={m.id}>{m.name}</SelectItem>
                                        }}
                                    </SelectContent>
                                </Select>
                            </div>
                            <div className="grid gap-2">
                                <Label>Review by</Label>
                                <div>
                                    <DatePicker
                                        value={form["review_due"]}
                                        onChange={lambda (d: str) { onField("review_due", d); }}
                                    />
                                </div>
                            </div>
                        </div>
                        <div className="grid gap-2">
                            <Label>PR link</Label>
                            <Input
                                placeholder="https://github.com/..."
                                value={form["pr"]}
                                onChange={lambda (e: ChangeEvent) { onField("pr", e.target.value); }}
                            />
                        </div>
                    </div>
                }}
                <div className="grid gap-2">
                    <Label>Notes / blockers</Label>
                    <Textarea
                        value={form["notes"]}
                        onChange={lambda (e: ChangeEvent) { onField("notes", e.target.value); }}
                    />
                </div>
            </div>
            <DialogFooter className="gap-2 sm:justify-between">
                {if editing {
                    <Button key="del" variant="destructive" onClick={onDelete} disabled={saving}>
                        Delete
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
                        disabled={saving or not form["title"].strip()}
                    >
                        Save
                    </Button>
                </div>
            </DialogFooter>
        </DialogContent>
    </Dialog>
}
