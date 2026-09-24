"""One worklist row, linking to its card: the first assignee's avatar, the
title over a muted line (project, then the blocked reason or the reviewer),
the step pill and the time. Row dict keys are listed on NeedsYou."""

import from "@jac/runtime" { Link }
import from ..common.Avatar { Avatar }
import from ..common.StepBadge { StepBadge }

def:pub NeedsRow(row: dict[str, any]) -> JsxElement {
    names: list[str] = row["names"];
    step: dict[str, str] = row["step"];
    return
        <li>
            <Link
                to={"/board?task=" + row["id"]}
                className="-mx-2 grid grid-cols-[2rem_minmax(0,1fr)_auto] items-center gap-x-3 gap-y-1 rounded-xl px-2 py-2 hover:bg-accent sm:grid-cols-[2rem_minmax(0,1fr)_auto_auto]"
            >
                {if len(names) > 0 {
                    <Avatar key="who" name={names[0]} size="md"/>
                } else {
                    <span
                        key="nobody"
                        className="size-8 rounded-full border border-dashed border-input"
                        title="Unassigned"
                    />
                } }
                <span className="min-w-0">
                    <span className="block truncate text-sm font-medium">
                        {row["title"]}
                    </span>
                    <span className="block truncate text-xs text-muted-foreground">
                        {row["meta"]}
                        {" · " if row["meta"] and row["note"] else ""}
                        <span className={"text-warning" if row["noteWarn"] else ""}>
                            {row["note"]}
                        </span>
                    </span>
                </span>
                <span className="hidden sm:flex">
                    <StepBadge
                        name={step["name"]}
                        color={step["color"]}
                        kind={step["kind"]}
                        size="sm"
                    />
                </span>
                <time
                    className={"num text-right text-xs whitespace-nowrap "
                        + (
                            "font-semibold text-destructive"
                                if row["late"]
                                else "text-muted-foreground"
                        )}
                >
                    {row["time"]}
                </time>
            </Link>
        </li>;
}
