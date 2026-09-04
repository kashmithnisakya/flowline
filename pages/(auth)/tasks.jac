"""flowline - Tasks (/tasks): a flat, sortable, filterable table over the whole
task set, the cross-column view the board cannot give. Read-only in this stage:
a row opens the board dialog for editing. State and handlers here, the table
and paging are presentational."""

import from "@jac/runtime" { useState }
import from "react" { useEffect, useRef }
import from ...models { Project, MemberView, TaskView }
import from ...walkers.tasks { ListTasks }
import from ...walkers.roster { ListMembers }
import from ...walkers.projects { ListProjects }
import from ...components.tasks.TaskTable { TaskTable }
import from ...components.ui.card { Card, CardContent }
import from ...components.ui.button { Button }
import from ...components.ui.input { Input }
import from ...components.ui.skeleton { Skeleton }
import from ...components.ui.select {
    Select,
    SelectTrigger,
    SelectValue,
    SelectContent,
    SelectItem
}
import from ...components.common.LoadFailed { LoadFailed }

glob SCOPES: list[list[str]] = [
         ["working", "Working"],
         ["all", "Everything"],
         ["done", "Done"],
         ["attention", "Needs attention"]
     ],
     PAGE_SIZE: int = 50;

# Merge freshly seen values into an accumulated, sorted, de-duplicated list.
# The category and tag dropdowns both build this way, so one page never
# empties a filter list just because the current page carries none of them.
def mergeSorted(existing: list[str], fresh: list[str]) -> list[str] {
    if len(fresh) == 0 {
        return existing;
    }
    merged = [v for v in existing];
    for v in fresh {
        if v not in merged {
            merged.append(v);
        }
    }
    merged.sort();
    return merged;
}

def:pub TasksPage -> JsxPage {
    has rows: list[TaskView] = [],
        members: list[MemberView] = [],
        projects: list[Project] = [],
        scope: str = "all",
        fProject: str = "all",
        fAssignee: str = "All",
        fCategory: str = "All",
        fTag: str = "All",
        fEstimate: str = "All",
        categories: list[str] = [],
        tags: list[str] = [],
        query: str = "",
        # The committed query; the input holds the draft until Enter.
        queryDraft: str = "",
        sort: str = "updated",
        sortDir: str = "desc",
        page: int = 1,
        total: int = 0,
        hasMore: bool = False,
        loading: bool = True,
        failed: bool = False,
        # Only the newest fetch may paint: filter and page changes race.
        reqRef: Ref[any] = Ref();

    async can with entry {
        loadWorkspace();
    }

    # One dependent effect covers every input to the same two reads.
    async can with (
        scope,
        fProject,
        fAssignee,
        fCategory,
        fTag,
        fEstimate,
        query,
        sort,
        sortDir,
        page
    ) entry {
        loadTasks();
    }

    async def loadWorkspace -> None;
    async def loadTasks -> None;
    def sortBy(field: str) -> None;
    def chooseScope(value: str) -> None;
    def setProject(value: str) -> None;
    def setAssignee(value: str) -> None;
    def setCategory(value: str) -> None;
    def setTag(value: str) -> None;
    def setEstimate(value: str) -> None;
    def runSearch -> None;
    def clearSearch -> None;
    def goPage(delta: int) -> None;

    pageCount = (total + PAGE_SIZE - 1) // PAGE_SIZE if total > 0 else 1;
    shownMembers = [
        m
        for m in members
        if fProject == "all" or fProject in m.project_ids
    ];

    return
        <div className="space-y-5">
            <div className="flex flex-wrap items-end justify-between gap-3">
                <div>
                    <h1 className="page-title">Tasks</h1>
                    <p className="page-subtitle">
                        Every task in one sortable table. Open a row to edit it on the board.
                    </p>
                </div>
                <div className="tabular-nums text-sm text-muted-foreground">
                    {str(total) + (" task" if total == 1 else " tasks")}
                </div>
            </div>
            <div className="flex flex-wrap items-center gap-2">
                <Select value={scope} onValueChange={chooseScope}>
                    <SelectTrigger className="h-8 w-44" size="sm" aria-label="Scope">
                        <SelectValue/>
                    </SelectTrigger>
                    <SelectContent>
                        {for s in SCOPES {
                            <SelectItem key={s[0]} value={s[0]}>{s[1]}</SelectItem>
                        }}
                    </SelectContent>
                </Select>
                <Select value={fProject} onValueChange={setProject}>
                    <SelectTrigger
                        className="h-8 w-44"
                        size="sm"
                        aria-label="Filter by project"
                    >
                        <SelectValue placeholder="Project"/>
                    </SelectTrigger>
                    <SelectContent>
                        <SelectItem value="all">All projects</SelectItem>
                        {for p in projects {
                            <SelectItem key={jid(p)} value={jid(p)}>
                                {p.name}
                            </SelectItem>
                        }}
                    </SelectContent>
                </Select>
                <Select value={fAssignee} onValueChange={setAssignee}>
                    <SelectTrigger
                        className="h-8 w-40"
                        size="sm"
                        aria-label="Filter by assignee"
                    >
                        <SelectValue placeholder="Assignee"/>
                    </SelectTrigger>
                    <SelectContent>
                        <SelectItem value="All">Everyone</SelectItem>
                        {for m in shownMembers {
                            <SelectItem key={m.id} value={m.id}>{m.name}</SelectItem>
                        }}
                    </SelectContent>
                </Select>
                <Select value={fCategory} onValueChange={setCategory}>
                    <SelectTrigger
                        className="h-8 w-40"
                        size="sm"
                        aria-label="Filter by category"
                    >
                        <SelectValue placeholder="Category"/>
                    </SelectTrigger>
                    <SelectContent>
                        <SelectItem value="All">All categories</SelectItem>
                        {for c in categories {
                            <SelectItem key={c} value={c}>{c}</SelectItem>
                        }}
                    </SelectContent>
                </Select>
                {if len(tags) > 0 {
                    <Select key="tag" value={fTag} onValueChange={setTag}>
                        <SelectTrigger
                            className="h-8 w-36"
                            size="sm"
                            aria-label="Filter by tag"
                        >
                            <SelectValue placeholder="Tag"/>
                        </SelectTrigger>
                        <SelectContent>
                            <SelectItem value="All">All tags</SelectItem>
                            {for tg in tags {
                                <SelectItem key={tg} value={tg}>{tg}</SelectItem>
                            }}
                        </SelectContent>
                    </Select>
                }}
                <Select value={fEstimate} onValueChange={setEstimate}>
                    <SelectTrigger
                        className="h-8 w-36"
                        size="sm"
                        aria-label="Filter by estimate"
                    >
                        <SelectValue placeholder="Estimate"/>
                    </SelectTrigger>
                    <SelectContent>
                        <SelectItem value="All">Any estimate</SelectItem>
                        <SelectItem value="yes">Estimated</SelectItem>
                        <SelectItem value="no">Unestimated</SelectItem>
                    </SelectContent>
                </Select>
                <Input
                    className="h-8 w-52"
                    placeholder="Search titles, Enter to run"
                    value={queryDraft}
                    onChange={lambda (e: any) { queryDraft = e.target.value; }}
                    onKeyDown={lambda (e: KeyboardEvent) { if e.key == "Enter" {
                        runSearch();
                    }}}
                />
                {if query {
                    <Button
                        key="clear"
                        variant="ghost"
                        size="sm"
                        className="h-8"
                        onClick={clearSearch}
                    >
                        Clear
                    </Button>
                }}
            </div>
            {if loading {
                <Card key="sk">
                    <CardContent className="space-y-2 py-4">
                        {for i in range(8) {
                            <Skeleton key={str(i)} className="h-9 w-full"/>
                        }}
                    </CardContent>
                </Card>
            } elif failed {
                <LoadFailed
                    key="failed"
                    title="Could not load tasks"
                    onRetry={loadTasks}
                />
            } else {
                <div key="body" className="space-y-3">
                    <TaskTable
                        rows={rows}
                        sort={sort}
                        sortDir={sortDir}
                        onSort={sortBy}
                        emptyLabel={"No tasks match these filters."
                            if query
                                or fProject != "all"
                                or fAssignee != "All"
                                or fCategory != "All"
                                or fTag != "All"
                                or fEstimate != "All"
                            else "No tasks yet."}
                    />
                    {if pageCount > 1 {
                        <div
                            key="pager"
                            className="flex items-center justify-end gap-3 text-sm text-muted-foreground"
                        >
                            <Button
                                variant="outline"
                                size="sm"
                                disabled={page <= 1}
                                onClick={lambda { goPage(-1); }}
                            >
                                Previous
                            </Button>
                            <span className="tabular-nums">
                                {"Page " + str(page) + " of " + str(pageCount)}
                            </span>
                            <Button
                                variant="outline"
                                size="sm"
                                disabled={not hasMore}
                                onClick={lambda { goPage(1); }}
                            >
                                Next
                            </Button>
                        </div>
                    }}
                </div>
            }  }
        </div>;
}
