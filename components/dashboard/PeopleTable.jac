"""People on the Overview, one PersonRow each: open work and what is overdue.
`placeholder` draws `placeholderRows` skeleton rows, the count the last visit
had. Each person's updates by day sit in History (PeopleUpdates)."""

import from .Panel { Panel, EmptyLine }
import from .PersonRow { PersonRow }
import from ..ui.skeleton { Skeleton }

def:pub PeopleTable(
    rows: list[dict[str, any]], placeholder: bool = False, placeholderRows: int = 5
) -> JsxElement {
    return
        <Panel
            id="people-h"
            title="People"
            aside={<span className="meta">Open, overdue</span>}
            busy={placeholder}
            flush={True}
        >
            {if len(rows) == 0 and not placeholder {
                <div key="empty" className="p-4">
                    <EmptyLine
                        text="No active people."
                        action="Add a person"
                        to="/workspace?tab=people"
                    />
                </div>
            } else {
                <div key="table" role="table" aria-labelledby="people-h">
                    {for i in range(placeholderRows if placeholder else 0) {
                        <div
                            key={"ph" + str(i)}
                            className="flex min-h-11 items-center gap-3 border-b border-border-subtle px-4 py-2 last:border-b-0"
                        >
                            <Skeleton className="size-6 shrink-0 rounded-md"/>
                            <Skeleton
                                className={"h-3.5 " + ("w-24" if i % 2 else "w-32")}
                            />
                        </div>
                    }}
                    {for r in rows {
                        <PersonRow key={r["id"]} row={r}/>
                    }}
                </div>
            } }
        </Panel>;
}
