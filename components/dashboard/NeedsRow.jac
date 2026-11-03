"""One worklist row, linking to its card: the step's status icon, the title over
a muted line (project and step, then the blocked reason or the reviewer), the
first assignee's avatar and the time. Row dict keys are listed on NeedsYou."""

import from "@jac/runtime" { Link }
import from ..common.Avatar { Avatar }
import from ..common.StepBadge { StepIcon }

def:pub NeedsRow(row: dict[str, any]) -> JsxElement {
    names: list[str] = row["names"];
    step: dict[str, str] = row["step"];
    lead = ", ".join(
        [
            part
            for part in [row["meta"], step["name"]]
            if part
        ]
    );
    return
        <li className="border-b border-border-subtle last:border-b-0">
            <Link
                to={"/board?task=" + row["id"]}
                className="grid min-h-11 grid-cols-[14px_minmax(0,1fr)_24px_minmax(52px,auto)] items-center gap-x-3 px-4 py-2 transition-colors hover:bg-bg-hover"
            >
                <StepIcon color={step["color"]} kind={step["kind"]}/>
                <span className="min-w-0">
                    <span className="block truncate text-[13px] font-medium">
                        {row["title"]}
                    </span>
                    <span className="meta block truncate">
                        {lead}
                        {" · " if lead and row["note"] else ""}
                        <span className={"text-warning" if row["noteWarn"] else ""}>
                            {row["note"]}
                        </span>
                    </span>
                </span>
                {if len(names) > 0 {
                    <Avatar key="who" name={names[0]} size="sm"/>
                } else {
                    <span
                        key="nobody"
                        className="size-6 rounded-md border border-dashed border-input"
                        title="Unassigned"
                    />
                } }
                <time
                    className={"num text-right text-xs whitespace-nowrap "
                        + ("text-danger" if row["late"] else "text-text-tertiary")}
                >
                    {row["time"]}
                </time>
            </Link>
        </li>;
}
