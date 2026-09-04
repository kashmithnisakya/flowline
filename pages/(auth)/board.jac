"""flowline - Board page (/board): the org's flow line as a kanban. The columns
ARE the flow line steps in designed order, so board and Flow line tab cannot
disagree; with no flow line yet it falls back to the six statuses. Stateful
shell: data and handlers here, columns/cards/filters/dialog presentational."""

import from ...models { Project, MemberView, TaskView, StepView, RepoView, RoleView }
# The one client import of constants.jac. Beyond sharing the status/kind
# mapping, it is what makes the compiler emit constants.js at all: the client
# compiles lazily, and a module nothing imports produces no output.
import from ...constants { STATUSES, STATUS_KIND, KIND_STATUS }

import from ...walkers.board { BoardSnapshot }
import from ...walkers.projects { AssignToProject }
import from ...walkers.tasks {
    ListTasks,
    GetTask,
    CreateTask,
    UpdateTask,
    MoveTask,
    SetMoveInfo,
    DeleteTask
}
import from ...walkers.github { SyncGithub, CreateIssueFromTask }
import from ...components.common.KineticGrid { KineticGrid }
import from ...components.board.FilterBar { FilterBar }
import from ...components.board.KanbanColumn { KanbanColumn }
import from ...components.board.TaskDialog { TaskDialog }
import from ...components.board.MoveDialog { MoveDialog }
import from ...components.ui.button { Button }
import from ...components.ui.skeleton { Skeleton }
import from "sonner" { toast }
import from "react" { useEffect }
import from ...components.common.glyphs { Spinner }
import from ...components.common.LoadFailed { LoadFailed, StaleDataStrip }
import from ...lib.dates { todayIso, dueTone }
import from ...lib.utils { fmtEstimate, parseEstimate }

glob BLANK_TASK: dict[str, str] = {
         "title": "",
         "category": "",
         "estimate": "",
         "tags": "",
         "project": "none",
         "priority": "Medium",
         "status": "Backlog",
         "due_date": "",
         "notes": "",
         "issue": "",
         "pr": "",
         "reviewer": "none",
         "review_due": ""
     },
     BLANK_MOVE: dict[str, str] = {
         "reviewer": "none",
         "review_due": "",
         "pr": "",
         "note": ""
     },
     # Step kinds whose moves open the optional handoff dialog: work that
     # has been passed to someone else, or has stopped.
     HANDOFF_KINDS: list[str] = ["handoff", "blocked"];


def:pub BoardPage -> JsxPage {
    has showAllDone: bool = False,
        # The working set: open tasks plus Done touched in the last week,
        # which is everything the board renders until "completed earlier"
        # is opened. Older Done history pages in on demand below.
        tasks: list[TaskView] = [],
        olderDone: list[TaskView] = [],
        # How many older Done rows exist under the current filters (-1
        # until the first filtered fetch says), how many pages are in, and
        # whether the server holds more.
        olderTotal: int = 0,
        olderPage: int = 0,
        olderMore: bool = False,
        loadingOlder: bool = False,
        # A `has` read after an await is the render-time value, so the
        # in-flight latch and the newest filters live on refs instead.
        olderRef: Ref[any] = Ref(),
        rowsRef: Ref[any] = Ref(),
        filterRef: Ref[any] = Ref(),
        # The working set is fetched in pages; past the bound the board
        # says so rather than quietly showing part of the workspace.
        workingTruncated: bool = False,
        # Distinct categories over the whole history, from the snapshot.
        knownCategories: list[str] = [],
        members: list[MemberView] = [],
        # The org's roles, for the lane order and colours in the task
        # dialog's flow line picture.
        roleRows: list[RoleView] = [],
        projects: list[Project] = [],
        steps: list[StepView] = [],
        repos: list[RepoView] = [],
        ghConnected: bool = False,
        syncing: bool = False,
        loading: bool = True,
        movesRef: Ref[any] = Ref(),
        fProject: str = "all",
        fAssignee: str = "All",
        fCategory: str = "All",
        # A tag the card must carry, or "All"; the estimate filter is "All",
        # "yes" (estimated) or "no" (unestimated). Client-side, like the rest.
        fTag: str = "All",
        fEstimate: str = "All",
        hideDone: bool = False,
        dialogOpen: bool = False,
        editingId: str = "",
        form: dict[str, str] = BLANK_TASK,
        fAssignees: list[str] = [],
        moveTaskId: str = "",
        moveTaskTitle: str = "",
        moveStatus: str = "",
        moveKind: str = "handoff",
        mForm: dict[str, str] = BLANK_MOVE,
        saving: bool = False,
        # The last fetch failed. With nothing on screen that is a full
        # panel; with a board already showing, a strip that names the time
        # of the last good load (loadedAt, "10:42").
        loadFailed: bool = False,
        retrying: bool = False,
        loadedAt: str = "",
        # A /board?task=<id> deep link (the overview's attention list, the
        # palette) opens that card once the first load has landed; "new"
        # opens the create dialog (/board?new=1).
        pendingTaskId: str = "";

    async can with entry {
        movesRef.current = 0;
        stored = localStorage.getItem("standup_project") or "";
        if stored {
            fProject = stored;
            # boot() runs in this same tick, where `fProject` still reads
            # "all"; the ref carries the effective filter across.
            filterRef.current = stored + "|All|All";
        }
        w: any = window;
        params: any = new(w.URLSearchParams, w.location.search);
        wanted = params.get("task") or "";
        if wanted {
            pendingTaskId = str(wanted);
        }
        if params.get("new") {
            pendingTaskId = "new";
        }
        boot();
    }

    # Runs from the render that has the loaded tasks and steps, so openEdit
    # sees fresh state (reading `tasks` right after `await loadAll()` in boot
    # would see the pre-load snapshot).
    useEffect(
        lambda { if pendingTaskId and not loading {
            if pendingTaskId == "new" {
                openCreate("");
            } else {
                openById(pendingTaskId);
            }
            pendingTaskId = "";
            # Consume the param only now: on a full load the page mounts
            # twice (bare, then inside the chrome once login resolves), and
            # the second mount must still find it. Stripping it here also
            # keeps a reload or the poll from reopening the card.
            w: any = window;
            if w.location.search {
                w.history.replaceState(None, "", w.location.pathname);
            }
        }},
        [pendingTaskId, loading, len(tasks)]
    );

    # Live-ish board: refetch on tab focus plus a 60s poll, both through
    # refreshTasks -- one walker call, no roster refetch. One manual
    # useEffect so the listener/interval handles are visible to the cleanup
    # (entry/exit abilities compile to separate closures).
    useEffect(
        lambda {
            onFocus = lambda { refreshTasks(); };
            window.addEventListener("focus", onFocus);
            # The assistant dock lives in the layout, not in this tree, so an
            # applied proposal announces itself with an event rather than leaving
            # the new card invisible until the next poll.
            window.addEventListener("standup:refresh", onFocus);
            # The command palette, mounted in the layout, asks an already
            # mounted board to open a card or the new-task dialog.
            onOpenTask = lambda (e: any) { pendingTaskId = str(e.detail or ""); };
            onNewTask = lambda { pendingTaskId = "new"; };
            window.addEventListener("standup:open-task", onOpenTask);
            window.addEventListener("standup:new-task", onNewTask);
            timer = window.setInterval(lambda { refreshTasks(); }, 60000);
            return lambda {
                window.removeEventListener("focus", onFocus);
                window.removeEventListener("standup:refresh", onFocus);
                window.removeEventListener("standup:open-task", onOpenTask);
                window.removeEventListener("standup:new-task", onNewTask);
                window.clearInterval(timer);
            };
        },
        []
    );

    async def boot -> None;
    # loadAll refreshes everything (boot, and every write that can touch the
    # roster); refreshTasks is the poll's path and skips the workspace lists,
    # which are edited on other pages. Both run through loadBoard.
    async def loadAll -> None;
    async def refreshTasks -> None;
    async def loadBoard(withWorkspace: bool) -> dict;
    async def retryLoad -> None;
    # Older Done history: page 1 replaces, later pages append; any filter
    # change or task write starts over so the rows never go stale.
    # `pid`/`who`/`cat` are passed, never read from state: a setter's new
    # value is not visible to the same handler that set it.
    async def loadOlder(page: int, pid: str, who: str, cat: str) -> None;
    async def refreshOlder(pid: str, who: str, cat: str) -> None;
    def toggleOlder -> None;
    async def openById(taskId: str) -> None;
    async def saveTask -> None;
    async def deleteTask -> None;
    # The columns ARE the flow line, so every column question routes through
    # these rather than a status literal. Page methods, not module defs,
    # because they all read `steps`.
    def columnKeys -> list[str];
    def columnLabel(key: str) -> str;
    def columnKind(key: str) -> str;
    def columnColor(key: str) -> str;
    def columnKeyOf(t: TaskView) -> str;
    def mappedStatus(key: str) -> str;
    def doneColumnKey -> str;
    async def moveTo(
        taskId: str, columnKey: str, anchorId: str = "", ahead: bool = False
    ) -> None;
    def moveBeside(draggedId: str, targetId: str, ahead: bool) -> None;
    def arrowMove(t: TaskView, columnKey: str) -> None;
    def setProjectFilter(v: str) -> None;
    def setAssigneeFilter(v: str) -> None;
    def setCategoryFilter(v: str) -> None;
    def filtersOn(pid: str, who: str, cat: str) -> bool;
    def setField(key: str, value: str) -> None;
    def setMoveField(key: str, value: str) -> None;
    def toggleAssignee(memberId: str) -> None;
    async def saveMoveInfo -> None;
    # Empty inKey lands the task in the first column.
    def openCreate(inKey: str = "") -> None;
    def openEdit(t: TaskView) -> None;
    async def syncGithub -> None;
    async def autoSyncGithub(connected: bool) -> None;
    def openTaskById(tid: str) -> None;
    async def createIssue(repoId: str) -> None;

    activeMembers = [
        m
        for m in members
        if m.active
    ];
    activeProjects = [
        p
        for p in projects
        if p.active
    ];
    # Categories are whatever the org has actually typed on its tasks.
    # Every category the workspace uses, counted server-side: built from the
    # working set alone it would lose the ones only old Done tasks carry,
    # and then you could not filter by them.
    allCategories: list[str] = [c for c in knownCategories];
    for t in tasks + olderDone {
        if t.category and t.category not in allCategories {
            allCategories.append(t.category);
        }
    }
    allCategories.sort();
    # Tags for the filter dropdown, from the loaded set (unlike categories,
    # tags are not carried in the snapshot; the working set is enough to
    # filter what the board shows).
    allTags: list[str] = [];
    for t in tasks + olderDone {
        for tg in t.tags {
            if tg not in allTags {
                allTags.append(tg);
            }
        }
    }
    allTags.sort();

    # One filter predicate for both the working set and the older-Done list,
    # so a new condition is added once. hideDone and the older-list's own
    # showAllDone guard stay at the call sites, since they differ per list.
    def matches(t: TaskView) -> bool {
        return (fProject == "all" or t.project_id == fProject)
            and (fAssignee == "All" or fAssignee in t.assignee_ids)
            and (fCategory == "All" or t.category == fCategory)
            and (fTag == "All" or fTag in t.tags)
            and (
                fEstimate == "All"
                or (fEstimate == "yes" and t.estimate > 0.0)
                or (fEstimate == "no" and t.estimate <= 0.0)
            );
    }

    colKeys = columnKeys();
    doneKey = doneColumnKey();
    today = todayIso();
    # No flow line AND nothing to show: six empty placeholder columns are noise
    # on a workspace that has not decided what its columns are yet. A legacy
    # org that HAS tasks still gets the fallback columns, because hiding the
    # board would hide its work.
    # A failed first load also has no steps and no tasks; it must not be
    # mistaken for a workspace that has not designed its flow line yet.
    nothingLoaded = loadFailed and len(steps) == 0 and len(tasks) == 0;
    noFlowLine = not nothingLoaded and len(steps) == 0 and len(tasks) == 0;

    visible = [
        t
        for t in tasks
        if matches(t) and (not hideDone or t.status != "Done")
    ];
    # Everything Done in the working set is recent by construction (the
    # server's cutoff); older history is its own list, fetched under the
    # same filters, so the client filter here only guards a filter that
    # changed while a page was in flight.
    recentDone = [
        t
        for t in visible
        if doneKey and columnKeyOf(t) == doneKey
    ];
    olderShown = [
        t
        for t in olderDone
        if showAllDone and not hideDone and matches(t)
    ];
    # The dialog hides its create-issue button once a task carries an issue,
    # so the number comes from server truth rather than the form dict.
    editingIssueNumber = 0;
    # The open card's sub-issue family, resolved from rows already loaded:
    # its children when it is a parent, its parent's card when it is a child.
    famRows: list[TaskView] = [];
    famTotal: int = 0;
    famDone: int = 0;
    famParentId: str = "";
    famParentLabel: str = "";
    for t in tasks + olderDone {
        if t.id == editingId {
            editingIssueNumber = t.gh_issue_number;
            famTotal = t.gh_sub_total;
            famDone = t.gh_sub_done;
            if t.gh_sub_total > 0 {
                for kid in tasks + olderDone {
                    if (
                        kid.gh_parent_number > 0
                        and kid.gh_parent_repo == t.gh_repo
                        and kid.gh_parent_number == t.gh_issue_number
                    ) {
                        famRows.append(kid);
                    }
                }
            }
            if t.gh_parent_number > 0 {
                for pt in tasks + olderDone {
                    if (
                        pt.gh_repo == t.gh_parent_repo
                        and pt.gh_issue_number == t.gh_parent_number
                    ) {
                        famParentId = pt.id;
                        famParentLabel = "#"
                            + str(pt.gh_issue_number)
                            + " · "
                            + pt.title;
                    }
                }
            }
        }
    }

    return
        <div className="space-y-4">
            <div className="flex flex-wrap items-center justify-between gap-3">
                <h1 className="page-title">Board</h1>
                {if loading {
                    <div key="tools-skel" className="flex flex-wrap items-center gap-2">
                        <Skeleton className="h-8 w-44"/>
                        <Skeleton className="h-8 w-40"/>
                        <Skeleton className="h-8 w-40"/>
                        <Skeleton className="h-8 w-24"/>
                        <Skeleton className="h-8 w-24"/>
                    </div>
                } elif not noFlowLine and not nothingLoaded {
                    <div key="tools" className="flex items-center gap-2">
                        <FilterBar
                            projects={activeProjects}
                            members={activeMembers}
                            project={fProject}
                            assignee={fAssignee}
                            category={fCategory}
                            hideDone={hideDone}
                            onProject={setProjectFilter}
                            onAssignee={setAssigneeFilter}
                            onCategory={setCategoryFilter}
                            onHideDone={lambda { hideDone = not hideDone; }}
                            categories={allCategories}
                            tags={allTags}
                            tag={fTag}
                            estimate={fEstimate}
                            onTag={lambda (v: str) { fTag = v; }}
                            onEstimate={lambda (v: str) { fEstimate = v; }}
                        />
                        {if ghConnected {
                            <Button
                                key="sync"
                                variant="outline"
                                disabled={syncing}
                                onClick={syncGithub}
                            >
                                {if syncing {
                                    <Spinner key="sp"/>
                                }}
                                {"Syncing…" if syncing else "Sync GitHub"}
                            </Button>
                        }}
                        <Button onClick={lambda { openCreate(""); }}>New task</Button>
                    </div>
                } }
            </div>
            {if workingTruncated and not loading {
                <div
                    key="truncated"
                    className="rounded-lg border border-warning/50 bg-warning/10 px-3 py-2 text-xs text-warning"
                    role="status"
                >
                    More open work than the board loads at once, so some cards are missing. Narrow the filters, or archive what is finished.
                </div>
            }}
            {if loadFailed and not nothingLoaded and not loading {
                <StaleDataStrip
                    key="stale"
                    since={loadedAt}
                    onRetry={retryLoad}
                    retrying={retrying}
                />
            }}
            {if loading {
                # Mirrors the loaded board: one row of column shells, each
                # with a header (dot, label bar, count pill) and card blocks,
                # so data landing swaps content without reflow.
                <div
                    key="skeletons"
                    className={"grid snap-x snap-mandatory items-start gap-3 overflow-x-auto px-0.5 pt-1 pb-3 md:items-stretch "
                        + (
                            # The refresh-failed strip takes a row above the lanes.
                            "[--lane-h:calc(100dvh-15.5rem)]"
                                if loadFailed
                                else "[--lane-h:calc(100dvh-12.5rem)]"
                        )}
                    style={{"gridTemplateColumns": "repeat(5, minmax(17rem, 1fr))"}}
                >
                    {for i in [0, 1, 2, 3, 4] {
                        <div
                            key={"sk" + str(i)}
                            className="flex min-h-44 w-full min-w-0 snap-start flex-col gap-2 rounded-xl border bg-muted/30 p-2 md:h-[var(--lane-h)]"
                        >
                            <div
                                className="flex items-center justify-between px-1 py-1"
                            >
                                <div className="flex items-center gap-1.5">
                                    <Skeleton className="size-2 rounded-full"/>
                                    <Skeleton className="h-4 w-20"/>
                                </div>
                                <Skeleton className="h-5 w-6 rounded-full"/>
                            </div>
                            <Skeleton className="h-20 w-full"/>
                            <Skeleton className="h-20 w-full"/>
                            {if i % 2 == 0 {
                                <Skeleton key="c3" className="h-20 w-full"/>
                            }}
                        </div>
                    }}
                </div>
            } elif nothingLoaded {
                <LoadFailed
                    key="failed"
                    title="Could not load the board"
                    onRetry={retryLoad}
                    retrying={retrying}
                />
            } elif noFlowLine {
                <div
                    key="noflowline"
                    className="relative flex flex-col items-center gap-3 overflow-hidden rounded-xl border border-dashed px-6 py-16 text-center"
                >
                    <KineticGrid
                        className="[mask-image:linear-gradient(to_bottom,black_55%,transparent)]"
                    />
                    <div
                        className="anim-fade-up relative z-10 flex flex-col items-center gap-3"
                    >
                        <svg
                            width={40}
                            height={40}
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth={1.5}
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            className="text-muted-foreground/70"
                        >
                            <circle cx={5} cy={12} r={2.5}/>
                            <circle cx={19} cy={5} r={2.5}/>
                            <circle cx={19} cy={19} r={2.5}/>
                            <path d="m7.3 10.8 9.4-4.6"/>
                            <path d="m7.3 13.2 9.4 4.6"/>
                        </svg>
                        <h2 className="font-display text-lg font-semibold">
                            Your board is the flow line you design
                        </h2>
                        <p
                            className="max-w-md text-sm text-pretty text-muted-foreground"
                        >
                            Name the steps your team actually uses and connect them however work moves. The columns here follow, so the two can never disagree.
                        </p>
                        <Button
                            onClick={lambda { window.location.href = "/flowlines"; }}
                        >
                            Design your flow line
                            <svg
                                width={16}
                                height={16}
                                viewBox="0 0 24 24"
                                fill="none"
                                stroke="currentColor"
                                strokeWidth={2}
                                strokeLinecap="round"
                                strokeLinejoin="round"
                            >
                                <path d="M5 12h14"/>
                                <path d="m12 5 7 7-7 7"/>
                            </svg>
                        </Button>
                    </div>
                </div>
            } else {
                # ONE row, always: columns divide the width between them, since
                # a wrapping flow line stops reading as a pipeline. No cap on a
                # column: a wide screen is more room for cards, not a margin.
                # Below the 17rem minimum the row scroll-snaps instead.
                <div
                    key="columns"
                    className={"grid snap-x snap-mandatory items-start gap-3 overflow-x-auto px-0.5 pt-1 pb-3 md:items-stretch "
                        + (
                            # The refresh-failed strip takes a row above the lanes.
                            "[--lane-h:calc(100dvh-15.5rem)]"
                                if loadFailed
                                else "[--lane-h:calc(100dvh-12.5rem)]"
                        )}
                    style={{
                        "gridTemplateColumns": "repeat("
                            + str(len(colKeys))
                            + ", minmax(17rem, 1fr))"
                    }}
                >
                    {for (ci, key) in enumerate(colKeys) {
                        <KanbanColumn
                            key={key}
                            columnKey={key}
                            label={columnLabel(key)}
                            kind={columnKind(key)}
                            color={columnColor(key)}
                            tasks={(recentDone + olderShown)
                                if key == doneKey
                                else [
                                    t
                                    for t in visible
                                    if columnKeyOf(t) == key
                                ]}
                            onOpen={openEdit}
                            onArrowMove={arrowMove}
                            onDropTask={moveTo}
                            onDropBeside={moveBeside}
                            prevKey={colKeys[ci - 1] if ci > 0 else ""}
                            prevLabel={columnLabel(colKeys[ci - 1]) if ci > 0 else ""}
                            nextKey={colKeys[ci + 1] if ci < len(colKeys) - 1 else ""}
                            nextLabel={columnLabel(colKeys[ci + 1])
                                if ci < len(colKeys) - 1
                                else ""}
                            doneKey={doneKey}
                            extraCount={olderTotal
                                if key == doneKey and not hideDone
                                else 0}
                            showingAll={showAllDone
                                if key == doneKey and not hideDone
                                else False}
                            onToggleOlder={toggleOlder}
                            moreOlder={olderMore if key == doneKey else False}
                            loadingOlder={loadingOlder if key == doneKey else False}
                            olderShown={len(olderShown) if key == doneKey else 0}
                            onMoreOlder={lambda { loadOlder(
                                olderPage + 1, fProject, fAssignee, fCategory
                            ); }}
                            onAddTask={openCreate}
                            overdueCount={0
                                if key == doneKey
                                else len(
                                    [
                                        t
                                        for t in visible
                                        if columnKeyOf(t) == key
                                            and dueTone(t.due_date, t.status, today)
                                                == "overdue"
                                    ]
                                )}
                        />
                    }}
                </div>
            }   }
            <TaskDialog
                open={dialogOpen}
                editing={bool(editingId)}
                form={form}
                projects={activeProjects}
                members={activeMembers}
                saving={saving}
                onField={setField}
                onOpenChange={lambda (o: bool) { dialogOpen = o; }}
                onSave={saveTask}
                onDelete={deleteTask}
                categories={allCategories}
                columnKeys={colKeys}
                columnLabels={[columnLabel(k) for k in colKeys]}
                handoffKeys={[
                    k
                    for k in colKeys
                    if columnKind(k) in HANDOFF_KINDS
                ]}
                assignees={fAssignees}
                onToggleAssignee={toggleAssignee}
                repos={repos}
                ghConnected={ghConnected}
                ghIssueNumber={editingIssueNumber}
                onCreateIssue={createIssue}
                steps={steps}
                roles={roleRows}
                family={famRows}
                familyTotal={famTotal}
                familyDone={famDone}
                parentTaskId={famParentId}
                parentLabel={famParentLabel}
                onOpenTask={openTaskById}
            />
            <MoveDialog
                open={bool(moveTaskId)}
                status={moveStatus}
                kind={moveKind}
                taskTitle={moveTaskTitle}
                members={activeMembers}
                form={mForm}
                saving={saving}
                onField={setMoveField}
                onOpenChange={lambda (o: bool) { if not o { moveTaskId = ""; }}}
                onSave={saveMoveInfo}
            />
        </div>;
}
