"""The open task's GitHub sub-issues as rows that jump the sheet to them, or the
link up to its parent issue."""

import from ....models { TaskRow }

# A row's column label: the child's step (or legacy status) through the board's
# own key/label lists, so it says what the column says.
def stepLabel(kid: TaskRow, keys: list[str], labels: list[str]) -> str {
    for (i, k) in enumerate(keys) {
        if (k == kid.step_id or k == kid.status) and i < len(labels) {
            return labels[i];
        }
    }
    return kid.status;
}

def:pub SheetFamily(
    family: list[TaskRow],
    total: int,
    done: int,
    keys: list[str],
    labels: list[str],
    onOpen: Callable[[str], None]
) -> JsxElement {
    return
        <section className="grid gap-1.5" aria-label="Sub-issues">
            <div className="flex items-baseline justify-between gap-3">
                <h3 className="text-[13px] font-semibold">Sub-issues</h3>
                <span className="num text-xs text-muted-foreground">
                    {str(done) + " of " + str(total) + " done"}
                </span>
            </div>
            <div className="border-t">
                {for kid in family {
                    <button
                        key={kid.id}
                        type="button"
                        className="flex w-full items-center gap-2 border-b px-1 py-1.5 text-left text-[13px] hover:bg-accent"
                        title={"Open " + kid.title}
                        onClick={lambda { if onOpen { onOpen(kid.id); }}}
                    >
                        <span className="num flex-none text-xs text-subtle">
                            {"#" + str(kid.gh_issue_number)}
                        </span>
                        <span className="min-w-0 flex-1 truncate">{kid.title}</span>
                        <span
                            className={"flex-none text-xs "
                                + (
                                    "text-success"
                                        if kid.status == "Done"
                                        else "text-muted-foreground"
                                )}
                        >
                            {stepLabel(kid, keys, labels)}
                        </span>
                    </button>
                }}
                {if len(family) < total {
                    <p
                        key="ghost"
                        className="px-1 py-1.5 text-xs text-muted-foreground"
                    >
                        {str(total - len(family)) + " more on GitHub, not on the board"}
                    </p>
                }}
            </div>
        </section>;
}
