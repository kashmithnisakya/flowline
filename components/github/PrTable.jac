"""One page of a repository's pull requests, read-only: a PR joins a task by
its link or number on the task itself, this table only says which already have.
Merged and draft are flowline's reading of GitHub's flags (which report
closed/open).
"""

import from ...models { GhPrRow }
import from ..ui.button { Button }
import from ..ui.skeleton { Skeleton }
import from ..common.glyphs { Spinner }
import from ..workspace.icons { IconExternal }

glob PR_STATE_LABEL: dict[str, str] = {
         "open": "Open",
         "closed": "Closed",
         "merged": "Merged",
         "draft": "Draft"
     };

# Relative "3d ago" label from an ISO stamp. Empty in, empty out; anything
# older than a month falls back to the plain date.
def timeAgo(iso: str) -> str {
    if not iso {
        return "";
    }
    then = new(Date, iso);
    now = new(Date);
    ms = now.getTime() - then.getTime();
    if ms < 0 {
        ms = 0;
    }
    mins = int(ms / 60000);
    if mins < 1 {
        return "just now";
    }
    if mins < 60 {
        return str(mins) + "m ago";
    }
    hours = int(mins / 60);
    if hours < 24 {
        return str(hours) + "h ago";
    }
    days = int(hours / 24);
    if days < 31 {
        return str(days) + "d ago";
    }
    return iso[:10];
}

def:pub PrTable(
    rows: list[GhPrRow],
    loading: bool,
    loadingMore: bool,
    hasMore: bool,
    state: str,
    query: str,
    onState: Callable[[str], None],
    onLoadMore: Callable[[], None]
) -> JsxElement {
    if loading {
        return
            <div className="flex flex-col gap-1 p-3">
                {for i in [0, 1, 2, 3, 4] {
                    <div key={"sk-" + str(i)} className="flex items-center gap-3 py-2">
                        <Skeleton className="h-4 w-10 shrink-0"/>
                        <Skeleton className="h-4 w-full max-w-80"/>
                        <Skeleton
                            className="ml-auto hidden h-4 w-16 shrink-0 sm:block"
                        />
                    </div>
                }}
            </div>;
    }
    if len(rows) == 0 {
        return
            <div className="flex flex-col items-center gap-2 px-6 py-12 text-center">
                <p className="text-sm font-semibold">
                    {"No matches" if query else "Nothing to show"}
                </p>
                <p className="max-w-sm text-sm text-muted-foreground">
                    {("No pull requests match \"" + query + "\" in that state.")
                        if query
                        else "This repository has no pull requests in that state."}
                </p>
                {if state != "all" {
                    <Button
                        key="allstates"
                        variant="ghost"
                        size="sm"
                        className="mt-1"
                        onClick={lambda { onState("all"); }}
                    >
                        Show every state
                    </Button>
                }}
            </div>;
    }

    return
        <div className="flex flex-col">
            <div className="overflow-x-auto">
                <table className="data-table">
                    <thead>
                        <tr>
                            <th className="w-16">Number</th>
                            <th>Title</th>
                            <th className="hidden md:table-cell">Author</th>
                            <th className="w-20">State</th>
                            <th className="hidden w-24 sm:table-cell">Updated</th>
                            <th className="relative w-24">
                                <span className="sr-only">Card</span>
                            </th>
                        </tr>
                    </thead>
                    <tbody>
                        {for r in rows {
                            <tr key={str(r.number)}>
                                <td className="num text-muted-foreground">
                                    {"#" + str(r.number)}
                                </td>
                                <td className="max-w-80">
                                    <a
                                        href={r.html_url}
                                        target="_blank"
                                        rel="noreferrer"
                                        className="flex items-center gap-1.5 font-medium underline-offset-2 hover:underline"
                                        title={r.title}
                                    >
                                        <span className="truncate">{r.title}</span>
                                        <IconExternal className="shrink-0 text-subtle"/>
                                    </a>
                                </td>
                                <td
                                    className="num hidden text-xs text-muted-foreground md:table-cell"
                                >
                                    {("@" + r.author) if r.author else ""}
                                </td>
                                <td className="text-muted-foreground">
                                    {PR_STATE_LABEL[r.state]
                                        if r.state in PR_STATE_LABEL
                                        else r.state}
                                </td>
                                <td
                                    className="num hidden text-xs text-muted-foreground sm:table-cell"
                                    title={r.updated_at[:16].replace("T", " ")}
                                >
                                    {timeAgo(r.updated_at)}
                                </td>
                                <td className="text-right">
                                    {if r.linked_task_id {
                                        <a
                                            key="card"
                                            href={"/board?task=" + r.linked_task_id}
                                            className="whitespace-nowrap text-[12.5px] text-muted-foreground underline-offset-2 hover:text-foreground hover:underline"
                                        >
                                            Open card
                                        </a>
                                    }}
                                </td>
                            </tr>
                        }}
                    </tbody>
                </table>
            </div>
            {if hasMore {
                <div key="more" className="flex justify-center border-t py-2">
                    <Button
                        variant="ghost"
                        size="sm"
                        onClick={onLoadMore}
                        disabled={loadingMore}
                    >
                        {if loadingMore {
                            <Spinner key="sp"/>
                        }}
                        {"Loading…" if loadingMore else "Load more"}
                    </Button>
                </div>
            }}
        </div>;
}
