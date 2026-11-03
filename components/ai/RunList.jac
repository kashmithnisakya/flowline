"""The AI page's activity: every run in the workspace, newest first, or only what
needs a look. Paged, like every list that grows with history."""

import from ...models { AgentRunLine }
import from ..ui.button { Button }
import from ..ui.skeleton { Skeleton }
import from .RunLine { RunLine }

glob TAB: str = "h-[26px] rounded-[5px] px-2.5 text-[12.5px] ";

def:pub RunList(
    rows: list[AgentRunLine],
    attention: bool,
    hasMore: bool,
    loading: bool,
    busy: bool,
    aiEnabled: bool,
    onFilter: Callable[[bool], None],
    onMore: Callable[[], None],
    onRetry: Callable[[str], None],
    onCancel: Callable[[str], None]
) -> JsxElement {
    empty = (
        "Nothing needs a look right now."
            if attention
            else (
                "No runs yet. Give a role an AI responsibility, then move a task with a linked pull request onto its step."
                    if aiEnabled
                    else "No runs yet. Turn AI on, then give a role a responsibility."
            )
    );
    return
        <section className="surface bg-bg-elevated" aria-label="AI activity">
            <div
                className="flex min-h-11 flex-wrap items-center gap-2 border-b px-4 py-1.5"
            >
                <h2 className="text-sm font-semibold">Activity</h2>
                <div
                    className="ml-auto inline-flex gap-0.5 rounded-md bg-bg-surface p-0.5"
                    role="group"
                    aria-label="Show"
                >
                    <button
                        type="button"
                        aria-pressed={not attention}
                        className={TAB
                            + (
                                "border bg-card font-medium"
                                    if not attention
                                    else "text-text-secondary"
                            )}
                        onClick={lambda { onFilter(False); }}
                    >
                        All
                    </button>
                    <button
                        type="button"
                        aria-pressed={attention}
                        className={TAB
                            + (
                                "border bg-card font-medium"
                                    if attention
                                    else "text-text-secondary"
                            )}
                        onClick={lambda { onFilter(True); }}
                    >
                        Needs a look
                    </button>
                </div>
            </div>
            {if loading and len(rows) == 0 {
                <div key="sk" className="grid gap-3 p-4" aria-busy="true">
                    <Skeleton className="h-4 w-3/5"/>
                    <Skeleton className="h-4 w-2/5"/>
                    <Skeleton className="h-4 w-1/2"/>
                </div>
            }}
            {if not loading and len(rows) == 0 {
                <p key="none" className="px-4 py-6 text-[13px] text-text-tertiary">
                    {empty}
                </p>
            }}
            <ul>
                {for r in rows {
                    <RunLine
                        key={r.id}
                        run={r}
                        busy={busy}
                        onRetry={onRetry}
                        onCancel={onCancel}
                    />
                }}
            </ul>
            {if hasMore {
                <div key="more" className="border-t px-4 py-2">
                    <Button variant="ghost" size="sm" onClick={lambda { onMore(); }}>
                        Show more
                    </Button>
                </div>
            }}
        </section>;
}
