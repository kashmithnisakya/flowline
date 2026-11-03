"""The repositories this workspace reads, one row each with its four switches. A
repository's name opens its issue and pull request lists, which take over the
panel and spell out what each switch does.
"""

import from ...models { RepoView }
import from ..ui.button { Button }
import from .GithubRepoRow { GithubRepoRow, REPO_COLS }
import from .icons { IconPlus }

glob HEADS: list[list[str]] = [
         [
             "Auto import",
             "New issues arrive as tasks on your start step. Turning this on brings in the repository's existing issues on the next sync."
         ],
         [
             "Merge to Done",
             "Move a card to Done when its issue closes or its pull request merges."
         ],
         [
             "Done closes",
             "Writes to GitHub. Close the issue when its card moves to Done, and reopen it when the card moves back."
         ],
         [
             "Sync labels",
             "Writes to GitHub. Add the flow line's labels as work moves. Turning this on creates the labels in the repository."
         ]
     ];

def:pub GithubRepoTable(
    repos: list[RepoView],
    onOpen: Callable[[str], None],
    onAdd: Callable[[], None],
    onSync: Callable[[str, bool], None],
    onDone: Callable[[str, bool], None],
    onClose: Callable[[str, bool], None],
    onLabels: Callable[[str, bool], None]
) -> JsxElement {
    return
        <div>
            <div className="overflow-x-auto">
                <div className="min-w-[680px]">
                    <div
                        className={REPO_COLS
                            + " min-h-8 border-b text-xs text-text-tertiary"}
                    >
                        <span>Repository</span>
                        <span>Project</span>
                        {for col in HEADS {
                            <span key={col[0]} className="text-center" title={col[1]}>
                                {col[0]}
                            </span>
                        }}
                    </div>
                    {for r in repos {
                        <GithubRepoRow
                            key={r.id}
                            repo={r}
                            onOpen={onOpen}
                            onSync={onSync}
                            onDone={onDone}
                            onClose={onClose}
                            onLabels={onLabels}
                        />
                    }}
                </div>
            </div>
            <div className="flex flex-wrap items-center gap-x-3 gap-y-2 px-4 py-2.5">
                <Button size="sm" variant="outline" onClick={lambda { onAdd(); }}>
                    <IconPlus/>
                    Add repository
                </Button>
                <p className="meta min-w-0 flex-1 basis-[240px]">
                    Done closes and Sync labels write to GitHub. Open a repository for what each switch does.
                </p>
                <button
                    type="button"
                    className="text-[13px] text-text-secondary underline underline-offset-[3px] hover:text-text-primary"
                    onClick={lambda { onOpen(repos[0].id); }}
                >
                    Import issues
                </button>
            </div>
        </div>;
}
