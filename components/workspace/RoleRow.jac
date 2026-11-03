"""One role: who holds it (assigned right here), the steps that name it as owner,
its AI, and its own menu. A free-text role has no Role node, so no AI chip."""

import from ...models { StepView, ResponsibilityView }
import from ..common.StepName { StepName }
import from ..roster.AssignMenu { AssignMenu }
import from .RoleAiChips { RoleAiChips }
import from .RowActions { RowActions }

glob:pub ROLE_GRID: str = "grid grid-cols-[minmax(0,1fr)_auto] items-center gap-x-4 gap-y-1 md:grid-cols-[minmax(0,1.2fr)_minmax(0,1fr)_minmax(0,1fr)_minmax(0,1fr)_40px]";

def:pub RoleRow(
    card: dict[str, str],
    steps: list[StepView],
    items: list[ResponsibilityView],
    memberIds: list[str],
    memberNames: list[str],
    holders: list[str],
    onPeople: Callable[[], None],
    onHolders: Callable[[list[str]], None],
    onRename: Callable[[], None],
    onDelete: Callable[[], None]
) -> JsxElement {
    owned = [
        x
        for x in steps
        if x.owner == card["name"]
    ];
    return
        <div className={ROLE_GRID}>
            <div className="col-start-1 row-start-1 min-w-0">
                <div className="truncate text-sm font-medium md:text-[13.5px]">
                    {card["name"]}
                </div>
                {if card["blurb"] {
                    <div key="blurb" className="truncate text-xs text-muted-foreground">
                        {card["blurb"]}
                    </div>
                }}
            </div>
            <div
                className="col-start-1 row-start-2 flex min-w-0 flex-wrap items-center gap-x-3 gap-y-1 md:contents"
            >
                <div className="min-w-0 md:col-start-2">
                    <AssignMenu
                        label={"People holding " + card["name"]}
                        values={memberIds}
                        names={memberNames}
                        selected={holders}
                        emptyText="No one yet"
                        noneText="No people on the roster yet"
                        footerLabel="Manage people"
                        onFooter={onPeople}
                        onCommit={onHolders}
                    />
                </div>
                <div className="min-w-0 md:col-start-3">
                    <a
                        href="/flowlines"
                        className="flex min-w-0 flex-wrap items-center gap-x-2 gap-y-0.5 text-[12.5px] text-muted-foreground underline-offset-2 hover:text-foreground hover:underline"
                    >
                        {for s in owned {
                            <StepName
                                key={s.id}
                                name={s.name}
                                color={s.color}
                                className="text-[12.5px]"
                            />
                        }}
                        {if len(owned) == 0 {
                            <span key="none">Owns no step yet</span>
                        }}
                    </a>
                </div>
                <div className="min-w-0 md:col-start-4">
                    {if card["id"] {
                        <RoleAiChips key="ai" role={card["name"]} items={items}/>
                    }}
                </div>
            </div>
            <div
                className="col-start-2 row-span-2 row-start-1 justify-self-end md:col-start-5 md:row-span-1"
            >
                <RowActions
                    label={"Actions for " + card["name"]}
                    editLabel="Rename"
                    dangerLabel="Delete"
                    onEdit={onRename}
                    onDanger={onDelete}
                />
            </div>
        </div>;
}
