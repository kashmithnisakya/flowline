"""Create/edit dialog for a project. Repos are attached here: an optional repo
field at creation, the full chip list (remove + add) when editing.
"""

import from ...models { RepoView }
import from ..ui.button { Button }
import from ..ui.dialog {
    Dialog,
    DialogContent,
    DialogHeader,
    DialogTitle,
    DialogFooter
}
import from ..ui.input { Input }
import from ..ui.label { Label }
import from ..ui.textarea { Textarea }
import from ..common.glyphs { Spinner }

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
    return
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="bg-card">
                <DialogHeader>
                    <DialogTitle>
                        {"Edit project" if editing else "New project"}
                    </DialogTitle>
                </DialogHeader>
                <div className="grid gap-4 py-2">
                    <div className="grid gap-2">
                        <Label>Name</Label>
                        <Input
                            value={name}
                            onChange={lambda (e: ChangeEvent) { onName(
                                e.target.value
                            ); }}
                        />
                    </div>
                    <div className="grid gap-2">
                        <Label>Description</Label>
                        <Textarea
                            value={description}
                            onChange={lambda (e: ChangeEvent) { onDescription(
                                e.target.value
                            ); }}
                        />
                    </div>
                    <div className="grid gap-2">
                        <Label>
                            {"Repositories"
                                if editing
                                else "GitHub repository (optional)"}
                        </Label>
                        {if editing and len(repos) > 0 {
                            <ul key="repos" className="surface divide-y">
                                {for r in repos {
                                    <li
                                        key={r.id}
                                        className="flex items-center gap-2 px-3 py-1.5"
                                    >
                                        <span
                                            className="num min-w-0 flex-1 truncate text-[13px]"
                                        >
                                            {r.full_name}
                                        </span>
                                        <Button
                                            variant="ghost"
                                            size="sm"
                                            className="text-muted-foreground"
                                            onClick={lambda { if onRemoveRepo {
                                                onRemoveRepo(r.id);
                                            }}}
                                        >
                                            Remove
                                        </Button>
                                    </li>
                                }}
                            </ul>
                        }}
                        <Input
                            placeholder="Paste a GitHub link, or org/repo"
                            value={repoDraft}
                            onChange={lambda (e: ChangeEvent) { if onRepoDraft {
                                onRepoDraft(e.target.value);
                            }}}
                        />
                    </div>
                </div>
                <DialogFooter>
                    <Button variant="outline" onClick={lambda { onOpenChange(False); }}>
                        Cancel
                    </Button>
                    <Button onClick={onSave} disabled={saving or not name.strip()}>
                        {if saving {
                            <Spinner key="sp"/>
                        }}
                        {"Saving…" if saving else "Save"}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>;
}
