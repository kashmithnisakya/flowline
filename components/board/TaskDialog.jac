"""Create/edit dialog for a kanban task.

The form is a plain dict owned by the page; every field change comes back
through onField(key, value) so this stays a presentational component.
"""

import from ...constants { STATUSES, CATEGORIES, PRIORITIES }
import from ...models { Project, MemberView }
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
    categories: list[str] = []
) -> JsxElement {
    categoryOptions = categories if categories else CATEGORIES;
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
                                {for c in categoryOptions {
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
                    <div className="grid gap-2">
                        <Label>Assignee</Label>
                        <Select
                            value={form["assignee"]}
                            onValueChange={lambda (v: str) { onField("assignee", v); }}
                        >
                            <SelectTrigger><SelectValue placeholder="Assignee" /></SelectTrigger>
                            <SelectContent>
                                <SelectItem value="none">Unassigned</SelectItem>
                                {for m in members {
                                    <SelectItem key={m.id} value={m.id}>{m.name}</SelectItem>
                                }}
                            </SelectContent>
                        </Select>
                    </div>
                    <div className="grid gap-2">
                        <Label>Due date</Label>
                        <Input
                            type="date"
                            value={form["due_date"]}
                            onChange={lambda (e: ChangeEvent) { onField("due_date", e.target.value); }}
                        />
                    </div>
                </div>
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
