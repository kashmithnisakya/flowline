"""Create/edit dialog for a roster member: multiple roles, tags and project
assignments as chips; the page owns all state. Roles follow the workspace: a
non-empty `roleOptions` renders toggle chips (held roles outside the options
stay removable), empty falls back to type-and-enter free text."""

import from ...models { Project }
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
import from ..common.glyphs { Spinner }
import from ..common.Avatar { Avatar }
import from ..flowlines.kinds { COLOR_KEYS, DOT_FILL }
import from ..workspace.icons { IconCheck, IconX }

# A toggle chip, sentence case and square like every other control: picked
# shows a tick in foreground weight; a removable one ends in a cross.
def Chip(
    label: str,
    on: bool,
    onClick: Callable[[], None],
    removable: bool = False,
    hint: str = ""
) -> JsxElement {
    return
        <button
            type="button"
            aria-pressed={None if removable else on}
            aria-label={("Remove " + label) if removable else None}
            title={hint}
            className={"inline-flex h-7 items-center gap-1.5 rounded-sm border px-2 text-[13px] transition-colors duration-150 "
                + (
                    "border-foreground bg-card font-semibold text-foreground"
                        if on
                        else "border-border text-muted-foreground hover:bg-accent hover:text-foreground"
                )}
            onClick={lambda { onClick(); }}
        >
            {if on and not removable {
                <IconCheck key="tick" size={12}/>
            }}
            <span>{label}</span>
            {if removable {
                <IconX key="x" size={12} className="text-subtle"/>
            }}
        </button>;
}

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
    shown = (form["first_name"] + " " + form["last_name"]).strip();
    return
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="bg-card sm:max-w-xl">
                <DialogHeader>
                    <DialogTitle>
                        {"Edit person" if editing else "Add person"}
                    </DialogTitle>
                    <DialogDescription>
                        People do not need an account. Tasks and log entries are assigned to them.
                    </DialogDescription>
                </DialogHeader>
                <div className="grid gap-4 py-2">
                    <div className="grid gap-2">
                        <Label>Name</Label>
                        <div className="flex items-center gap-3">
                            <Avatar
                                name={shown or "?"}
                                size="md"
                                color={form["color"]}
                            />
                            <Input
                                className="min-w-0 flex-1"
                                placeholder="First name"
                                value={form["first_name"]}
                                onChange={lambda (e: ChangeEvent) { onField(
                                    "first_name", e.target.value
                                ); }}
                            />
                            <Input
                                className="min-w-0 flex-1"
                                placeholder="Last name"
                                value={form["last_name"]}
                                onChange={lambda (e: ChangeEvent) { onField(
                                    "last_name", e.target.value
                                ); }}
                            />
                        </div>
                    </div>
                    <div className="grid gap-2">
                        <Label>Colour</Label>
                        <div className="flex items-center gap-2">
                            {for c in COLOR_KEYS {
                                <button
                                    key={c}
                                    type="button"
                                    title={c}
                                    className={"h-6 w-6 rounded-md "
                                        + DOT_FILL[c]
                                        + (
                                            " ring-2 ring-ring ring-offset-2 ring-offset-card"
                                                if form["color"] == c
                                                else ""
                                        )}
                                    onClick={lambda { onField("color", c); }}
                                />
                            }}
                            <button
                                key="auto"
                                type="button"
                                title="Auto (from the name)"
                                className={"h-6 rounded-sm border px-2 text-xs "
                                    + (
                                        "border-foreground font-semibold text-foreground"
                                            if not form["color"]
                                            else "border-border text-muted-foreground hover:text-foreground"
                                    )}
                                onClick={lambda { onField("color", ""); }}
                            >
                                Auto
                            </button>
                        </div>
                    </div>
                    <div className="grid gap-2">
                        <Label>Roles</Label>
                        {if len(roleOptions) > 0 {
                            <div
                                key="fixed"
                                className="flex flex-wrap items-center gap-1.5"
                            >
                                {for opt in roleOptions {
                                    <Chip
                                        key={opt}
                                        label={opt}
                                        on={opt in roles}
                                        onClick={lambda { if onToggleRole {
                                            onToggleRole(opt);
                                        }}}
                                    />
                                }}
                                {for extra in extraRoles {
                                    <Chip
                                        key={"x-" + extra}
                                        label={extra}
                                        on={True}
                                        removable={True}
                                        hint="Not one of this workspace's roles"
                                        onClick={lambda { if onToggleRole {
                                            onToggleRole(extra);
                                        }}}
                                    />
                                }}
                            </div>
                        } else {
                            <div
                                key="free"
                                className="flex flex-wrap items-center gap-1.5"
                            >
                                {for r in roles {
                                    <Chip
                                        key={r}
                                        label={r}
                                        on={True}
                                        removable={True}
                                        onClick={lambda { onRemoveRole(r); }}
                                    />
                                }}
                                <Input
                                    placeholder={"Type a role and press Enter"
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
                                <Chip
                                    key={t}
                                    label={t}
                                    on={True}
                                    onClick={lambda { onToggleTag(t); }}
                                />
                            }}
                            {for t in unselectedTags {
                                <Chip
                                    key={"s-" + t}
                                    label={t}
                                    on={False}
                                    onClick={lambda { onToggleTag(t); }}
                                />
                            }}
                            <Input
                                placeholder={"Type a tag and press Enter"
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
                                    <Chip
                                        key={jid(p)}
                                        label={p.name}
                                        on={jid(p) in selectedProjectIds}
                                        onClick={lambda { onToggleProject(jid(p)); }}
                                    />
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
                        disabled={saving or not form["first_name"].strip()}
                    >
                        {if saving {
                            <Spinner key="sp"/>
                        }}
                        {"Saving…"
                            if saving
                            else ("Save changes" if editing else "Add person")}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>;
}
