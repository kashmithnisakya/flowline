"""flowline - Tasks (/tasks): a flat, sortable, filterable table over the whole
task set, the cross-column view the board cannot give. A row opens the board's
task dialog in place, and scope, filters, sort and page live in the URL, so a
reload, the back button or a shared link keeps the view."""

import from "@jac/runtime" { useState }
import from "react" { useEffect, useRef }
import from ...models { Project, MemberView, TaskView, StepView, RoleView }
import from ...constants { STATUSES, STATUS_KIND, KIND_STATUS }
import from ...services.tasks.tasks { ListTasks, UpdateTask, DeleteTask }
import from ...services.roster.roster { ListMembers, ListRoles }
import from ...services.projects.projects { ListProjects, AssignToProject }
import from ...services.flowlines.flowlines { GetFlowLine }
import from ...components.tasks.TaskTable { TaskTable }
import from ...components.board.TaskDialog { TaskDialog }
import from ...components.flowlines.kinds { COUNT_TINT, statusChip, colorKey }
import from ...lib.utils { fmtEstimate, parseEstimate }
import from "sonner" { toast }
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
     SCOPE_KEYS: list[str] = ["working", "all", "done", "attention"],
     SORT_KEYS: list[str] = [
         "title",
         "step",
         "priority",
         "estimate",
         "category",
         "due",
         "updated"
     ],
     PAGE_SIZE: int = 50,
     # The board's task form and handoff kinds, so the dialog opened here is
     # the board's dialog with the board's fields.
     BLANK_TASK: dict[str, str] = {
         "title": "",
         "category": "",
         "tags": "",
         "estimate": "",
         "project": "",
         "priority": "Medium",
         "status": "Backlog",
         "due_date": "",
         "notes": "",
         "issue": "",
         "pr": "",
         "reviewer": "none",
         "review_due": ""
     },
     HANDOFF_KINDS: list[str] = ["handoff", "blocked"];

# One query-string value, or `fallback` when it is absent or not in `allowed`
# (an empty `allowed` takes any value). Nothing strips the params, so both
# mounts of a full page load read the same view.
def urlParam(key: str, fallback: str, allowed: list[str] = []) -> str {
    w: any = window;
    params: any = new(w.URLSearchParams, w.location.search);
    raw = params.get(key);
    if not raw {
        return fallback;
    }
    value = str(raw);
    if len(allowed) > 0 and value not in allowed {
        return fallback;
    }
    return value;
}

# The page number from the URL: digits only, at least 1.
def urlPage -> int {
    raw = urlParam("page", "1");
    for c in raw {
        if c not in "0123456789" {
            return 1;
        }
    }
    n = int(raw);
    return n if n >= 1 else 1;
}

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
        # The view starts from the URL; writeUrl mirrors every change back.
        scope: str = urlParam("scope", "all", SCOPE_KEYS),
        fProject: str = urlParam("project", "all"),
        fAssignee: str = urlParam("assignee", "All"),
        fCategory: str = urlParam("category", "All"),
        fTag: str = urlParam("tag", "All"),
        fEstimate: str = urlParam("estimate", "All", ["All", "yes", "no"]),
        categories: list[str] = [],
        tags: list[str] = [],
        query: str = urlParam("q", ""),
        # The committed query; the input holds the draft until Enter.
        queryDraft: str = urlParam("q", ""),
        sort: str = urlParam("sort", "updated", SORT_KEYS),
        sortDir: str = urlParam("dir", "desc", ["asc", "desc"]),
        page: int = urlPage(),
        # The flow line and roles, for step names and the task dialog.
        steps: list[StepView] = [],
        roleRows: list[RoleView] = [],
        taskOpen: bool = False,
        editTaskId: str = "",
        taskForm: dict[str, str] = BLANK_TASK,
        taskAssignees: list[str] = [],
        taskSaving: bool = False,
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
        writeUrl();
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
    def writeUrl -> None;
    def columnKeys -> list[str];
    def columnKind(key: str) -> str;
    def columnKeyOf(t: TaskView, keys: list[str]) -> str;
    def mappedStatus(key: str) -> str;
    def openTask(tid: str) -> None;
    def setTaskField(key: str, value: str) -> None;
    def toggleTaskAssignee(memberId: str) -> None;
    async def saveTask -> None;
    async def deleteTask -> None;

    pageCount = (total + PAGE_SIZE - 1) // PAGE_SIZE if total > 0 else 1;
    shownMembers = [
        m
        for m in members
        if fProject == "all" or fProject in m.project_ids
    ];
    activeProjects = [
        p
        for p in projects
        if p.active
    ];
    activeMembers = [
        m
        for m in members
        if m.active
    ];
    # The board's columns, with the name and chip each one shows. The Step
    # column places every row by the board's rule, so the two cannot differ.
    colKeys = columnKeys();
    colLabels: list[str] = [];
    colTints: list[str] = [];
    handoffKeys: list[str] = [];
    for key in colKeys {
        label = key;
        tint = statusChip(key);
        for st in steps {
            if st.id == key {
                label = st.name;
                ck = colorKey(st.color);
                tint = COUNT_TINT[ck] if ck in COUNT_TINT else COUNT_TINT["slate"];
            }
        }
        colLabels.append(label);
        colTints.append(tint);
        if columnKind(key) in HANDOFF_KINDS {
            handoffKeys.append(key);
        }
    }
    stepNames: dict[str, str] = {};
    stepTints: dict[str, str] = {};
    for t in rows {
        placed = columnKeyOf(t, colKeys);
        for (ci, k) in enumerate(colKeys) {
            if k == placed {
                stepNames[t.id] = colLabels[ci];
                stepTints[t.id] = colTints[ci];
            }
        }
    }

    return
        <div className="space-y-5">
            <div className="flex flex-wrap items-end justify-between gap-3">
                <div>
                    <h1 className="page-title">Tasks</h1>
                    <p className="page-subtitle">
                        Every task in one sortable table. Open a row to edit it.
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
                        onOpen={openTask}
                        stepHeader={"Step" if len(steps) > 0 else "Status"}
                        stepNames={stepNames}
                        stepTints={stepTints}
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
            <TaskDialog
                open={taskOpen}
                editing={True}
                form={taskForm}
                projects={activeProjects}
                members={activeMembers}
                saving={taskSaving}
                onField={setTaskField}
                onOpenChange={lambda (o: bool) { taskOpen = o; }}
                onSave={saveTask}
                onDelete={deleteTask}
                categories={categories}
                columnKeys={colKeys}
                columnLabels={colLabels}
                handoffKeys={handoffKeys}
                assignees={taskAssignees}
                onToggleAssignee={toggleTaskAssignee}
                steps={steps}
                roles={roleRows}
            />
        </div>;
}
