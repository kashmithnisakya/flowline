"""flowline - Board page (/board): the org's flow line as a kanban. The columns
ARE the flow line steps in designed order, so board and Flow line tab cannot
disagree; with no flow line yet it falls back to the six statuses. Stateful
shell: data and handlers here; route strip, toolbar, lanes and sheet are
presentational."""

import from ...models {
    Project,
    MemberView,
    TaskView,
    StepView,
    RepoView,
    RoleView,
    IterationView
}
# The one client import of constants.jac. Beyond sharing the status/kind
# mapping, it is what makes the compiler emit constants.js at all: the client
# compiles lazily, and a module nothing imports produces no output.
import from ...constants { STATUSES, STATUS_KIND, KIND_STATUS, KIND_COLORS }

import from ...services.board.board { BoardSnapshot }
import from ...services.projects.projects { AssignToProject }
import from ...services.tasks.tasks {
    ListTasks,
    GetTask,
    CreateTask,
    UpdateTask,
    MoveTask,
    SetMoveInfo,
    DeleteTask
}
import from ...services.github.github { SyncGithub, CreateIssueFromTask }
import from ...services.github.events { DrainGithubEvents }
import from ...components.board.FilterBar { FilterBar }
import from ...components.board.KanbanColumn { KanbanColumn }
import from ...components.board.TaskDialog { TaskDialog }
import from ...components.board.MoveDialog { MoveDialog }
import from ...components.board.RouteStrip { RouteStrip }
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
     BLANK_MOVE: dict[str, str] = {
         "reviewer": "none",
         "review_due": "",
         "pr": "",
         "note": ""
     },
     # Step kinds whose moves open the optional handoff dialog: work that
     # has been passed to someone else, or has stopped.
     HANDOFF_KINDS: list[str] = ["handoff", "blocked"],
     # The task form's fields, compared against the opened copy to tell
     # whether the sheet holds unsaved edits.
     FORM_KEYS: list[str] = [
         "title",
         "category",
         "estimate",
         "tags",
         "project",
         "priority",
         "status",
         "due_date",
         "start_date",
         "iteration",
         "notes",
         "issue",
         "pr",
         "reviewer",
         "review_due"
     ],
     # What the page was asked to open while the sheet held unsaved edits:
     # kind "task" (id, title) or "new" (lane key); kind "" is nothing.
     NO_SWITCH: dict[str, str] = {"kind": "", "id": "", "key": "", "title": ""};

# The auto sync's one-shot lives at module level on purpose: a remount
# (the page used to mount twice on a full load) gets its own `has` flags.
glob AUTO_SYNC: dict[str, float] = {"at": 0.0},
     AUTO_SYNC_ROUNDS: int = 3,
     SYNC_ROUNDS: int = 40,
     # How often an open board applies queued webhook deliveries: one keyed
     # store read per tick, no GitHub call, so it can be far shorter than
     # the 60s task poll.
     DRAIN_MS: int = 20000,
     # The lane grid, shared by the lanes and their first-load skeleton.
     # Lanes are minmax(252px,1fr): they share the width when they all fit
     # and the grid scrolls sideways once seven of them no longer do. The
     # md:-mr-1 md:pr-1 pair gives the last card list's 4px overhang a home
     # in the scroller's padding, so it neither scrolls nor clips a focus ring.
     LANE_GRID: str = "relative grid snap-x snap-mandatory auto-cols-[100%] grid-flow-col items-start gap-4 overflow-x-auto overscroll-x-contain pb-2 md:-mr-1 md:snap-none md:auto-cols-[minmax(252px,1fr)] md:grid-rows-[minmax(0,1fr)] md:items-stretch md:gap-2.5 md:pr-1",
     # Node and card title widths for the skeleton, so it reads as a board.
     NODE_WIDTHS: list[int] = [96, 88, 120, 104, 128, 96, 92],
     CARD_WIDTHS: list[str] = ["w-4/5", "w-3/5", "w-[70%]", "w-1/2"],
     LANES_KEY: str = "flowline-lanes";

# How many lanes the skeleton draws: the count the last load saw in this
# browser, else six (the legacy statuses).
def guessLanes -> int {
    raw = "";
    try {
        raw = localStorage.getItem(LANES_KEY) or "";
    } except Exception as e {
        raw = "";
    }
    n = int(raw) if raw else 6;
    return n if n >= 3 and n <= 10 else 6;
}


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
        # Bumped after each drain so the effect below re-arms its timer with
        # the current state (a setInterval closure would keep the first one).
        drainTick: int = 0,
        syncing: bool = False,
        syncNote: str = "",
        loading: bool = True,
        movesRef: Ref[any] = Ref(),
        fProject: str = "all",
        fAssignee: str = "All",
        fCategory: str = "All",
        # A tag the card must carry, or "All"; the estimate filter is "All",
        # "yes" (estimated) or "no" (unestimated). Client-side, like the rest.
        fTag: str = "All",
        fEstimate: str = "All",
        # "All", "current" (whichever iterations hold today), "none" or a jid.
        fIteration: str = "All",
        fPriority: str = "All",
        iterations: list[IterationView] = [],
        # Live search over the loaded board: matches a task title or its
        # issue/PR number, so one box covers "payment" and "412".
        boardQuery: str = "",
        hideDone: bool = False,
        dialogOpen: bool = False,
        editingId: str = "",
        form: dict[str, str] = BLANK_TASK,
        fAssignees: list[str] = [],
        # The form and assignees as the sheet opened (or last moved), so
        # opening another card over edits asks first instead of losing them.
        baseForm: dict[str, str] = BLANK_TASK,
        baseAssignees: list[str] = [],
        switchTo: dict[str, str] = NO_SWITCH,
        switchRow: Ref[any] = Ref(),
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
        pendingTaskId: str = "",
        # The lane scroller and what it shows: keys of lanes mostly on screen
        # (comma-joined, so an unchanged view is a no-op write), the lane most
        # on screen (the phone tab), lanes past the right edge, the lane
        # height on md+ and whether the md+ layout applies.
        lanesRef: Ref[any] = Ref(),
        frameRef: Ref[any] = Ref(),
        viewKeys: str = "",
        activeLane: str = "",
        hiddenAfter: int = 0,
        laneH: int = 0,
        wideView: bool = True;

    async can with entry {
        movesRef.current = 0;
        stored = localStorage.getItem("flowline_project")
            or localStorage.getItem("standup_project")
            or "";
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
            window.addEventListener("flowline:refresh", onFocus);
            # The command palette, mounted in the layout, asks an already
            # mounted board to open a card or the new-task dialog.
            onOpenTask = lambda (e: any) { pendingTaskId = str(e.detail or ""); };
            onNewTask = lambda { pendingTaskId = "new"; };
            window.addEventListener("flowline:open-task", onOpenTask);
            window.addEventListener("flowline:new-task", onNewTask);
            timer = window.setInterval(lambda { refreshTasks(); }, 60000);
            onResize = lambda { scheduleMeasure(); };
            window.addEventListener("resize", onResize);
            # "/" focuses the title filter, N opens a new task (beside a sheet
            # too) and J/K step the open sheet through the cards, unless the
            # keys are being typed or a dialog or menu has them. "/" in the
            # sheet stays there: focus behind it would lose the next Escape.
            onKey = lambda (e: any) {
                t: any = e.target;
                tag = str(t.tagName or "").lower() if t else "";
                typing = tag == "input"
                    or tag == "textarea"
                    or tag == "select"
                    or bool(t and t.isContentEditable);
                if typing or e.metaKey or e.ctrlKey or e.altKey or e.defaultPrevented {
                    return;
                }
                if document.querySelector("[role=menu], [role=listbox]") {
                    return;
                }
                inSheet = bool(t and t.closest and t.closest("[data-task-sheet]"));
                if e.key == "/" and not inSheet {
                    boxes: any = document.querySelectorAll("[data-board-search]");
                    for i in range(int(boxes.length)) {
                        box: any = boxes[i];
                        if box.offsetParent {
                            e.preventDefault();
                            box.focus();
                        }
                    }
                } elif (e.key == "n" or e.key == "N")
                    and not document.querySelector(
                        "[role=dialog][data-state=open]:not([data-beside=true])"
                    ) {
                    e.preventDefault();
                    pendingTaskId = "new";
                } elif (e.key == "j" or e.key == "J" or e.key == "k" or e.key == "K")
                    and document.querySelector("[data-task-sheet][data-state=open]")
                    and not document.querySelector(
                        "[role=dialog][data-state=open]:not([data-task-sheet])"
                    )
                    and not (t and t.closest and t.closest("[role=combobox]")) {
                    e.preventDefault();
                    stepCard(1 if e.key == "j" or e.key == "J" else -1);
                }
            };
            window.addEventListener("keydown", onKey);
            return lambda {
                window.removeEventListener("resize", onResize);
                window.removeEventListener("keydown", onKey);
                window.removeEventListener("focus", onFocus);
                window.removeEventListener("flowline:refresh", onFocus);
                window.removeEventListener("flowline:open-task", onOpenTask);
                window.removeEventListener("flowline:new-task", onNewTask);
                window.clearInterval(timer);
            };
        },
        []
    );

    # Webhook deliveries queue on the server until the workspace applies
    # them; while the board is open that is this timer, so a merged PR moves
    # its card within a tick rather than on the next visit.
    useEffect(
        lambda {
            timer: any = 0;
            if ghConnected and not loading {
                timer = window.setTimeout(lambda { drainDeliveries(); }, DRAIN_MS);
            }
            return lambda { if timer { window.clearTimeout(timer); }};
        },
        [ghConnected, loading, drainTick]
    );

    # Measure after the lanes lay out, and again whenever what sits above
    # them or how many there are changes.
    useEffect(
        lambda {
            frame: any = window.requestAnimationFrame(lambda { measureLanes(); });
            return lambda { window.cancelAnimationFrame(frame); };
        },
        [
            loading,
            len(steps),
            len(tasks),
            loadFailed,
            workingTruncated,
            hideDone,
            fProject,
            fAssignee,
            fCategory,
            fTag,
            fEstimate,
            fIteration,
            fPriority,
            bool(boardQuery),
            dialogOpen
        ]
    );

    # An open sheet covers the right of the board, so the lanes gain room
    # past their end and the open card scrolls out from under it.
    useEffect(
        lambda {
            frame: any = 0;
            if dialogOpen and editingId and wideView {
                frame = window.requestAnimationFrame(lambda { revealCard(editingId); });
            }
            return lambda { if frame { window.cancelAnimationFrame(frame); }};
        },
        [dialogOpen, editingId, wideView]
    );

    async def boot -> None;
    async def drainDeliveries -> None;
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
    # keepOpen: the save answers "Save and open", so the sheet moves on to
    # what was asked for instead of closing.
    async def saveTask(keepOpen: bool = False) -> None;
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
    # askDetails=False is a move from the task sheet: no handoff dialog (the
    # sheet has those fields, a second form would race its Save), no toast.
    async def moveTo(
        taskId: str,
        columnKey: str,
        anchorId: str = "",
        ahead: bool = False,
        askDetails: bool = True
    ) -> None;
    def sheetMove(columnKey: str) -> None;
    def moveBeside(draggedId: str, targetId: str, ahead: bool) -> None;
    def arrowMove(t: TaskView, columnKey: str) -> None;
    def setProjectFilter(v: str) -> None;
    def setAssigneeFilter(v: str) -> None;
    def setCategoryFilter(v: str) -> None;
    def filtersOn(pid: str, who: str, cat: str) -> bool;
    def clearFilters -> None;
    # Lane geometry: which lanes are on screen, the lane height on md+, and
    # scrolling a lane (or the first one past the edge) into view.
    def measureLanes -> None;
    def scheduleMeasure -> None;
    def scrollToLane(key: str) -> None;
    def scrollToHidden -> None;
    def revealCard(tid: str) -> None;
    # Where an open task sheet starts on screen (md+), else -1: the lanes
    # under it count as out of view.
    def sheetEdge -> float;
    # J/K with the sheet open: the next or previous card in board order.
    def stepCard(delta: int) -> None;
    # A drag near either edge of the lanes scrolls them, so a card can reach
    # a lane that starts off screen.
    def dragEdgeScroll(e: DragEvent) -> None;
    def setField(key: str, value: str) -> None;
    def setMoveField(key: str, value: str) -> None;
    def toggleAssignee(memberId: str) -> None;
    async def saveMoveInfo -> None;
    # Empty inKey lands the task in the first column. openCreate and openEdit
    # ask before replacing unsaved edits; showCreate and showTask replace.
    def openCreate(inKey: str = "") -> None;
    def openEdit(t: TaskView) -> None;
    def showCreate(inKey: str = "") -> None;
    def showTask(t: TaskView) -> None;
    def formDirty -> bool;
    async def resolveSwitch(save: bool) -> None;
    def openSwitchTarget -> None;
    def sheetOpenChange(o: bool) -> None;
    def replaceRow(view: TaskView) -> None;
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

    # Normalised search query, matched against the title and the issue/PR
    # numbers, so typing digits finds "#412" and typing words finds a title.
    bq = boardQuery.strip().lower();

    # One filter predicate for both the working set and the older-Done list,
    # so a new condition is added once. hideDone and the older-list's own
    # showAllDone guard stay at the call sites, since they differ per list.
    todayDay = todayIso();
    currentIterations: list[str] = [];
    for it in iterations {
        if it.start_date <= todayDay and it.end_date >= todayDay {
            currentIterations.append(it.id);
        }
    }

    def matches(t: TaskView) -> bool {
        # The issue/PR number lives in the synced numeric field OR the tail of
        # a hand-pasted link, so search the number wherever it actually is.
        issueTail = t.issue_link.split("/")[-1] if t.issue_link else "";
        prTail = t.pr_link.split("/")[-1] if t.pr_link else "";
        hit = not bq
            or bq in t.title.lower()
            or (t.gh_issue_number > 0 and bq in str(t.gh_issue_number))
            or (t.pr_number > 0 and bq in str(t.pr_number))
            or (bool(issueTail) and bq in issueTail.lower())
            or (bool(prTail) and bq in prTail.lower());
        return hit
            and (fProject == "all" or t.project_id == fProject)
            and (fAssignee == "All" or fAssignee in t.assignee_ids)
            and (fCategory == "All" or t.category == fCategory)
            and (fTag == "All" or fTag in t.tags)
            and (fPriority == "All" or t.priority == fPriority)
            and (
                fIteration == "All"
                or (fIteration == "none" and not t.iteration_id)
                or (fIteration == "current" and t.iteration_id in currentIterations)
                or (bool(t.iteration_id) and t.iteration_id == fIteration)
            )
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
    editingPrState = "";
    # The open card's sub-issue family, resolved from rows already loaded:
    # its children when it is a parent, its parent's card when it is a child.
    famRows: list[TaskView] = [];
    famTotal: int = 0;
    famDone: int = 0;
    famParentId: str = "";
    famParentLabel: str = "";
    editingChecklist: list[dict[str, any]] = [];
    for t in tasks + olderDone {
        if t.id == editingId {
            editingIssueNumber = t.gh_issue_number;
            editingPrState = t.pr_state;
            editingChecklist = t.checklist;
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

    # One pass over the filtered set per lane: its rows, overdue count and
    # colour, shared by the route strip, the lanes and the move menus.
    colLabels: list[str] = [columnLabel(k) for k in colKeys];
    colColors: list[str] = [];
    laneRows: list[list[TaskView]] = [];
    laneCounts: list[int] = [];
    laneOverdue: list[int] = [];
    for key in colKeys {
        stepColor = columnColor(key);
        kind = columnKind(key);
        if stepColor {
            colColors.append(stepColor);
        } else {
            colColors.append(KIND_COLORS[kind] if kind in KIND_COLORS else "slate");
        }
        rows: list[TaskView] = (recentDone + olderShown)
            if key == doneKey
            else [
                t
                for t in visible
                if columnKeyOf(t) == key
            ];
        laneRows.append(rows);
        laneCounts.append(len(rows));
        late = 0;
        if key != doneKey {
            for t in rows {
                if dueTone(t.due_date, t.status, today) == "overdue" {
                    late = late + 1;
                }
            }
        }
        laneOverdue.append(late);
    }
    inView: list[str] = [
        k
        for k in viewKeys.split(",")
        if k
    ];
    shownCount = len(visible) + len(olderShown);
    selectedId = editingId if dialogOpen else "";
    editingCreated = "";
    editingUpdated = "";
    for t in tasks + olderDone {
        if t.id == editingId {
            editingCreated = t.created_at;
            editingUpdated = t.updated_at;
        }
    }
    switchLabel = "";
    if switchTo["kind"] == "task" {
        switchLabel = "“" + switchTo["title"] + "”";
    } elif switchTo["kind"] == "new" {
        switchLabel = "a new task";
    }
    laneGuess = guessLanes();
    laneStyle: dict[str, str] = {};
    if wideView and laneH > 0 {
        laneStyle["height"] = str(laneH) + "px";
    }
    if wideView and dialogOpen and editingId {
        laneStyle["paddingRight"] = "436px";
    }
    if wideView and hiddenAfter > 0 {
        # The right edge fades while lanes sit past it.
        laneStyle["maskImage"] = "linear-gradient(to right, #000 calc(100% - 56px), transparent)";
        laneStyle["WebkitMaskImage"] = "linear-gradient(to right, #000 calc(100% - 56px), transparent)";
    }

    return
        <div className="flex min-w-0 flex-col gap-3">
            <div className="flex min-h-9 flex-wrap items-center gap-3">
                <h1 className="page-title">Board</h1>
                {if not noFlowLine and not nothingLoaded {
                    <div key="actions" className="ml-auto flex items-center gap-2">
                        {if ghConnected {
                            <Button
                                key="sync"
                                variant="outline"
                                disabled={syncing}
                                aria-label={"Sync GitHub" if not syncing else None}
                                title="Sync GitHub"
                                onClick={syncGithub}
                            >
                                {if syncing {
                                    <Spinner key="sp"/>
                                } else {
                                    <svg
                                        key="icon"
                                        width={14}
                                        height={14}
                                        viewBox="0 0 16 16"
                                        aria-hidden="true"
                                    >
                                        <path
                                            d="M13 4.5V2m0 2.5h-2.5M13 4.5A5.5 5.5 0 1 0 13.5 9"
                                            fill="none"
                                            stroke="currentColor"
                                            strokeWidth={1.6}
                                            strokeLinecap="round"
                                            strokeLinejoin="round"
                                        />
                                    </svg>
                                } }
                                <span className="max-sm:hidden">
                                    {(syncNote or "Syncing…")
                                        if syncing
                                        else "Sync GitHub"}
                                </span>
                            </Button>
                        }}
                        <Button
                            aria-label="New task"
                            disabled={loading}
                            onClick={lambda { openCreate(""); }}
                        >
                            <svg
                                width={14}
                                height={14}
                                viewBox="0 0 16 16"
                                aria-hidden="true"
                            >
                                <path
                                    d="M8 3v10M3 8h10"
                                    stroke="currentColor"
                                    strokeWidth={1.8}
                                    strokeLinecap="round"
                                />
                            </svg>
                            New task
                            <span
                                aria-hidden="true"
                                className="ml-0.5 font-mono text-xs max-md:hidden"
                            >
                                N
                            </span>
                        </Button>
                    </div>
                }}
            </div>
            {if workingTruncated and not loading {
                <div
                    key="truncated"
                    className="rounded-md border border-warning/50 bg-card px-3 py-2 text-xs text-warning"
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
                <div
                    key="skeletons"
                    className="flex min-w-0 flex-col gap-3"
                    aria-busy="true"
                >
                    <nav
                        aria-label="Steps"
                        className="hidden min-w-0 items-center gap-3 md:flex"
                    >
                        <div
                            className="flex min-w-0 flex-1 items-center overflow-hidden py-0.5"
                        >
                            {for i in range(laneGuess) {
                                <div
                                    key={"rs" + str(i)}
                                    className="flex shrink-0 items-center"
                                >
                                    {if i > 0 {
                                        <span
                                            key="w"
                                            aria-hidden="true"
                                            className="h-0.5 w-[18px] shrink-0 bg-wire"
                                        />
                                    }}
                                    <Skeleton
                                        className="h-7 rounded-md"
                                        style={{
                                            "width": str(NODE_WIDTHS[i % 7]) + "px"
                                        }}
                                    />
                                </div>
                            }}
                        </div>
                    </nav>
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
                        query={boardQuery}
                        onQuery={lambda (v: str) { boardQuery = v; }}
                        onClear={clearFilters}
                        busy={True}
                    />
                    <div
                        ref={lanesRef}
                        data-board-lanes="true"
                        className={LANE_GRID}
                        style={laneStyle}
                    >
                        {for i in range(laneGuess) {
                            <section
                                key={"sk" + str(i)}
                                data-lane={"sk" + str(i)}
                                className="flex min-w-0 snap-start flex-col rounded-md md:h-full"
                            >
                                <div
                                    className="mx-0.5 flex h-9 shrink-0 items-center gap-1.5 border-b-2 border-border pl-0.5"
                                >
                                    <Skeleton className="size-[13px] rounded-full"/>
                                    <Skeleton
                                        className={"h-3 "
                                            + ("w-24" if i % 2 else "w-16")}
                                    />
                                    <Skeleton className="h-3 w-3"/>
                                </div>
                                <div
                                    className="-mx-1 flex min-h-0 flex-1 flex-col gap-1.5 overflow-hidden px-1.5 pt-2 pb-3"
                                >
                                    {for j in range(2 + (i % 2)) {
                                        <div
                                            key={"c" + str(j)}
                                            className="flex shrink-0 flex-col gap-1 rounded-md border bg-card px-2.5 pt-2 pb-2"
                                        >
                                            <div className="flex h-[18px] items-center">
                                                <Skeleton
                                                    className={"h-3 "
                                                        + CARD_WIDTHS[(i + j) % 4]}
                                                />
                                            </div>
                                            <div
                                                className="flex min-h-6 items-center gap-1.5"
                                            >
                                                <Skeleton className="h-2.5 w-20"/>
                                                <Skeleton
                                                    className="ml-auto size-6 rounded-full"
                                                />
                                            </div>
                                        </div>
                                    }}
                                </div>
                            </section>
                        }}
                    </div>
                </div>
            } elif nothingLoaded {
                <LoadFailed
                    key="failed"
                    title="Could not load the board"
                    onRetry={retryLoad}
                    retrying={retrying}
                />
            } elif noFlowLine {
                <div key="noflowline" className="flex min-w-0 flex-col gap-6 pt-2">
                    <div className="flex max-w-lg flex-col items-start gap-3">
                        <h2 className="section-title text-lg">
                            Your board follows your flow line
                        </h2>
                        <p className="text-sm text-muted-foreground">
                            Each column here is a step your team moves work through, in the order you draw them. Start from a template, or draw the steps yourself.
                        </p>
                        <div className="flex flex-wrap items-center gap-2 pt-1">
                            <Button
                                onClick={lambda { window.location.href = "/flowlines"; }}
                            >
                                Pick a template
                            </Button>
                            <Button
                                variant="ghost"
                                onClick={lambda { window.location.href = "/flowlines"; }}
                            >
                                Draw the steps yourself
                            </Button>
                        </div>
                    </div>
                    <div
                        aria-hidden="true"
                        className="grid grid-cols-2 gap-2.5 md:grid-cols-[repeat(4,minmax(0,252px))]"
                    >
                        {for i in [0, 1, 2, 3] {
                            <div
                                key={"ghost" + str(i)}
                                className={"flex flex-col gap-1.5"
                                    + (" max-md:hidden" if i > 1 else "")}
                            >
                                <div
                                    className="flex h-9 items-center border-b-2 border-border px-0.5"
                                >
                                    <span className="h-2.5 w-20 rounded-xs bg-muted"/>
                                </div>
                                {for j in range(3 - (i % 2)) {
                                    <div
                                        key={"g" + str(i) + "-" + str(j)}
                                        className="flex h-[62px] flex-col justify-center gap-2 rounded-md border border-border bg-card/60 px-2.5"
                                    >
                                        <span
                                            className="h-2.5 w-4/5 rounded-xs bg-muted"
                                        />
                                        <span
                                            className="h-2 w-1/2 rounded-xs bg-muted"
                                        />
                                    </div>
                                }}
                            </div>
                        }}
                    </div>
                </div>
            } else {
                <div
                    key="board"
                    className="flex min-w-0 flex-col gap-3 animate-in fade-in duration-150"
                >
                    <div className="hidden md:block">
                        <RouteStrip
                            keys={colKeys}
                            labels={colLabels}
                            colors={colColors}
                            counts={laneCounts}
                            inView={inView}
                            active={activeLane}
                            hiddenAfter={hiddenAfter}
                            onPick={scrollToLane}
                            onMore={scrollToHidden}
                        />
                    </div>
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
                        iterations={iterations}
                        iteration={fIteration}
                        onIteration={lambda (v: str) { fIteration = v; }}
                        priority={fPriority}
                        onPriority={lambda (v: str) { fPriority = v; }}
                        query={boardQuery}
                        onQuery={lambda (v: str) { boardQuery = v; }}
                        onClear={clearFilters}
                        shownCount={shownCount}
                    />
                    <div className="md:hidden">
                        <RouteStrip
                            tabs={True}
                            keys={colKeys}
                            labels={colLabels}
                            colors={colColors}
                            counts={laneCounts}
                            inView={inView}
                            active={activeLane}
                            hiddenAfter={0}
                            onPick={scrollToLane}
                            onMore={scrollToHidden}
                        />
                    </div>
                    <div
                        ref={lanesRef}
                        data-board-lanes="true"
                        onScroll={lambda { scheduleMeasure(); }}
                        onDragOverCapture={lambda (e: DragEvent) { dragEdgeScroll(e); }}
                        className={LANE_GRID}
                        style={laneStyle}
                    >
                        {for (ci, key) in enumerate(colKeys) {
                            <KanbanColumn
                                key={key}
                                columnKey={key}
                                label={colLabels[ci]}
                                kind={columnKind(key)}
                                color={columnColor(key)}
                                tasks={laneRows[ci]}
                                onOpen={openEdit}
                                onArrowMove={arrowMove}
                                onDropTask={moveTo}
                                onDropBeside={moveBeside}
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
                                overdueCount={laneOverdue[ci]}
                                keys={colKeys}
                                labels={colLabels}
                                colors={colColors}
                                steps={steps}
                                selectedId={selectedId}
                                doneHidden={hideDone and key == doneKey}
                            />
                        }}
                    </div>
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
                onOpenChange={sheetOpenChange}
                onSave={saveTask}
                onDelete={deleteTask}
                categories={allCategories}
                columnKeys={colKeys}
                columnLabels={colLabels}
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
                iterations={iterations}
                onOpenTask={openTaskById}
                taskId={editingId}
                checklist={editingChecklist}
                onChecklist={replaceRow}
                onMove={sheetMove}
                createdAt={editingCreated}
                historyKey={editingUpdated}
                prState={editingPrState}
                beside={True}
                topAnchor="[data-board-toolbar]"
                switchLabel={switchLabel}
                onSwitch={resolveSwitch}
                onStay={lambda { switchTo = NO_SWITCH; }}
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
                taskId={moveTaskId}
            />
        </div>;
}
