"""Create/edit dialog for a roster member: multiple roles, tags and project
assignments as chips; the page owns all state. Roles follow the workspace: a
non-empty `roleOptions` renders toggle chips (held roles outside the options
stay removable), empty falls back to type-and-enter free text."""

import from ...models { Project }
import from ..ui.button { Button }
import from ..ui.badge { Badge }
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
import from ..common.glyphs { Spinner }

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
    onAddTag: Callable[[], None],
    onRemoveRole: Callable[[str], None],
    onToggleTag: Callable[[str], None],
    onToggleProject: Callable[[str], None],
    onOpenChange: Callable[[bool], None],
    onSave: Callable[[], None],
    roleOptions: list[str] = [],
    onToggleRole: Callable[[str], None] = None
) -> JsxElement {
    # Filter BEFORE the loop: a wrapper span around a conditional chip stays
    # in the flex row as an empty item and doubles the gap.
    unselectedTags = [
        t
        for t in allTags
        if t not in memberTags
    ];
    # Held roles the flow line does not define (free-text from before a
    # template was applied). Shown as removable chips beside the options.
    extraRoles = [
        r
        for r in roles
        if r not in roleOptions
    ];
    return
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="sm:max-w-xl">
                <DialogHeader>
                    <DialogTitle>
                        {"Edit member" if editing else "Add member"}
                    </DialogTitle>
                    <DialogDescription>
                        Members are roster records. They do not need accounts.
                    </DialogDescription>
                </DialogHeader>
                <div className="grid gap-4 py-2">
                    <div className="grid gap-2">
                        <Label>Name</Label>
                        <Input
                            placeholder="Full name"
                            value={form["name"]}
                            onChange={lambda (e: ChangeEvent) { onField(
                                "name", e.target.value
                            ); }}
                        />
                    </div>
                    <div className="grid gap-2">
                        <Label>Roles</Label>
                        {if len(roleOptions) > 0 {
                            <div
                                key="fixed"
                                className="flex flex-wrap items-center gap-1.5"
                            >
                                {for opt in roleOptions {
                                    <Badge
                                        key={opt}
                                        variant={"default"
                                            if opt in roles
                                            else "outline"}
                                        className={"cursor-pointer "
                                            + (
                                                ""
                                                    if opt in roles
                                                    else "hover:bg-accent hover:text-accent-foreground"
                                            )}
                                        onClick={lambda { if onToggleRole {
                                            onToggleRole(opt);
                                        }}}
                                    >
                                        {opt}
                                    </Badge>
                                }}
                                {for extra in extraRoles {
                                    <Badge
                                        key={"x-" + extra}
                                        variant="secondary"
                                        className="cursor-pointer animate-in fade-in zoom-in-95 duration-150 hover:bg-destructive/15 hover:text-destructive"
                                        title="Not one of this flow line's roles. Click to remove"
                                        onClick={lambda { if onToggleRole {
                                            onToggleRole(extra);
                                        }}}
                                    >
                                        {extra + " ✕"}
                                    </Badge>
                                }}
                            </div>
                        } else {
                            <div
                                key="free"
                                className="flex flex-wrap items-center gap-1.5"
                            >
                                {for r in roles {
                                    <Badge
                                        key={r}
                                        variant="secondary"
                                        className="cursor-pointer animate-in fade-in zoom-in-95 duration-150 hover:bg-destructive/15 hover:text-destructive"
                                        title="Click to remove"
                                        onClick={lambda { onRemoveRole(r); }}
                                    >
                                        {r} ✕
                                    </Badge>
                                }}
                                <Input
                                    placeholder={"Add a role and press Enter"
                                        if len(roles) == 0
                                        else "Another role…"}
                                    className="h-8 w-56"
                                    value={form["roleDraft"]}
                                    onChange={lambda (e: ChangeEvent) { onField(
                                        "roleDraft", e.target.value
                                    ); }}
                                    onKeyDown={lambda (e: KeyboardEvent) { if e.key
                                        == "Enter" {
                                        e.preventDefault();
                                        onAddRole();
                                    }}}
                                />
                            </div>
                        } }
                    </div>
                    <div className="grid gap-2">
                        <Label>Tags</Label>
                        <div className="flex flex-wrap items-center gap-1.5">
                            {for t in memberTags {
                                <Badge
                                    key={t}
                                    variant="default"
                                    className="cursor-pointer animate-in fade-in zoom-in-95 duration-150 hover:bg-destructive/15 hover:text-destructive"
                                    title="Click to remove"
                                    onClick={lambda { onToggleTag(t); }}
                                >
                                    {t + " ✕"}
                                </Badge>
                            }}
                            {for t in unselectedTags {
                                <Badge
                                    key={"s-" + t}
                                    variant="outline"
                                    className="cursor-pointer animate-in fade-in zoom-in-95 duration-150 hover:bg-accent hover:text-accent-foreground"
                                    title="Click to add"
                                    onClick={lambda { onToggleTag(t); }}
                                >
                                    {t}
                                </Badge>
                            }}
                            <Input
                                placeholder={"Add a tag and press Enter"
                                    if len(memberTags) == 0
                                    else "Another tag…"}
                                className="h-8 w-56"
                                value={form["tagDraft"]}
                                onChange={lambda (e: ChangeEvent) { onField(
                                    "tagDraft", e.target.value
                                ); }}
                                onKeyDown={lambda (e: KeyboardEvent) { if e.key
                                    == "Enter" {
                                    e.preventDefault();
                                    onAddTag();
                                }}}
                            />
                        </div>
                    </div>
                    <div className="grid gap-2">
                        <Label>Projects</Label>
                        {if len(projects) > 0 {
                            <div key="projects" className="flex flex-wrap gap-1.5">
                                {for p in projects {
                                    <Badge
                                        key={jid(p)}
                                        variant={"default"
                                            if jid(p) in selectedProjectIds
                                            else "outline"}
                                        className={"cursor-pointer "
                                            + (
                                                ""
                                                    if jid(p) in selectedProjectIds
                                                    else "hover:bg-accent hover:text-accent-foreground"
                                            )}
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
                        } }
                    </div>
                    <div className="grid gap-4 sm:grid-cols-2">
                        <div className="grid gap-2">
                            <Label>Email</Label>
                            <Input
                                type="email"
                                placeholder="Optional"
                                value={form["email"]}
                                onChange={lambda (e: ChangeEvent) { onField(
                                    "email", e.target.value
                                ); }}
                            />
                        </div>
                        <div className="grid gap-2">
                            <Label>GitHub username</Label>
                            <Input
                                placeholder="Optional"
                                value={form["github"]}
                                onChange={lambda (e: ChangeEvent) { onField(
                                    "github", e.target.value
                                ); }}
                            />
                        </div>
                    </div>
                </div>
                <DialogFooter>
                    <Button variant="outline" onClick={lambda { onOpenChange(False); }}>
                        Cancel
                    </Button>
                    <Button
                        onClick={onSave}
                        disabled={saving or not form["name"].strip()}
                    >
                        {if saving {
                            <Spinner key="sp"/>
                        }}
                        {"Saving…"
                            if saving
                            else ("Save changes" if editing else "Add member")}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>;
}
