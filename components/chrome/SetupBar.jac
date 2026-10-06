"""The setup wizard's only chrome: the mark, the workspace name and Sign out."""

import from ..common.CommandPalette { PageIcon }
import from .Mark { Mark }

def:pub SetupBar(orgName: str, onSignOut: Callable[[], None]) -> JsxElement {
    return
        <header className="sticky top-0 z-40 h-12 border-b bg-card">
            <div className="flex h-full items-center gap-2 px-4 sm:px-6">
                <Mark/>
                <span className="min-w-0 truncate text-sm font-semibold">
                    {orgName or "flowline"}
                </span>
                <button
                    type="button"
                    className="ml-auto inline-flex h-8 items-center gap-2 rounded-md px-2.5 text-[13px] font-medium text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
                    onClick={onSignOut}
                >
                    <PageIcon name="signout"/>
                    Sign out
                </button>
            </div>
        </header>;
}
