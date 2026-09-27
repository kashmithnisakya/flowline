"""Per-repository automation, as settings rather than filters: each switch says
what it will do, and the two that write to GitHub say so. All four are saved
policy, applied on the next sync, GitHub event or move.
"""

import from ...models { RepoView }
import from .AutomationRow { AutomationRow }

def:pub RepoAutomation(
    repo: RepoView,
    onSync: Callable[[bool], None],
    onDone: Callable[[bool], None],
    onClose: Callable[[bool], None],
    onLabels: Callable[[bool], None]
) -> JsxElement {
    where = repo.project_name or "its project";
    return
        <div className="surface">
            <h3 className="px-4 pt-3 text-[12.5px] font-semibold text-muted-foreground">
                Automation for this repository
            </h3>
            <AutomationRow
                id="auto-sync"
                first={True}
                title={"Import issues into " + where}
                detail="New issues arrive as tasks on your start step. Turning this on brings in the repository's existing issues on the next sync, closed ones on Done."
                checked={repo.auto_sync}
                onChange={onSync}
            />
            <AutomationRow
                id="auto-done"
                title="Move a card to Done when its issue closes or its pull request merges"
                detail="Off by default. The log records each move with GitHub's own time."
                checked={repo.auto_done}
                onChange={onDone}
            />
            <AutomationRow
                id="auto-close"
                title="Close the issue when its card moves to Done"
                detail="Moving the card back out reopens the issue. Off by default."
                checked={repo.auto_close}
                onChange={onClose}
                writes={True}
            />
            <AutomationRow
                id="label-sync"
                title="Add the flow line's labels as work moves"
                detail="Crossing an arrow with a GitHub label adds it to the issue or its pull request, and moving on takes it off unless the arrow keeps it. Turning this on creates the labels in the repository. Off by default."
                checked={repo.label_sync}
                onChange={onLabels}
                writes={True}
            />
        </div>;
}
