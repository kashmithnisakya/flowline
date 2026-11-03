"""One person on the Overview (id, name, color, open, done, late, lateAlarm):
avatar, name over what they finished this week, then open and overdue counts.
`late` is text: blank until the due list lands, "-" if it failed."""

import from ..common.Avatar { Avatar }

def:pub PersonRow(row: dict[str, any]) -> JsxElement {
    return
        <div
            className="flex min-h-11 items-center gap-3 border-b border-border-subtle px-4 py-2 last:border-b-0"
            role="row"
        >
            <Avatar name={row["name"]} color={row["color"]} size="sm"/>
            <span className="min-w-0 flex-1" role="cell">
                <span className="block truncate text-[13px] font-medium">
                    {row["name"]}
                </span>
                <span className="meta block truncate">
                    {str(row["done"]) + " done this week"}
                </span>
            </span>
            <span
                className="num w-8 text-right text-xs"
                role="cell"
                aria-label={str(row["open"]) + " open"}
            >
                {str(row["open"])}
            </span>
            <span
                className={"num w-8 text-right text-xs "
                    + ("text-danger" if row["lateAlarm"] else "text-text-tertiary")}
                role="cell"
                aria-label={row["late"] + " overdue"}
            >
                {row["late"]}
            </span>
        </div>;
}
