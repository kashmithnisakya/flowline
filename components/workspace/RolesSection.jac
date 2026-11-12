"""Roles: the link between people and the flow line. Each row says who holds
the role (assigned right here), which steps name it as their owner and what AI
it has (the AI page edits that), and renames or deletes it from its own menu.
The lists are the page's; a write here refetches through the page's own loader.
"""

import from ...models { MemberView, RoleView, StepView, ResponsibilityView }
import from ...lib.workspace { forgetWorkspace }
import from ...services.roster.roster { SaveRole, DeleteRole, SetMemberRoles }
import from ..ui.button { Button }
import from ..common.Reveal { Reveal }
import from .ConfirmDialog { ConfirmDialog }
import from .RoleForm { RoleForm }
import from .RoleRow { RoleRow }
import from .RolesFrame { RolesFrame, RolesHeads }
import from .SectionPanel { SectionPanel }
import from .icons { IconPlus }
import from "sonner" { toast }

def:pub RolesSection(
    members: list[MemberView] = [],
    roles: list[RoleView] = [],
    steps: list[StepView] = [],
    loading: bool = False,
    onChanged: Callable[[], any] = None,
    onPeople: Callable[[], None] = None,
    responsibilities: list[ResponsibilityView] = []
) -> JsxElement {
    has saving: bool = False,
        busy: bool = False,
        # The add row is open while this is set, with its own drafts.
        adding: bool = False,
        newRole: str = "",
        newBlurb: str = "",
        # Name of the role being renamed in place, with the drafts the inputs
        # bind to. Empty means nothing is being edited.
        editingRole: str = "",
        editName: str = "",
        editBlurb: str = "",
        deleteTarget: str = "";

    async def refresh -> None;
    async def addRole -> None;
    async def saveEdit -> None;
    async def removeRole -> None;
    async def setHolders(role: str, wanted: list[str], undoable: bool) -> None;
    def startEdit(name: str, blurb: str) -> None;
    def startAdd -> None;

    active = [
        m
        for m in members
        if m.active
    ];
    memberIds: list[str] = [];
    memberNames: list[str] = [];
    for m in active {
        memberIds.append(m.id);
        memberNames.append(m.name);
    }

    # Managed roles first, in their stored order, then any free-text role
    # still held by someone. One list drives the rows.
    known: list[str] = [];
    cards: list[dict[str, str]] = [];
    for r in roles {
        known.append(r.name);
        cards.append({"id": r.id, "name": r.name, "blurb": r.blurb, "color": r.color});
    }
    for m in active {
        for held in m.roles {
            if held not in known {
                known.append(held);
                cards.append({"id": "", "name": held, "blurb": "", "color": ""});
            }
        }
    }
    holdersOf: dict[str, list[str]] = {};
    for name in known {
        ids: list[str] = [];
        for m in active {
            if name in m.roles {
                ids.append(m.id);
            }
        }
        holdersOf[name] = ids;
    }
    unplaced: list[str] = [];
    for m in active {
        if len(m.roles) == 0 {
            unplaced.append(m.name);
        }
    }
    deleteCount = len(holdersOf[deleteTarget]) if deleteTarget in holdersOf else 0;

    return
        <SectionPanel
            section="roles"
            title="Roles"
            count={"" if loading else str(len(cards))}
            flush={True}
            actions={<Button size="sm" variant="outline" onClick={startAdd}>
                <IconPlus/>
                Add role
            </Button>}
        >
            <Reveal ready={not loading} frame={<RolesFrame/>}>
                <div key="rows">
                    <RolesHeads className={"md:grid" if len(cards) > 0 else ""}/>
                    {if adding {
                        <div key="add" className="border-b px-3 py-2.5">
                            <RoleForm
                                name={newRole}
                                blurb={newBlurb}
                                submitLabel="Add role"
                                saving={saving}
                                onName={lambda (v: str) { newRole = v; }}
                                onBlurb={lambda (v: str) { newBlurb = v; }}
                                onSubmit={addRole}
                                onCancel={lambda { adding = False; }}
                            />
                        </div>
                    }}
                    {if len(cards) == 0 and not adding {
                        <p
                            key="empty"
                            className="px-3 py-10 text-center text-sm text-muted-foreground"
                        >
                            No roles yet. Add one, or apply a flow line template that brings its own.
                        </p>
                    }}
                    <ul className="divide-y">
                        {for card in cards {
                            <li
                                key={card["name"]}
                                className="px-3 py-2.5 transition-colors duration-150 hover:bg-accent md:py-2"
                            >
                                {if editingRole == card["name"] {
                                    <RoleForm
                                        key="edit"
                                        name={editName}
                                        blurb={editBlurb}
                                        submitLabel="Save"
                                        saving={saving}
                                        onName={lambda (v: str) { editName = v; }}
                                        onBlurb={lambda (v: str) { editBlurb = v; }}
                                        onSubmit={saveEdit}
                                        onCancel={lambda { editingRole = ""; }}
                                    />
                                } else {
                                    <RoleRow
                                        key="row"
                                        card={card}
                                        steps={steps}
                                        items={[
                                            x
                                            for x in responsibilities
                                            if x.role_id == card["id"]
                                        ]}
                                        memberIds={memberIds}
                                        memberNames={memberNames}
                                        holders={holdersOf[card["name"]]}
                                        onPeople={onPeople}
                                        onHolders={lambda (next: list[str]) { setHolders(
                                            card["name"], next, True
                                        ); }}
                                        onRename={lambda { startEdit(
                                            card["name"], card["blurb"]
                                        ); }}
                                        onDelete={lambda { deleteTarget = card[
                                            "name"
                                        ]; }}
                                    />
                                } }
                            </li>
                        }}
                    </ul>
                </div>
            </Reveal>
            {if len(unplaced) > 0 {
                <p
                    key="unplaced"
                    className="border-t px-3 py-2.5 text-[13px] text-muted-foreground"
                >
                    {"No role yet: " + ", ".join(unplaced)}
                </p>
            }}
            <ConfirmDialog
                open={bool(deleteTarget)}
                title={"Delete the " + deleteTarget + " role?"}
                body={"It comes off "
                    + str(deleteCount)
                    + (" person" if deleteCount == 1 else " people")
                    + " and any flow line step that names it as owner. Nothing else changes."}
                confirmLabel="Delete role"
                busy={busy}
                onConfirm={removeRole}
                onOpenChange={lambda (o: bool) { if not o { deleteTarget = ""; }}}
            />
        </SectionPanel>;
}
