"""One page of a repository's issues. Import is keyed on (repo, issue number),
so an issue already on the board cannot be picked twice: its row links to the
card it made instead. The import bar appears only once something is selected.
"""

glob STATUSES: list[str] = [
         "Backlog",
         "In Progress",
         "Review",
         "Changes Requested",
         "Done",
         "Blocked"
     ];

import from ...models { Project, StepView, GhIssueRow }
import from ..ui.button { Button }
import from ..ui.checkbox { Checkbox }
import from ..ui.select {
    Select,
    SelectTrigger,
    SelectValue,
    SelectContent,
    SelectItem
}
import from ..ui.skeleton { Skeleton }
import from ..common.glyphs { Spinner }
import from ..common.StepName { StepName }
import from ..workspace.icons { IconExternal }

def:pub IssueImportTable(
    rows: list[GhIssueRow],
    loading: bool,
    loadingMore: bool,
    hasMore: bool,
    state: str,
    selected: list[int],
    projectName: str,
    projects: list[Project],
    projectId: str,
    status: str,
    steps: list[StepView],
    stepId: str,
    importing: bool,
    query: str,
    onState: Callable[[str], None],
    onToggle: Callable[[int], None],
    onProject: Callable[[str], None],
    onStatus: Callable[[str], None],
    onStep: Callable[[str], None],
    onImport: Callable[[], None],
    onLoadMore: Callable[[], None],
    onClear: Callable[[], None]
) -> JsxElement {
    closedPicked = False;
    for r in rows {
        if r.number in selected and r.state == "closed" {
            closedPicked = True;
        }
    }
    if loading {
        return
            <div className="flex flex-col gap-1 p-3">
                {for i in [0, 1, 2, 3, 4] {
                    <div key={"sk-" + str(i)} className="flex items-center gap-3 py-2">
                        <Skeleton className="size-4 shrink-0 rounded-xs"/>
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
                    {"No matches" if query else "Nothing to import"}
                </p>
                <p className="max-w-sm text-sm text-muted-foreground">
                    {("No issues match \"" + query + "\" in that state.")
                        if query
                        else "This repository has no issues in that state."}
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
                            <th className="relative w-9">
                                <span className="sr-only">Pick</span>
                            </th>
                            <th className="w-16">Number</th>
                            <th>Title</th>
                            <th className="hidden md:table-cell">Labels</th>
                            <th className="hidden lg:table-cell">Assignee</th>
                            <th className="w-20">State</th>
                            <th className="relative w-24">
                                <span className="sr-only">Card</span>
                            </th>
                        </tr>
                    </thead>
                    <tbody>
                        {for r in rows {
                            <tr key={str(r.number)}>
                                <td className="w-9">
                                    {if not r.already_imported {
                                        <Checkbox
                                            key="pick"
                                            aria-label={"Pick issue " + str(r.number)}
                                            checked={r.number in selected}
                                            onCheckedChange={lambda { onToggle(
                                                r.number
                                            ); }}
                                        />
                                    }}
                                </td>
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
                                    className="hidden max-w-40 truncate text-xs text-muted-foreground md:table-cell"
                                >
                                    {", ".join(r.labels)}
                                </td>
                                <td
                                    className="num hidden text-xs text-muted-foreground lg:table-cell"
                                >
                                    {("@" + r.assignee) if r.assignee else ""}
                                </td>
                                <td className="text-muted-foreground">
                                    {"Closed" if r.state == "closed" else "Open"}
                                </td>
                                <td className="text-right">
                                    {if r.already_imported and r.imported_task_id {
                                        <a
                                            key="card"
                                            href={"/board?task=" + r.imported_task_id}
                                            className="whitespace-nowrap text-[12.5px] text-muted-foreground underline-offset-2 hover:text-foreground hover:underline"
                                        >
                                            Open card
                                        </a>
                                    } elif r.already_imported {
                                        <span
                                            key="on"
                                            className="text-[12.5px] text-muted-foreground"
                                        >
                                            On the board
                                        </span>
                                    } }
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
            {if len(selected) > 0 {
                <div
                    key="importbar"
                    className="sticky bottom-0 flex flex-wrap items-center gap-x-3 gap-y-2 border-t bg-card px-3 py-2.5"
                >
                    <span className="num text-[13px] font-semibold">
                        {str(len(selected)) + " selected"}
                    </span>
                    <span className="flex items-center gap-2 text-[13px]">
                        <span className="text-muted-foreground">Add to</span>
                        {if projectName {
                            <span key="projname" className="font-medium">
                                {projectName}
                            </span>
                        } else {
                            <Select
                                key="projsel"
                                value={projectId}
                                onValueChange={onProject}
                            >
                                <SelectTrigger className="h-8 w-40" size="sm">
                                    <SelectValue placeholder="Project"/>
                                </SelectTrigger>
                                <SelectContent>
                                    <SelectItem value="none">
                                        The repository's project
                                    </SelectItem>
                                    {for p in projects {
                                        <SelectItem key={jid(p)} value={jid(p)}>
                                            {p.name}
                                        </SelectItem>
                                    }}
                                </SelectContent>
                            </Select>
                        } }
                    </span>
                    <span className="flex items-center gap-2 text-[13px]">
                        <span className="text-muted-foreground">at</span>
                        {if len(steps) > 0 {
                            <Select key="stepsel" value={stepId} onValueChange={onStep}>
                                <SelectTrigger className="h-8 w-40" size="sm">
                                    <SelectValue placeholder="Step"/>
                                </SelectTrigger>
                                <SelectContent>
                                    {for s in steps {
                                        <SelectItem key={s.id} value={s.id}>
                                            <StepName name={s.name} color={s.color}/>
                                        </SelectItem>
                                    }}
                                </SelectContent>
                            </Select>
                        } else {
                            <Select
                                key="statussel"
                                value={status}
                                onValueChange={onStatus}
                            >
                                <SelectTrigger className="h-8 w-40" size="sm">
                                    <SelectValue placeholder="Status"/>
                                </SelectTrigger>
                                <SelectContent>
                                    {for s in STATUSES {
                                        <SelectItem key={s} value={s}>{s}</SelectItem>
                                    }}
                                </SelectContent>
                            </Select>
                        } }
                    </span>
                    {if closedPicked {
                        <span
                            key="closedrule"
                            className="text-xs text-muted-foreground"
                        >
                            Closed issues land on Done.
                        </span>
                    }}
                    <div className="ml-auto flex items-center gap-2">
                        <Button
                            variant="ghost"
                            size="sm"
                            onClick={lambda { onClear(); }}
                            disabled={importing}
                        >
                            Clear
                        </Button>
                        <Button
                            size="sm"
                            className="num"
                            onClick={onImport}
                            disabled={importing}
                        >
                            {if importing {
                                <Spinner key="sp"/>
                            }}
                            {"Importing…"
                                if importing
                                else ("Import " + str(len(selected)))}
                        </Button>
                    </div>
                </div>
            }}
        </div>;
}
