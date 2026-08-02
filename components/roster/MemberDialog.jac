"""Create/edit dialog for a roster member.

v2.3: members carry multiple roles (free-text chips), multiple tags
(picked from the workspace vocabulary) and multiple project assignments
(toggle chips). The page owns all state; `form` carries name, email,
github and the in-progress role draft.
"""

import from ...models { Project }
import from ..ui.button { Button }
import from ..ui.badge { Badge }
import from ..ui.dialog {
    Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter
}
import from ..ui.input { Input }
import from ..ui.label { Label }

def:pub MemberDialog(
    open: bool,
    editing: bool,
    form: dict[str, str],
    roles: list[str],
    memberTags: list[str],
    allTags: list[str],
    projects: list[Project],
    selectedProjectIds: list[str],
    saving: bool,
    onField: Callable[[str, str], None],
    onAddRole: Callable[[], None],
    onRemoveRole: Callable[[str], None],
    onToggleTag: Callable[[str], None],
    onToggleProject: Callable[[str], None],
    onOpenChange: Callable[[bool], None],
    onSave: Callable[[], None]
) -> JsxElement {
    return <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="sm:max-w-xl">
            <DialogHeader>
                <DialogTitle>{"Edit member" if editing else "Add member"}</DialogTitle>
                <DialogDescription>
                    Members are roster records. They do not need accounts.
                </DialogDescription>
            </DialogHeader>
            <div className="grid gap-4 py-2">
                <div className="grid gap-1.5">
                    <Label>Name</Label>
                    <Input
                        placeholder="Full name"
                        value={form["name"]}
                        onChange={lambda (e: ChangeEvent) { onField("name", e.target.value); }}
                    />
                </div>
                <div className="grid gap-1.5">
                    <Label>Roles</Label>
                    <div className="flex flex-wrap items-center gap-1.5">
                        {for r in roles {
                            <Badge
                                key={r}
                                variant="secondary"
                                className="cursor-pointer"
                                title="Click to remove"
                                onClick={lambda { onRemoveRole(r); }}
                            >
                                {r} ✕
                            </Badge>
                        }}
                        <Input
                            placeholder={"Add a role and press Enter" if len(roles) == 0 else "Another role…"}
                            className="h-8 w-56"
                            value={form["roleDraft"]}
                            onChange={lambda (e: ChangeEvent) { onField("roleDraft", e.target.value); }}
                            onKeyDown={lambda (e: KeyboardEvent) {
                                if e.key == "Enter" {
                                    e.preventDefault();
                                    onAddRole();
                                }
                            }}
                        />
                    </div>
                </div>
                <div className="grid gap-1.5">
                    <Label>Tags</Label>
                    {if len(allTags) > 0 {
                        <div key="tags" className="flex flex-wrap gap-1.5">
                            {for t in allTags {
                                <Badge
                                    key={t}
                                    variant={"default" if t in memberTags else "outline"}
                                    className="cursor-pointer"
                                    onClick={lambda { onToggleTag(t); }}
                                >
                                    {t}
                                </Badge>
                            }}
                        </div>
                    } else {
                        <p key="notags" className="text-xs text-muted-foreground">
                            No tags defined yet. Add them on the Workspace tab.
                        </p>
                    }}
                </div>
                <div className="grid gap-1.5">
                    <Label>Projects</Label>
                    {if len(projects) > 0 {
                        <div key="projects" className="flex flex-wrap gap-1.5">
                            {for p in projects {
                                <Badge
                                    key={jid(p)}
                                    variant={"default" if jid(p) in selectedProjectIds else "outline"}
                                    className="cursor-pointer"
                                    onClick={lambda { onToggleProject(jid(p)); }}
                                >
                                    {p.name}
                                </Badge>
                            }}
                        </div>
                    } else {
                        <p key="noproj" className="text-xs text-muted-foreground">
                            No projects yet.
                        </p>
                    }}
                </div>
                <div className="grid gap-3 sm:grid-cols-2">
                    <div className="grid gap-1.5">
                        <Label>Email</Label>
                        <Input
                            type="email"
                            placeholder="Optional"
                            value={form["email"]}
                            onChange={lambda (e: ChangeEvent) { onField("email", e.target.value); }}
                        />
                    </div>
                    <div className="grid gap-1.5">
                        <Label>GitHub username</Label>
                        <Input
                            placeholder="Optional"
                            value={form["github"]}
                            onChange={lambda (e: ChangeEvent) { onField("github", e.target.value); }}
                        />
                    </div>
                </div>
            </div>
            <DialogFooter>
                <Button variant="outline" onClick={lambda { onOpenChange(False); }}>
                    Cancel
                </Button>
                <Button onClick={onSave} disabled={saving or not form["name"].strip()}>
                    {"Save changes" if editing else "Add member"}
                </Button>
            </DialogFooter>
        </DialogContent>
    </Dialog>;
}
