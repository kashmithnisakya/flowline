"""People on the Overview, one PersonRow each. The columns follow the
panel's own width: when narrow the counts fold under the name. `placeholder`
draws `placeholderRows` skeleton rows, the count the last visit had."""

import from .Panel { Panel, EmptyLine }
import from .PersonRow { PersonRow, PeopleHeader }
import from ..ui.skeleton { Skeleton }

def:pub PeopleTable(
    rows: list[dict[str, any]],
    dayNames: list[str],
    todayIndex: int,
    placeholder: bool = False,
    placeholderRows: int = 5
) -> JsxElement {
    return
        <Panel id="people-h" title="People" busy={placeholder} className="@container">
            {if len(rows) == 0 and not placeholder {
                <EmptyLine
                    key="empty"
                    text="No active people."
                    action="Add a person"
                    to="/workspace?tab=people"
                />
            } else {
                <div key="table" role="table" aria-labelledby="people-h">
                    <PeopleHeader/>
                    {for i in range(placeholderRows if placeholder else 0) {
                        <div
                            key={"ph" + str(i)}
                            className="flex items-center gap-3 px-2 py-2"
                        >
                            <Skeleton className="size-8 shrink-0 rounded-full"/>
                            <Skeleton
                                className={"h-3.5 " + ("w-24" if i % 2 else "w-32")}
                            />
                        </div>
                    }}
                    {for r in rows {
                        <PersonRow
                            key={r["id"]}
                            row={r}
                            dayNames={dayNames}
                            todayIndex={todayIndex}
                        />
                    }}
                </div>
            } }
        </Panel>;
}
