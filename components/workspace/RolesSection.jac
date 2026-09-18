"""Roles: the link between people and the flow line. Each row says who holds
the role (assigned right here) and which steps name it as their owner, and
renames or deletes it from its own menu.
"""

import from ...models { MemberView, RoleView, StepView }
import from ...lib.workspace { forgetWorkspace }
import from ...services.roster.roster {
    ListMembers,
    ListRoles,
    SaveRole,
    DeleteRole,
    SetMemberRoles
}
import from ...services.flowlines.flowlines { GetFlowLine }
import from ..common.StepName { StepName }
import from ..roster.AssignMenu { AssignMenu }
import from ..ui.button { Button }
import from ..ui.input { Input }
import from ..ui.skeleton { Skeleton }
import from ..common.Reveal { Reveal }
import from .ConfirmDialog { ConfirmDialog }
import from .RowActions { RowActions }
import from .SectionHeader { SectionHeader }
import from .icons { IconPlus }
import from "sonner" { toast }


def:pub RolesSection(
    onChanged: Callable[[], None] = None, onPeople: Callable[[], None] = None
) -> JsxElement {
    has members: list[MemberView] = [],
        roles: list[RoleView] = [],
        steps: list[StepView] = [],
        loading: bool = True,
        saving: bool = False,
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

    async can with entry {
        load();
    }

    async def load -> None;
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
        cards.append({"name": r.name, "blurb": r.blurb, "color": r.color});
    }
    for m in active {
        for held in m.roles {
            if held not in known {
                known.append(held);
                cards.append({"name": held, "blurb": "", "color": ""});
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
    def loadFrame -> JsxElement {
        return
            <div key="sk" className="surface" aria-busy="true">
                <div
                    className="hidden grid-cols-[minmax(0,1.3fr)_minmax(0,1fr)_minmax(0,1fr)_40px] items-center gap-x-4 border-b px-3 py-2 text-[12.5px] text-muted-foreground md:grid"
                >
                    <span>Role</span>
                    <span>Held by</span>
                    <span>Flow line</span>
                    <span/>
                </div>
                <ul className="divide-y">
                    {for i in [0, 1, 2] {
                        <li key={"r" + str(i)} className="px-3 py-2.5 md:py-2">
                            <div
                                className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-x-4 gap-y-1 md:grid-cols-[minmax(0,1.3fr)_minmax(0,1fr)_minmax(0,1fr)_40px]"
                            >
                                <div className="col-start-1 row-start-1 min-w-0">
                                    <div className="flex h-5 items-center">
                                        <Skeleton
                                            className={"h-3.5 "
                                                + ("w-24" if i % 2 else "w-32")}
                                        />
                                    </div>
                                    <div className="flex h-4 items-center">
                                        <Skeleton className="h-3 w-40"/>
                                    </div>
                                </div>
                                <div
                                    className="col-start-1 row-start-2 flex min-w-0 flex-wrap items-center gap-x-3 gap-y-1 md:contents"
                                >
                                    <div className="min-w-0 md:col-start-2">
                                        <Skeleton className="h-3.5 w-36"/>
                                    </div>
                                    <div className="min-w-0 md:col-start-3">
                                        <Skeleton className="h-3 w-28"/>
                                    </div>
                                </div>
                                <div
                                    className="col-start-2 row-span-2 row-start-1 justify-self-end md:col-start-4 md:row-span-1"
                                />
                            </div>
                        </li>
                    }}
                </ul>
            </div>;
    }

    return
        <div className="flex flex-col gap-4">
            <SectionHeader title="Roles" count={"" if loading else str(len(cards))}>
                <Button size="sm" onClick={startAdd}>
                    <IconPlus/>
                    Add role
                </Button>
            </SectionHeader>
            <Reveal ready={not loading} frame={loadFrame()}>
                <div key="rows" className="surface">
                    <div
                        className={"hidden grid-cols-[minmax(0,1.3fr)_minmax(0,1fr)_minmax(0,1fr)_40px] items-center gap-x-4 border-b px-3 py-2 text-[12.5px] text-muted-foreground "
                            + ("md:grid" if len(cards) > 0 else "")}
                    >
                        <span>Role</span>
                        <span>Held by</span>
                        <span>Flow line</span>
                        <span/>
                    </div>
                    {if adding {
                        <div key="add" className="border-b px-3 py-2.5">
                            <form
                                className="flex flex-wrap items-center gap-2"
                                onSubmit={lambda (e: FormEvent) {
                                    e.preventDefault();
                                    addRole();
                                }}
                            >
                                <Input
                                    className="h-8 w-48"
                                    placeholder="Role name"
                                    autoFocus={True}
                                    value={newRole}
                                    onChange={lambda (e: ChangeEvent) { newRole = e.target.value; }}
                                />
                                <Input
                                    className="h-8 w-64 max-w-full"
                                    placeholder="What this role does (optional)"
                                    value={newBlurb}
                                    onChange={lambda (e: ChangeEvent) { newBlurb = e.target.value; }}
                                />
                                <Button
                                    type="submit"
                                    size="sm"
                                    disabled={saving or not newRole.strip()}
                                >
                                    Add role
                                </Button>
                                <Button
                                    type="button"
                                    size="sm"
                                    variant="ghost"
                                    onClick={lambda { adding = False; }}
                                >
                                    Cancel
                                </Button>
                            </form>
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
                                    <form
                                        key="edit"
                                        className="flex flex-wrap items-center gap-2"
                                        onSubmit={lambda (e: FormEvent) {
                                            e.preventDefault();
                                            saveEdit();
                                        }}
                                    >
                                        <Input
                                            className="h-8 w-48"
                                            autoFocus={True}
                                            value={editName}
                                            onChange={lambda (e: ChangeEvent) { editName = e.target.value; }}
                                        />
                                        <Input
                                            className="h-8 w-64 max-w-full"
                                            placeholder="What this role does (optional)"
                                            value={editBlurb}
                                            onChange={lambda (e: ChangeEvent) { editBlurb = e.target.value; }}
                                        />
                                        <Button
                                            type="submit"
                                            size="sm"
                                            disabled={saving or not editName.strip()}
                                        >
                                            Save
                                        </Button>
                                        <Button
                                            type="button"
                                            size="sm"
                                            variant="ghost"
                                            onClick={lambda { editingRole = ""; }}
                                        >
                                            Cancel
                                        </Button>
                                    </form>
                                } else {
                                    <div
                                        key="row"
                                        className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-x-4 gap-y-1 md:grid-cols-[minmax(0,1.3fr)_minmax(0,1fr)_minmax(0,1fr)_40px]"
                                    >
                                        <div
                                            className="col-start-1 row-start-1 min-w-0"
                                        >
                                            <div
                                                className="truncate text-sm font-medium md:text-[13.5px]"
                                            >
                                                {card["name"]}
                                            </div>
                                            {if card["blurb"] {
                                                <div
                                                    key="blurb"
                                                    className="truncate text-xs text-muted-foreground"
                                                >
                                                    {card["blurb"]}
                                                </div>
                                            }}
                                        </div>
                                        <div
                                            className="col-start-1 row-start-2 flex min-w-0 flex-wrap items-center gap-x-3 gap-y-1 md:contents"
                                        >
                                            <div className="min-w-0 md:col-start-2">
                                                <AssignMenu
                                                    label={"People holding "
                                                        + card["name"]}
                                                    values={memberIds}
                                                    names={memberNames}
                                                    selected={holdersOf[card["name"]]}
                                                    emptyText="No one yet"
                                                    noneText="No people on the roster yet"
                                                    footerLabel="Manage people"
                                                    onFooter={onPeople}
                                                    onCommit={lambda (
                                                        next: list[str]
                                                    ) { setHolders(
                                                        card["name"], next, True
                                                    ); }}
                                                />
                                            </div>
                                            <div className="min-w-0 md:col-start-3">
                                                <a
                                                    href="/flowlines"
                                                    className="flex min-w-0 flex-wrap items-center gap-x-2 gap-y-0.5 text-[12.5px] text-muted-foreground underline-offset-2 hover:text-foreground hover:underline"
                                                >
                                                    {for s in [
                                                        x
                                                        for x in steps
                                                        if x.owner == card["name"]
                                                    ] {
                                                        <StepName
                                                            key={s.id}
                                                            name={s.name}
                                                            color={s.color}
                                                            className="text-[12.5px]"
                                                        />
                                                    }}
                                                    {if len(
                                                        [
                                                            x
                                                            for x in steps
                                                            if x.owner == card["name"]
                                                        ]
                                                    )
                                                        == 0 {
                                                        <span key="none">
                                                            Owns no step yet
                                                        </span>
                                                    }}
                                                </a>
                                            </div>
                                        </div>
                                        <div
                                            className="col-start-2 row-span-2 row-start-1 justify-self-end md:col-start-4 md:row-span-1"
                                        >
                                            <RowActions
                                                label={"Actions for " + card["name"]}
                                                editLabel="Rename"
                                                dangerLabel="Delete"
                                                onEdit={lambda { startEdit(
                                                    card["name"], card["blurb"]
                                                ); }}
                                                onDanger={lambda { deleteTarget = card[
                                                    "name"
                                                ]; }}
                                            />
                                        </div>
                                    </div>
                                } }
                            </li>
                        }}
                    </ul>
                </div>
            </Reveal>
            {if len(unplaced) > 0 {
                <p key="unplaced" className="text-[13px] text-muted-foreground">
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
        </div>;
}
