"""A connected workspace with no repository yet: what to do about it."""

import from ..ui.button { Button }
import from .icons { IconPlus }

def:pub GithubNoRepo(onAdd: Callable[[], None]) -> JsxElement {
    return
        <div className="flex flex-col items-center gap-2 px-6 py-12 text-center">
            <p className="text-sm font-semibold">No repository yet</p>
            <p className="max-w-sm text-sm text-muted-foreground">
                Add one of the repositories you granted the App, and pick the project its issues land in.
            </p>
            <Button size="sm" className="mt-1" onClick={lambda { onAdd(); }}>
                <IconPlus/>
                Add repository
            </Button>
        </div>;
}
