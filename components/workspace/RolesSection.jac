"""Manage the org's roles and who holds them. Roles are Role nodes (seeded by
the template, editable here): add creates, edit renames through every member
and step owner, delete strips from everyone. Assignment goes through
SetMemberRoles, which touches only the role list. Any number of roles per person."""

import from ...models { MemberView, RoleView }
import from ...walkers.roster {
    ListMembers,
    SetMemberRoles,
    ListRoles,
    SaveRole,
    DeleteRole
}
import from ..workflow.kinds { DOT_FILL, colorKey }
import from ..ui.card { Card, CardContent }
import from ..ui.badge { Badge }
import from ..ui.input { Input }
import from ..ui.button { Button }
import from ..ui.skeleton { Skeleton }
import from "sonner" { toast }


def:pub RolesSection(onChanged: Callable[[], None] = None) -> JsxElement {
    has members: list[MemberView] = [],
        roles: list[RoleView] = [],
        newRole: str = "",
        # Name of the role whose card is in edit mode, with the drafts the
        # inputs bind to. Empty means nothing is being edited.
        editingRole: str = "",
        editName: str = "",
        editBlurb: str = "",
        # Name pending the two-click delete confirm.
        confirmDelete: str = "",
        loading: bool = True,
        saving: bool = False;

    async can with entry {
        load();
    }

    async def load -> None;
    async def toggleRole(memberId: str, role: str) -> None;
    async def addRole -> None;
    def startEdit(name: str, blurb: str) -> None;
    async def saveEdit -> None;
    async def deleteRole(name: str) -> None;

    active = [
        m
        for m in members
        if m.active
    ];

    # Managed roles first, in their stored order, then any free-text role
    # still in use that has no node yet. One list drives the cards.
    managed: list[str] = [];
    cards: list[dict[str, str]] = [];
    for r in roles {
        managed.append(r.name);
        cards.append(
            {"name": r.name, "blurb": r.blurb, "color": r.color, "managed": "y"}
        );
    }
    for m in active {
        for held in m.roles {
            if held not in managed {
                managed.append(held);
                cards.append({"name": held, "blurb": "", "color": "", "managed": ""});
            }
        }
    }

    unassigned = [
        m
        for m in active
        if len(m.roles) == 0
    ];
    unassignedNames: list[str] = [];
    for m in unassigned {
        unassignedNames.append(m.name);
    }

    return
        <div className="flex flex-col gap-4">
            {if loading {
                <div key="sk" className="grid gap-3 sm:grid-cols-2">
                    {for i in [0, 1, 2, 3] {
                        <div
                            key={"r" + str(i)}
                            className="flex flex-col gap-3 rounded-xl border bg-card p-4"
                        >
                            <Skeleton className="h-4 w-36"/>
                            <Skeleton className="h-3 w-48 max-w-full"/>
                            <div className="flex gap-1.5">
                                <Skeleton className="h-5 w-16 rounded-full"/>
                                <Skeleton className="h-5 w-20 rounded-full"/>
                            </div>
                        </div>
                    }}
                </div>
            } else {
                <div key="body" className="flex flex-col gap-4">
                    <p className="text-sm text-muted-foreground">
                        Roles are shared by the whole workspace: workflow steps name their owner role, and a person can hold several. Click a name on a card to toggle it.
                    </p>
                    {if len(cards) == 0 {
                        <div
                            key="empty"
                            className="rounded-xl border border-dashed bg-card p-8 text-center text-sm text-muted-foreground"
                        >
                            No roles yet. Add the first one below, or apply a workflow template that brings its own.
                        </div>
                    } else {
                        <div key="cards" className="grid gap-3 sm:grid-cols-2">
                            {for card in cards {
                                <Card key={card["name"]}>
                                    <CardContent className="flex flex-col gap-3 py-4">
                                        {if editingRole == card["name"] {
                                            <div
                                                key="edit"
                                                className="flex flex-col gap-2"
                                            >
                                                <Input
                                                    className="h-8"
                                                    value={editName}
                                                    autoFocus={True}
                                                    onChange={lambda (e: ChangeEvent) { editName = e.target.value; }}
                                                    onKeyDown={lambda (
                                                        e: KeyboardEvent
                                                    ) { if e.key == "Enter" {
                                                        e.preventDefault();
                                                        saveEdit();
                                                    }}}
                                                />
                                                <Input
                                                    className="h-8"
                                                    placeholder="What this role does (optional)"
                                                    value={editBlurb}
                                                    onChange={lambda (e: ChangeEvent) { editBlurb = e.target.value; }}
                                                    onKeyDown={lambda (
                                                        e: KeyboardEvent
                                                    ) { if e.key == "Enter" {
                                                        e.preventDefault();
                                                        saveEdit();
                                                    }}}
                                                />
                                                <div className="flex gap-2">
                                                    <Button
                                                        size="sm"
                                                        onClick={saveEdit}
                                                        disabled={saving
                                                        or not editName.strip()}
                                                    >
                                                        Save
                                                    </Button>
                                                    <Button
                                                        size="sm"
                                                        variant="ghost"
                                                        onClick={lambda { editingRole = ""; }}
                                                    >
                                                        Cancel
                                                    </Button>
                                                </div>
                                            </div>
                                        } else {
                                            <div
                                                key="head"
                                                className="flex flex-col gap-1"
                                            >
                                                <div
                                                    className="flex items-center gap-2"
                                                >
                                                    <span
                                                        className={"h-2.5 w-2.5 shrink-0 rounded-full " + DOT_FILL[
                                                            colorKey(
                                                                card["color"] or "slate"
                                                            )
                                                        ]}
                                                    />
                                                    <span
                                                        className="text-sm font-semibold"
                                                    >
                                                        {card["name"]}
                                                    </span>
                                                    <div className="flex-1"/>
                                                    <Button
                                                        variant="ghost"
                                                        size="sm"
                                                        className="h-7 px-2 text-xs text-muted-foreground"
                                                        onClick={lambda { startEdit(
                                                            card["name"], card["blurb"]
                                                        ); }}
                                                    >
                                                        Edit
                                                    </Button>
                                                    {if confirmDelete == card["name"] {
                                                        <span
                                                            key="confirm"
                                                            className="flex items-center gap-1"
                                                        >
                                                            <Button
                                                                variant="destructive"
                                                                size="sm"
                                                                className="h-7 px-2 text-xs"
                                                                disabled={saving}
                                                                onClick={lambda { deleteRole(
                                                                    card["name"]
                                                                ); }}
                                                            >
                                                                Remove from everyone
                                                            </Button>
                                                            <Button
                                                                variant="ghost"
                                                                size="sm"
                                                                className="h-7 px-2 text-xs"
                                                                onClick={lambda { confirmDelete = ""; }}
                                                            >
                                                                Keep
                                                            </Button>
                                                        </span>
                                                    } else {
                                                        <Button
                                                            key="del"
                                                            variant="ghost"
                                                            size="sm"
                                                            className="h-7 px-2 text-xs text-muted-foreground hover:text-destructive"
                                                            onClick={lambda { confirmDelete = card[
                                                                "name"
                                                            ]; }}
                                                        >
                                                            Delete
                                                        </Button>
                                                    } }
                                                </div>
                                                {if card["blurb"] {
                                                    <p
                                                        key="blurb"
                                                        className="text-xs text-muted-foreground"
                                                    >
                                                        {card["blurb"]}
                                                    </p>
                                                }}
                                            </div>
                                        } }
                                        <div
                                            className="flex flex-wrap items-center gap-1.5"
                                        >
                                            {for m in active {
                                                <Badge
                                                    key={m.id}
                                                    variant={"default"
                                                        if card["name"] in m.roles
                                                        else "outline"}
                                                    className={"cursor-pointer " + (
                                                        ""
                                                            if card["name"] in m.roles
                                                            else "hover:bg-accent hover:text-accent-foreground"
                                                    )}
                                                    onClick={lambda { toggleRole(
                                                        m.id, card["name"]
                                                    ); }}
                                                >
                                                    {m.name}
                                                </Badge>
                                            }}
                                            {if len(active) == 0 {
                                                <span
                                                    key="noone"
                                                    className="text-xs text-muted-foreground"
                                                >
                                                    No one on the roster yet. Add people on the People tab.
                                                </span>
                                            }}
                                        </div>
                                    </CardContent>
                                </Card>
                            }}
                        </div>
                    } }
                    <div className="flex items-center gap-2">
                        <Input
                            className="h-8 w-56"
                            placeholder="New role"
                            value={newRole}
                            onChange={lambda (e: ChangeEvent) { newRole = e.target.value; }}
                            onKeyDown={lambda (e: KeyboardEvent) { if e.key == "Enter" {
                                e.preventDefault();
                                addRole();
                            }}}
                        />
                        <Button
                            size="sm"
                            variant="outline"
                            onClick={addRole}
                            disabled={saving or not newRole.strip()}
                        >
                            Add role
                        </Button>
                    </div>
                    {if len(unassignedNames) > 0 {
                        <p key="unassigned" className="text-xs text-muted-foreground">
                            {"No role yet: " + ", ".join(unassignedNames)}
                        </p>
                    }}
                </div>
            } }
        </div>;
}
