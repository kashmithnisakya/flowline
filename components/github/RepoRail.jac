"""The repositories this workspace reads, and which one the pane on the right
is showing. Each row carries the project its issues land in; live state is
the installation's, so it lives in the connection strip, not here.
"""

import from ...models { RepoView }
import from ..ui.button { Button }
import from ..workspace.icons { IconPlus }

def:pub RepoRail(
    repos: list[RepoView],
    selected: str,
    onSelect: Callable[[str], None],
    onAdd: Callable[[], None]
) -> JsxElement {
    return
        <div className="surface overflow-hidden">
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
            {if len(repos) == 0 {
                <p key="none" className="px-3 py-4 text-[13px] text-muted-foreground">
                    None yet. Add one to read its issues.
                </p>
            }}
            <ul className="divide-y">
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
