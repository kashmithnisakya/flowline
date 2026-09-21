"""The repositories this workspace reads, and which one the pane on the right
is showing. Each row carries the project its issues land in; live state is
the installation's, so it lives in the connection strip, not here.
"""

import from ...models { RepoView }
import from ..ui.button { Button }
import from ..ui.skeleton { Skeleton }
import from ..workspace.icons { IconPlus }

# `placeholder` is the first load: that many skeleton rows under the header.
def:pub RepoRail(
    repos: list[RepoView],
    selected: str,
    onSelect: Callable[[str], None],
    onAdd: Callable[[], None],
    placeholder: int = 0
) -> JsxElement {
    return
        <div className="surface overflow-hidden" aria-busy={placeholder > 0}>
            <div
                className="flex items-center justify-between gap-2 border-b py-1.5 pr-1.5 pl-3"
            >
                <h2 className="text-[13px] font-semibold">Repositories</h2>
                <Button
                    variant="ghost"
                    size="sm"
                    className="text-muted-foreground"
                    onClick={lambda { onAdd(); }}
                >
                    <IconPlus/>
                    Add
                </Button>
            </div>
            {if len(repos) == 0 and placeholder == 0 {
                <p key="none" className="px-3 py-4 text-[13px] text-muted-foreground">
                    None yet. Add one to read its issues.
                </p>
            }}
            <ul className="divide-y">
                {for i in range(placeholder) {
                    <li key={"ph" + str(i)} className="flex flex-col gap-0.5 px-3 py-2">
                        <div className="flex h-[19px] items-center">
                            <Skeleton
                                className={"h-3 " + ("w-28" if i % 2 else "w-36")}
                            />
                        </div>
                        <div className="flex h-4 items-center">
                            <Skeleton className="h-2.5 w-20"/>
                        </div>
                    </li>
                }}
                {for r in repos {
                    <li key={r.id}>
                        <button
                            type="button"
                            aria-current={"true" if r.id == selected else None}
                            className={"flex w-full flex-col gap-0.5 px-3 py-2 text-left transition-colors duration-150 "
                                + (
                                    "bg-accent shadow-[inset_2px_0_0_var(--primary)]"
                                        if r.id == selected
                                        else "hover:bg-accent"
                                )}
                            onClick={lambda { onSelect(r.id); }}
                        >
                            <span className="num truncate text-[12.5px] font-medium">
                                {r.full_name}
                            </span>
                            <span className="truncate text-xs text-muted-foreground">
                                {r.project_name or "No project"}
                            </span>
                        </button>
                    </li>
                }}
            </ul>
        </div>;
}
