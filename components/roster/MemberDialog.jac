"""Create/edit dialog for a roster member."""

import from ...constants { SECTIONS }
import from ..ui.button { Button }
import from ..ui.dialog {
    Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter
}
import from ..ui.input { Input }
import from ..ui.label { Label }
import from ..ui.select {
    Select, SelectTrigger, SelectValue, SelectContent, SelectItem
}

def:pub MemberDialog(
    open: bool,
    editing: bool,
    form: dict[str, str],
    saving: bool,
    onField: Callable[[str, str], None],
    onOpenChange: Callable[[bool], None],
    onSave: Callable[[], None],
    sections: list[str] = []
) -> JsxElement {
    # Custom sections ride in via the prop; built-ins are the fallback so
    # previews and older call sites keep rendering.
    sectionOptions = sections if sections else SECTIONS;
    <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent>
            <DialogHeader>
                <DialogTitle>{"Edit member" if editing else "Add member"}</DialogTitle>
            </DialogHeader>
            <div className="grid gap-4 py-2">
                <div className="grid gap-2">
                    <Label>Name</Label>
                    <Input
                        value={form["name"]}
                        onChange={lambda (e: ChangeEvent) { onField("name", e.target.value); }}
                    />
                </div>
                <div className="grid gap-2">
                    <Label>Role</Label>
                    <Input
                        value={form["role"]}
                        onChange={lambda (e: ChangeEvent) { onField("role", e.target.value); }}
                    />
                </div>
                <div className="grid gap-2">
                    <Label>Section</Label>
                    <Select
                        value={form["section"]}
                        onValueChange={lambda (v: str) { onField("section", v); }}
                    >
                        <SelectTrigger>
                            <SelectValue placeholder="Pick a section (optional)" />
                        </SelectTrigger>
                        <SelectContent>
                            {for s in sectionOptions {
                                <SelectItem key={s} value={s}>{s}</SelectItem>
                            }}
                        </SelectContent>
                    </Select>
                </div>
                <div className="grid gap-2">
                    <Label>Email</Label>
                    <Input
                        type="email"
                        value={form["email"]}
                        onChange={lambda (e: ChangeEvent) { onField("email", e.target.value); }}
                    />
                </div>
                <div className="grid gap-2">
                    <Label>GitHub username</Label>
                    <Input
                        value={form["github"]}
                        onChange={lambda (e: ChangeEvent) { onField("github", e.target.value); }}
                    />
                </div>
            </div>
            <DialogFooter>
                <Button variant="outline" onClick={lambda { onOpenChange(False); }}>
                    Cancel
                </Button>
                <Button onClick={onSave} disabled={saving or not form["name"].strip()}>
                    Save
                </Button>
            </DialogFooter>
        </DialogContent>
    </Dialog>
}
