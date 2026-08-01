"""Create/edit dialog for a project.

Repos are attached here: an optional repo field at creation, and the
full chip list (remove + add) when editing. Cards stay display-only.
"""

import from ...models { RepoView }
import from ..ui.badge { Badge }
import from ..ui.button { Button }
import from ..ui.dialog {
    Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter
}
import from ..ui.input { Input }
import from ..ui.label { Label }
import from ..ui.textarea { Textarea }

def:pub ProjectDialog(
    open: bool,
    editing: bool,
    name: str,
    description: str,
    saving: bool,
    onName: Callable[[str], None],
    onDescription: Callable[[str], None],
    onOpenChange: Callable[[bool], None],
    onSave: Callable[[], None],
    repos: list[RepoView] = [],
    repoDraft: str = "",
    onRepoDraft: Callable[[str], None] = None,
    onRemoveRepo: Callable[[str], None] = None
) -> JsxElement {
    <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent>
            <DialogHeader>
                <DialogTitle>{"Edit project" if editing else "New project"}</DialogTitle>
            </DialogHeader>
            <div className="grid gap-4 py-2">
                <div className="grid gap-2">
                    <Label>Name</Label>
                    <Input
                        value={name}
                        onChange={lambda (e: ChangeEvent) { onName(e.target.value); }}
                    />
                </div>
                <div className="grid gap-2">
                    <Label>Description</Label>
                    <Textarea
                        value={description}
                        onChange={lambda (e: ChangeEvent) { onDescription(e.target.value); }}
                    />
                </div>
                <div className="grid gap-2">
                    <Label>{"Repositories" if editing else "GitHub repo (optional)"}</Label>
                    {if editing and len(repos) > 0 {
                        <div key="chips" className="flex flex-wrap gap-1.5">
                            {for r in repos {
                                <Badge
                                    key={r.id}
                                    variant="secondary"
                                    className="cursor-pointer font-normal"
                                    title="Click to remove"
                                    onClick={lambda { if onRemoveRepo { onRemoveRepo(r.id); } }}
                                >
                                    {r.full_name} ✕
                                </Badge>
                            }}
                        </div>
                    }}
                    <Input
                        placeholder="Paste a GitHub link or org/repo"
                        value={repoDraft}
                        onChange={lambda (e: ChangeEvent) { if onRepoDraft { onRepoDraft(e.target.value); } }}
                    />
                </div>
            </div>
            <DialogFooter>
                <Button variant="outline" onClick={lambda { onOpenChange(False); }}>
                    Cancel
                </Button>
                <Button onClick={onSave} disabled={saving or not name.strip()}>
                    Save
                </Button>
            </DialogFooter>
        </DialogContent>
    </Dialog>
}
