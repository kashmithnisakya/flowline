"""One repository in the GitHub panel: its name (opens its lists), its project and
a switch per automation."""

import from ...models { RepoView }
import from ..ui.switch { Switch }

glob:pub REPO_COLS: str = "grid grid-cols-[minmax(0,1.4fr)_minmax(0,1fr)_repeat(4,84px)] items-center gap-x-3 px-4";

def RepoSwitch(
    label: str, repo: str, checked: bool, onFlip: Callable[[bool], None]
) -> JsxElement {
    return
        <span className="flex justify-center">
            <Switch
                checked={checked}
                aria-label={label + " for " + repo}
                onCheckedChange={lambda (v: bool) { onFlip(v); }}
            />
        </span>;
}

def:pub GithubRepoRow(
    repo: RepoView,
    onOpen: Callable[[str], None],
    onSync: Callable[[str, bool], None],
    onDone: Callable[[str, bool], None],
    onClose: Callable[[str, bool], None],
    onLabels: Callable[[str, bool], None]
) -> JsxElement {
    return
        <div className={REPO_COLS + " min-h-11 border-b py-1.5"}>
            <button
                type="button"
                className="num truncate text-left text-[13px] font-medium underline-offset-2 hover:underline"
                title="Open its issues and pull requests"
                onClick={lambda { onOpen(repo.id); }}
            >
                {repo.full_name}
            </button>
            <span className="truncate text-[13px] text-muted-foreground">
                {repo.project_name or "No project"}
            </span>
            <RepoSwitch
                label="Auto import"
                repo={repo.full_name}
                checked={repo.auto_sync}
                onFlip={lambda (v: bool) { onSync(repo.id, v); }}
            />
            <RepoSwitch
                label="Merge to Done"
                repo={repo.full_name}
                checked={repo.auto_done}
                onFlip={lambda (v: bool) { onDone(repo.id, v); }}
            />
            <RepoSwitch
                label="Done closes"
                repo={repo.full_name}
                checked={repo.auto_close}
                onFlip={lambda (v: bool) { onClose(repo.id, v); }}
            />
            <RepoSwitch
                label="Sync labels"
                repo={repo.full_name}
                checked={repo.label_sync}
                onFlip={lambda (v: bool) { onLabels(repo.id, v); }}
            />
        </div>;
}
