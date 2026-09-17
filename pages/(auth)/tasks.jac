"""flowline - Tasks (/tasks): a flat, sortable, filterable table over the whole
task set, the cross-column view the board cannot give. A row (or New task)
opens the board's task dialog in place, and scope, filters, sort and page live
in the URL, so a reload, the back button or a shared link keeps the view."""

import from "react" { useEffect }
import from ...models {
    Project,
    MemberView,
    TaskView,
    StepView,
    RoleView,
    IterationView
}
import from ...constants { STATUSES, STATUS_KIND, KIND_STATUS, KIND_COLORS }
import from ...services.tasks.tasks { ListTasks, CreateTask, UpdateTask, DeleteTask }
import from ...services.roster.roster { ListMembers, ListRoles }
import from ...services.iterations.iterations { ListIterations }
import from ...services.projects.projects { ListProjects, AssignToProject }
import from ...services.flowlines.flowlines { GetFlowLine }
import from ...components.tasks.TaskTable { TaskTable }
import from ...components.tasks.TaskToolbar { TaskToolbar, ScopeSwitch }
import from ...components.board.TaskDialog { TaskDialog }
import from ...lib.utils { fmtEstimate, parseEstimate }
import from "sonner" { toast }
import from ...components.ui.button { Button }
import from ...components.ui.skeleton { Skeleton }
import from ...components.common.Reveal { Reveal }
import from ...components.common.LoadFailed { LoadFailed }
import from ...components.common.Busy { Busy }

glob SCOPE_KEYS: list[str] = ["working", "done", "all", "attention"],
     # Only the table's sortable headers: an old ?sort=estimate link falls back
     # to the default rather than ordering by a column nobody can see.
     SORT_KEYS: list[str] = ["title", "step", "priority", "due", "updated"],
     PRIORITY_RANK: dict[str, int] = {"High": 0, "Medium": 1, "Low": 2},
     PRIORITY_KEYS: list[str] = ["All", "High", "Medium", "Low"],
     PAGE_SIZE: int = 50,
     # Step and priority are filtered here, over every matching page read at
     # the walker's largest page size (ListTasks has no such filters yet).
     GATHER_SIZE: int = 500,
     GATHER_PAGES: int = 40,
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
         "start_date": "",
         "iteration": "none",
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
# The category and tag menus both build this way, so one page never empties
# a filter list just because the current page carries none of them.
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

def PlusGlyph -> JsxElement {
    return
        <svg width={14} height={14} viewBox="0 0 16 16" aria-hidden="true">
            <path
                d="M8 3v10M3 8h10"
                stroke="currentColor"
                strokeWidth={1.8}
                strokeLinecap="round"
            />
        </svg>;
}

def PagerArrow(back: bool) -> JsxElement {
    return
        <svg width={14} height={14} viewBox="0 0 16 16" aria-hidden="true">
            <path
                d={"M10 3.5 5.5 8l4.5 4.5" if back else "M6 3.5 10.5 8 6 12.5"}
                fill="none"
                stroke="currentColor"
                strokeWidth={1.7}
                strokeLinecap="round"
                strokeLinejoin="round"
            />
        </svg>;
}

def:pub TasksPage -> JsxPage {
    has rows: list[TaskView] = [],
        members: list[MemberView] = [],
        projects: list[Project] = [],
        # The view starts from the URL; writeUrl mirrors every change back.
        scope: str = urlParam("scope", "working", SCOPE_KEYS),
        fProject: str = urlParam("project", "all"),
        fAssignee: str = urlParam("assignee", "All"),
        fStep: str = urlParam("step", "All"),
        fPriority: str = urlParam("priority", "All", PRIORITY_KEYS),
        fCategory: str = urlParam("category", "All"),
        fTag: str = urlParam("tag", "All"),
        fEstimate: str = urlParam("estimate", "All", ["All", "yes", "no"]),
        categories: list[str] = [],
        tags: list[str] = [],
        # The committed query; the box holds the draft, committed as you type.
        query: str = urlParam("q", ""),
        queryDraft: str = urlParam("q", ""),
        sort: str = urlParam("sort", "updated", SORT_KEYS),
        sortDir: str = urlParam("dir", "desc", ["asc", "desc"]),
        page: int = urlPage(),
        # The flow line and roles, for step names and the task dialog.
        steps: list[StepView] = [],
        # The table waits for the flow line, so rows never flash legacy statuses.
        stepsLoaded: bool = False,
        workspaceReady: bool = False,
        roleRows: list[RoleView] = [],
        taskOpen: bool = False,
        # The dialog is creating a task rather than editing `editTaskId`.
        creating: bool = False,
        editTaskId: str = "",
        taskForm: dict[str, str] = BLANK_TASK,
        iterations: list[IterationView] = [],
        taskAssignees: list[str] = [],
        taskSaving: bool = False,
        total: int = 0,
        # Tasks in the scope before any filter, for "4 of 22 tasks".
        scopeTotal: int = -1,
        hasMore: bool = False,
        loading: bool = True,
        refreshing: bool = False,
        failed: bool = False,
        # The J/K row, and the app header's height the table header sticks under.
        cursor: int = -1,
        stickyTop: int = 0,
        # Only the newest fetch may paint: filter and page changes race.
        reqRef: Ref[any] = Ref(),
        # The step/priority match set for one view, and per-scope totals.
        poolRef: Ref[any] = Ref(),
        totalsRef: Ref[any] = Ref(),
        # Set once the members, projects and flow line have loaded.
        readyRef: Ref[any] = Ref();

    async can with entry {
        loadWorkspace();
    }

    # One dependent effect covers every input to the same read.
    async can with (
        scope,
        fProject,
        fAssignee,
        fStep,
        fPriority,
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

    # The search runs as you type, once the keys pause.
    useEffect(
        lambda {
            timer: any = window.setTimeout(lambda { commitSearch(); }, 250);
            return lambda { window.clearTimeout(timer); };
        },
        [queryDraft]
    );

    # "/" focuses the search, J/K move the row cursor, Enter opens it. The
    # header offset is re-read on resize, since the app bar can change height.
    useEffect(
        lambda {
            onKey = lambda (e: any) { handleKey(e); };
            onResize = lambda { measureHeader(); };
            window.addEventListener("keydown", onKey);
            window.addEventListener("resize", onResize);
            measureHeader();
            return lambda {
                window.removeEventListener("keydown", onKey);
                window.removeEventListener("resize", onResize);
            };
        },
        []
    );

    async def loadWorkspace -> None;
    async def loadTasks -> None;
    async def gatherPool(seq: int) -> list[TaskView];
    def sortPool(pool: list[TaskView]) -> list[TaskView];
    def filtered -> bool;
    def forget -> None;
    def sortBy(field: str) -> None;
    def chooseScope(value: str) -> None;
    def pickProject(value: str) -> None;
    def pickAssignee(value: str) -> None;
    def pickStep(value: str) -> None;
    def pickPriority(value: str) -> None;
    def pickCategory(value: str) -> None;
    def pickTag(value: str) -> None;
    def pickEstimate(value: str) -> None;
    def typeSearch(value: str) -> None;
    def commitSearch -> None;
    def clearFilters -> None;
    def goPage(delta: int) -> None;
    def writeUrl -> None;
    def handleKey(e: any) -> None;
    def moveCursor(delta: int) -> None;
    def focusRow(i: int, scroll: bool) -> None;
    def refocusRow -> None;
    def pointAt(i: int) -> None;
    def measureHeader -> None;
    def columnKeys -> list[str];
    def columnKind(key: str) -> str;
    def columnKeyOf(t: TaskView, keys: list[str]) -> str;
    def mappedStatus(key: str) -> str;
    def openTask(tid: str) -> None;
    def openCreate -> None;
    def dialogOpenChange(o: bool) -> None;
    def replaceRow(view: TaskView) -> None;
    def setTaskField(key: str, value: str) -> None;
    def toggleTaskAssignee(memberId: str) -> None;
    async def saveTask -> None;
    async def deleteTask -> None;

    pageCount = (total + PAGE_SIZE - 1) // PAGE_SIZE if total > 0 else 1;
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
    # The board's columns, with the name and colour each one shows. The Step
    # column places every row by the board's rule, so the two cannot differ.
    colKeys = columnKeys();
    colLabels: list[str] = [];
    colColors: list[str] = [];
    stepOptions: list[list[str]] = [];
    handoffKeys: list[str] = [];
    for key in colKeys {
        label = key;
        kind = columnKind(key);
        color = KIND_COLORS[kind] if kind in KIND_COLORS else "slate";
        for st in steps {
            if st.id == key {
                label = st.name;
                color = st.color;
            }
        }
        colLabels.append(label);
        colColors.append(color);
        # A step shows its swatch; a legacy status its kind glyph (C10).
        stepOptions.append(
            [key, label, color] if len(steps) > 0 else [key, label, "", kind]
        );
        if kind in HANDOFF_KINDS {
            handoffKeys.append(key);
        }
    }
    taskChecklist: list[dict[str, any]] = [];
    taskCreated: str = "";
    taskUpdated: str = "";
    taskPrState: str = "";
    for t in rows {
        if t.id == editTaskId and not creating {
            taskChecklist = t.checklist;
            taskCreated = t.created_at;
            taskUpdated = t.updated_at;
            taskPrState = t.pr_state;
        }
    }
    stepNames: dict[str, str] = {};
    stepColors: dict[str, str] = {};
    stepKinds: dict[str, str] = {};
    for t in rows {
        placed = columnKeyOf(t, colKeys);
        if len(steps) == 0 {
            stepKinds[t.id] = columnKind(placed);
        }
        for (ci, k) in enumerate(colKeys) {
            if k == placed {
                stepNames[t.id] = colLabels[ci];
                stepColors[t.id] = colColors[ci];
            }
        }
    }
    isFiltered = filtered();
    stepWord = "Status" if stepsLoaded and len(steps) == 0 else "Step";
    waiting = loading or not stepsLoaded;
    leadName = "";
    for m in members {
        if m.id == fAssignee {
            leadName = m.name;
        }
    }
    first = (page - 1) * PAGE_SIZE;
    countLabel = str(total) + (" task" if total == 1 else " tasks");
    if pageCount > 1 {
        last = first + len(rows);
        countLabel = str(first + 1) + "–" + str(last) + " of " + str(total) + " tasks";
    } elif isFiltered and scopeTotal > total {
        countLabel = str(total) + " of " + str(scopeTotal) + " tasks";
    }
    emptyLabel = "No tasks yet.";
    if isFiltered {
        emptyLabel = "No tasks match these filters.";
    } elif scope == "working" {
        emptyLabel = "Nothing open or recently done.";
    } elif scope == "done" {
        emptyLabel = "No finished tasks yet.";
    } elif scope == "attention" {
        emptyLabel = "Nothing is blocked or overdue.";
    }

    def loadFrame -> JsxElement {
        return
            <TaskTable
                rows={[]}
                placeholder={10}
                sort={sort}
                sortDir={sortDir}
                onSort={sortBy}
                onOpen={openTask}
                stepHeader={stepWord}
                stickyTop={stickyTop}
            />;
    }

    return
        <div className="flex min-w-0 flex-col gap-4">
            <div className="flex flex-wrap items-center gap-x-4 gap-y-2">
                <h1 className="page-title">Tasks</h1>
                <div className="max-sm:order-last">
                    <ScopeSwitch scope={scope} onScope={chooseScope}/>
                </div>
                <Button
                    className="ml-auto gap-1.5"
                    disabled={not workspaceReady}
                    onClick={lambda { openCreate(); }}
                >
                    <PlusGlyph/>
                    New task
                </Button>
            </div>
            <div
                data-tasks-top="true"
                className="surface @container min-w-0 scroll-mt-16"
            >
                <TaskToolbar
                    projects={projects}
                    members={members}
                    steps={stepOptions if stepsLoaded else []}
                    project={fProject}
                    assignee={fAssignee}
                    step={fStep}
                    priority={fPriority}
                    onProject={pickProject}
                    onAssignee={pickAssignee}
                    onStep={pickStep}
                    onPriority={pickPriority}
                    query={queryDraft}
                    onQuery={typeSearch}
                    onClear={clearFilters}
                    categories={categories}
                    tags={tags}
                    category={fCategory}
                    tag={fTag}
                    estimate={fEstimate}
                    onCategory={pickCategory}
                    onTag={pickTag}
                    onEstimate={pickEstimate}
                    refreshing={refreshing}
                    countLabel={countLabel}
                    stepLabel={stepWord}
                />
                <Reveal ready={not waiting} frame={loadFrame()}>
                    {if failed {
                        <div key="failed" className="p-4">
                            <LoadFailed
                                title="Could not load tasks"
                                onRetry={loadTasks}
                            />
                        </div>
                    } else {
                        <div key="table">
                            <TaskTable
                                rows={rows}
                                sort={sort}
                                sortDir={sortDir}
                                onSort={sortBy}
                                onOpen={openTask}
                                stepNames={stepNames}
                                stepColors={stepColors}
                                stepKinds={stepKinds}
                                stepHeader={stepWord}
                                leadName={leadName}
                                cursor={cursor}
                                onCursor={pointAt}
                                refreshing={refreshing}
                                stickyTop={stickyTop}
                                emptyLabel={emptyLabel}
                                emptyAction={"Clear filters" if isFiltered else ""}
                                onEmptyAction={clearFilters}
                            />
                        </div>
                    } }
                </Reveal>
                {if not failed {
                    <div
                        key="foot"
                        className="flex flex-wrap items-center gap-x-4 gap-y-2 border-t px-4 py-2 text-[12.5px] text-muted-foreground"
                    >
                        {if waiting {
                            <Skeleton key="count" className="h-3 w-16"/>
                        } else {
                            <span key="count" className="num" aria-live="polite">
                                {countLabel}
                            </span>
                        } }
                        <Busy active={refreshing} className="@min-[50rem]:hidden"/>
                        <div
                            className="ml-auto flex flex-wrap items-center gap-x-4 gap-y-2"
                        >
                            {if len(rows) > 0 or waiting {
                                <span
                                    key="keys"
                                    className="hidden items-center gap-1 @min-[50rem]:inline-flex"
                                >
                                    <span className="kbd">J</span>
                                    <span className="kbd">K</span>
                                    <span className="mr-1">move,</span>
                                    <span className="kbd">Enter</span>
                                    <span>opens</span>
                                </span>
                            }}
                            {if pageCount > 1 and not waiting {
                                <div key="pager" className="flex items-center gap-2">
                                    <span className="num">
                                        {"Page " + str(page) + " of " + str(pageCount)}
                                    </span>
                                    <Button
                                        variant="outline"
                                        size="icon"
                                        aria-label="Previous page"
                                        disabled={page <= 1}
                                        onClick={lambda { goPage(-1); }}
                                    >
                                        <PagerArrow back={True}/>
                                    </Button>
                                    <Button
                                        variant="outline"
                                        size="icon"
                                        aria-label="Next page"
                                        disabled={not hasMore}
                                        onClick={lambda { goPage(1); }}
                                    >
                                        <PagerArrow back={False}/>
                                    </Button>
                                </div>
                            }}
                        </div>
                    </div>
                }}
            </div>
            <TaskDialog
                open={taskOpen}
                editing={not creating}
                form={taskForm}
                projects={activeProjects}
                members={activeMembers}
                saving={taskSaving}
                onField={setTaskField}
                onOpenChange={dialogOpenChange}
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
                taskId={"" if creating else editTaskId}
                checklist={taskChecklist}
                onChecklist={replaceRow}
                iterations={iterations}
                createdAt={taskCreated}
                historyKey={taskUpdated}
                prState={taskPrState}
            />
        </div>;
}
