"""Per-repository automation, as settings rather than filters: each switch says
what it will do, and the one that writes to GitHub says so. All three are saved
policy, applied on the next sync or GitHub event.
"""

import from ...models { RepoView }
import from ..ui.switch { Switch }

def:pub RepoAutomation(
    repo: RepoView,
    onSync: Callable[[bool], None],
    onDone: Callable[[bool], None],
    onClose: Callable[[bool], None]
) -> JsxElement {
    where = repo.project_name or "its project";
    return
        <div className="surface">
            <h3 className="px-4 pt-3 text-[12.5px] font-semibold text-muted-foreground">
                Automation for this repository
            </h3>
            <div
                className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-x-4 px-4 py-3"
            >
                <div>
                    <label htmlFor="auto-sync" className="text-[13.5px] font-medium">
                        {"Import issues into " + where}
                    </label>
                    <p className="mt-0.5 text-[12.5px] text-muted-foreground">
                        New issues arrive as tasks on your start step. Turning this on brings in the repository's existing issues on the next sync, closed ones on Done.
                    </p>
                </div>
                <Switch
                    id="auto-sync"
                    checked={repo.auto_sync}
                    onCheckedChange={lambda (v: bool) { onSync(v); }}
                />
            </div>
            <div
                className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-x-4 border-t px-4 py-3"
            >
                <div>
                    <label htmlFor="auto-done" className="text-[13.5px] font-medium">
                        Move a card to Done when its issue closes or its pull request merges
                    </label>
                    <p className="mt-0.5 text-[12.5px] text-muted-foreground">
                        Off by default. The log records each move with GitHub's own time.
                    </p>
                </div>
                <Switch
                    id="auto-done"
                    checked={repo.auto_done}
                    onCheckedChange={lambda (v: bool) { onDone(v); }}
                />
            </div>
            <div
                className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-x-4 border-t px-4 py-3"
            >
                <div>
                    <label htmlFor="auto-close" className="text-[13.5px] font-medium">
                        Close the issue when its card moves to Done
                    </label>
                    <p className="mt-0.5 text-[12.5px] text-muted-foreground">
                        <span className="font-semibold text-warning">
                            Writes to GitHub.
                        </span>
                        {" Moving the card back out reopens the issue. Off by default."}
                    </p>
                </div>
                <Switch
                    id="auto-close"
                    checked={repo.auto_close}
                    onCheckedChange={lambda (v: bool) { onClose(v); }}
                />
            </div>
        </div>;
}
