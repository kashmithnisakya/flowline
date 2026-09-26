"""flowline - Board page (/board): one project's work as the flow line's
steps, stacked. The groups ARE the flow line steps in designed order, so the
board and the Flow line page cannot disagree; with no flow line yet it falls
back to the six statuses. Stateful shell: data and handlers here; header,
strip, toolbar, groups and sheet are presentational."""

import from "@jac/runtime" { jacIsLoggedIn }
import from ...models {
    Project,
    MemberView,
    TaskRow,
    TaskView,
    StepView,
    RepoView,
    RoleView,
    FilterSetView
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
import from ...services.filters.filters { SetBoardFilters }
import from ...components.board.FilterBar { FilterBar }
import from ...components.common.FilterSets { FilterSetMenu }
import from ...components.board.BoardHeader { BoardHeader }
import from ...components.board.FlowStrip { FlowStrip }
import from ...components.board.StepGroup { StepGroup }
import from ...components.board.OlderDone { OlderDone }
import from ...components.board.ColumnHeads { ColumnHeads }
import from ...components.board.FilteredEmpty { FilteredEmpty }
import from ...components.board.BoardSkeleton { BoardSkeleton, rememberGroups }
import from ...components.board.NoFlowLine { NoFlowLine }
import from ...components.board.TaskDialog { TaskDialog }
import from ...components.board.MoveDialog { MoveDialog }
import from ...components.ui.button { Button }
import from ...components.common.Reveal { Reveal }
import from ...lib.project { currentProject, pickProject }
import from ...lib.workspace { rememberWorkspace, forgetWorkspace }
import from "sonner" { toast }
import from "react" { useEffect }
import from ...components.common.LoadFailed { LoadFailed, StaleDataStrip }
import from ...lib.dates { todayIso, dueTone }
import from ...lib.utils { fmtEstimate, parseEstimate }
import from ...lib.filters {
    defaultProject,
    filterKey,
    filterValue,
    trimFilters,
    readBoardFilters,
    keepBoardFilters
}
import from ...components.flowlines.kinds { DOT_FILL, colorKey, moveRefusal }

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
         "notes",
         "issue",
         "pr",
         "reviewer",
         "review_due"
     ],
     # What the page was asked to open while the sheet held unsaved edits:
     # kind "task" (id, title) or "new" (lane key); kind "" is nothing.
     NO_SWITCH: dict[str, str] = {"kind": "", "id": "", "key": "", "title": ""};

# The GitHub poll runs on the server's schedule, never on a board open; the
# Sync button drives this many increments by hand.
glob SYNC_ROUNDS: int = 40,
     # The task poll, and the age past which a tab return refetches: a
     # snapshot younger than one poll is what the poll would return.
     POLL_MS: int = 60000,
     # How often an open board applies queued webhook deliveries while they
     # are live (one keyed store read per tick, no GitHub call); a quiet
     # connection drains once per task poll instead.
     DRAIN_MS: int = 20000,
     # A filter change reaches the account once the picking pauses this long.
     SAVE_FILTERS_MS: int = 800;


def:pub BoardPage -> JsxPage {
    has showAllDone: bool = False,
        # The working set: open tasks plus Done touched in the last week,
        # which is everything the board renders until "completed earlier"
        # is opened. Older Done history pages in on demand below.
        tasks: list[TaskRow] = [],
        olderDone: list[TaskRow] = [],
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
        # The flow line's name, over the strip.
        flowName: str = "Flow line",
        repos: list[RepoView] = [],
        ghConnected: bool = False,
        # A delivery reached the server inside its live window (the snapshot
        # says; a drain that lands rows says so too), so the queue is
        # polled every DRAIN_MS instead of once per task poll.
        webhookLive: bool = False,
        # Bumped after each drain so the effect below re-arms its timer with
        # the current state (a setInterval closure would keep the first one).
        drainTick: int = 0,
        # When the last good snapshot landed (ms), for the focus gate.
        snapshotRef: Ref[any] = Ref(),
        syncing: bool = False,
        syncNote: str = "",
        loading: bool = True,
        movesRef: Ref[any] = Ref(),
        # The newest snapshot load owns the state: an older one still paging
        # neither paints its pages nor fetches the rest.
        loadReqRef: Ref[any] = Ref(),
        # The project on screen, the scope every page shares (lib/project).
        # "" only until page 1 says which one the server opened on.
        fProject: str = currentProject(),
        # The project the loaded rows belong to. While it differs from
        # fProject a switch is in flight, and the rows on screen stay
        # rather than blanking until the new set lands.
        loadedProject: str = "",
        fAssignee: str = "All",
        fCategory: str = "All",
        # A tag the card must carry, or "All"; the estimate filter is "All",
        # "yes" (estimated) or "no" (unestimated). Client-side, like the rest.
        fTag: str = "All",
        fEstimate: str = "All",
        fPriority: str = "All",
        # The account's saved sets, the one the filters came from ("" none),
        # its name as this browser last saw it (the first frame's label), and
        # whether the account's filters have been taken: every change after
        # that is saved, compared as filterKey + "|" + set on savedRef.
        filterSets: list[FilterSetView] = [],
        activeSet: str = "",
        lastSetName: str = "",
        filtersReady: bool = False,
        savedRef: Ref[any] = Ref(),
        # Live search over the loaded board: matches a task title or its
        # issue/PR number, so one box covers "payment" and "412".
        boardQuery: str = "",
        hideEmpty: bool = False,
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
        # Step groups folded shut (column keys); Done starts folded.
        closed: list[str] = [],
        doneOpen: bool = False;

    async can with entry {
        movesRef.current = 0;
        # The first frame shows the filters this browser last saw; the
        # account's own replace them when page 1 lands.
        kept = readBoardFilters();
        if kept["ok"] {
            adoptFilters(kept["filters"], kept["set"]);
            lastSetName = kept["name"];
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

    # Live-ish board: a POLL_MS poll, and a refetch on tab focus only when
    # the snapshot on screen is older than one poll, both through
    # refreshTasks -- one walker call, no roster refetch. One manual
    # useEffect so the listener/interval handles are visible to the cleanup
    # (entry/exit abilities compile to separate closures).
    useEffect(
        lambda {
            onFocus = lambda {
                d = new(Date);
                age: float = (d.getTime() as float) - (snapshotRef.current or 0.0);
                if age >= POLL_MS {
                    refreshTasks();
                }
            };
            onRefresh = lambda { refreshTasks(); };
            window.addEventListener("focus", onFocus);
            # The assistant dock lives in the layout, not in this tree, so an
            # applied proposal announces itself with an event rather than leaving
            # the new card invisible until the next poll.
            window.addEventListener("flowline:refresh", onRefresh);
            # The command palette, mounted in the layout, asks an already
            # mounted board to open a card or the new-task dialog.
            onOpenTask = lambda (e: any) { pendingTaskId = str(e.detail or ""); };
            onNewTask = lambda { pendingTaskId = "new"; };
            window.addEventListener("flowline:open-task", onOpenTask);
            window.addEventListener("flowline:new-task", onNewTask);
            timer = window.setInterval(lambda { pollTick(); }, POLL_MS);
            # The sidebar (or another page's picker) scopes the board.
            onProject = lambda (e: any) { setProjectFilter(str(e.detail or "")); };
            window.addEventListener("flowline:project", onProject);
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
                # A change still inside its pause is saved on the way out.
                persistFilters();
                window.removeEventListener("flowline:project", onProject);
                window.removeEventListener("keydown", onKey);
                window.removeEventListener("focus", onFocus);
                window.removeEventListener("flowline:refresh", onRefresh);
                window.removeEventListener("flowline:open-task", onOpenTask);
                window.removeEventListener("flowline:new-task", onNewTask);
                window.clearInterval(timer);
            };
        },
        []
    );

    # Webhook deliveries queue on the server until the workspace applies
    # them; while they are live and the board is open that is this timer,
    # so a merged PR moves its card within a tick rather than on the next
    # visit. A quiet connection is drained by the task poll instead.
    useEffect(
        lambda {
            timer: any = 0;
            if ghConnected and webhookLive and not loading {
                timer = window.setTimeout(lambda { drainDeliveries(True); }, DRAIN_MS);
            }
            return lambda { if timer { window.clearTimeout(timer); }};
        },
        [ghConnected, webhookLive, loading, drainTick]
    );

    # Every filter change after the account's filters were taken reaches
    # the account, once the picking pauses.
    useEffect(
        lambda {
            timer: any = 0;
            if filtersReady {
                timer = window.setTimeout(
                    lambda { persistFilters(); }, SAVE_FILTERS_MS
                );
            }
            return lambda { if timer { window.clearTimeout(timer); }};
        },
        [
            filtersReady,
            activeSet,
            fAssignee,
            fCategory,
            fTag,
            fEstimate,
            fPriority,
            hideDone
        ]
    );

    async def boot -> None;
    async def drainDeliveries(refresh: bool) -> None;
    async def pollTick -> None;
    # loadAll refreshes everything (boot, and every write that can touch the
    # roster); refreshTasks is the poll's path and skips the workspace lists,
    # which are edited on other pages. Both run through loadBoard.
    async def loadAll -> None;
    async def reloadAll -> None;
    async def refreshTasks -> None;
    async def loadBoard(withWorkspace: bool) -> dict[str, any];
    def absorbWorkspace(data: any) -> None;
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
    def columnKeyOf(t: TaskRow) -> str;
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
    def arrowMove(t: TaskRow, columnKey: str) -> None;
    def setProjectFilter(v: str) -> None;
    def setAssigneeFilter(v: str) -> None;
    def setCategoryFilter(v: str) -> None;
    def filtersOn(who: str, cat: str) -> bool;
    def clearFilters -> None;
    # The saved filters: the filters on screen in their stored form, taking
    # a stored dict (a set, the account's, this browser's copy), dropping
    # values that name a row gone from the lists, and saving to the account.
    def boardFilters -> dict[str, str];
    def adoptFilters(filters: dict[str, str], setId: str) -> None;
    def takeAccountFilters(data: any) -> None;
    def dropStaleFilters -> None;
    async def persistFilters -> None;
    def applySet(view: FilterSetView) -> None;
    def showAllTasks -> None;
    def absorbSet(view: FilterSetView) -> None;
    def dropSet(setId: str) -> None;
    # J/K with the sheet open: the next or previous card in board order.
    def stepCard(delta: int) -> None;
    def setField(key: str, value: str) -> None;
    def setMoveField(key: str, value: str) -> None;
    def toggleAssignee(memberId: str) -> None;
    async def saveMoveInfo -> None;
    # Empty inKey lands the task in the first column. openCreate and openEdit
    # ask before replacing unsaved edits; showCreate and showTask replace.
    def openCreate(inKey: str = "") -> None;
    def openEdit(t: TaskRow) -> None;
    def showCreate(inKey: str = "") -> None;
    def showTask(t: TaskRow) -> None;
    def formDirty -> bool;
    async def resolveSwitch(save: bool) -> None;
    def openSwitchTarget -> None;
    def sheetOpenChange(o: bool) -> None;
    def replaceRow(view: TaskView) -> None;
    def absorbDetails(view: TaskView) -> None;
    async def syncGithub -> None;
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

    # The filters on screen as a saved set stores them, and the board's sets.
    nowFilters = boardFilters();
    boardSets: list[FilterSetView] = [
        s
        for s in filterSets
        if s.page == "board"
    ];

    # One filter predicate for both the working set and the older-Done list,
    # so a new condition is added once. hideDone and the older-list's own
    # showAllDone guard stay at the call sites, since they differ per list.

    def matches(t: TaskRow) -> bool {
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
            and (not fProject or loadedProject != fProject or t.project_id == fProject)
            and (fAssignee == "All" or fAssignee in t.assignee_ids)
            and (fCategory == "All" or t.category == fCategory)
            and (fTag == "All" or fTag in t.tags)
            and (fPriority == "All" or t.priority == fPriority)
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
    famRows: list[TaskRow] = [];
    famTotal: int = 0;
    famDone: int = 0;
    famParentId: str = "";
    famParentLabel: str = "";
    for t in tasks + olderDone {
        if t.id == editingId {
            editingIssueNumber = t.gh_issue_number;
            editingPrState = t.pr_state;
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

    # One pass over the filtered set per step: its rows, overdue count and
    # colour, shared by the strip, the groups and the move menus.
    colLabels: list[str] = [columnLabel(k) for k in colKeys];
    colColors: list[str] = [];
    groupRows: list[list[TaskRow]] = [];
    groupCounts: list[int] = [];
    groupOverdue: list[int] = [];
    for key in colKeys {
        kind = columnKind(key);
        colColors.append(
            columnColor(key) or (KIND_COLORS[kind] if kind in KIND_COLORS else "slate")
        );
        rows: list[TaskRow] = (recentDone + olderShown)
            if key == doneKey
            else [
                t
                for t in visible
                if columnKeyOf(t) == key
            ];
        groupRows.append(rows);
        groupCounts.append(len(rows));
        late = 0;
        if key != doneKey {
            for t in rows {
                if dueTone(t.due_date, t.status, today) == "overdue" {
                    late = late + 1;
                }
            }
        }
        groupOverdue.append(late);
    }
    route: dict[str, any] = {
        "keys": colKeys,
        "labels": colLabels,
        "colors": colColors,
        "steps": steps
    };
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
    openCount = len(
        [
            t
            for t in tasks
            if t.status != "Done"
        ]
    );
    blockedCount = len(
        [
            t
            for t in tasks
            if t.status == "Blocked"
        ]
    );
    anyFilter = (
        fAssignee != "All"
        or fPriority != "All"
        or fCategory != "All"
        or fTag != "All"
        or fEstimate != "All"
        or bool(boardQuery.strip())
    );
    hiddenByFilters = len(tasks) - len(visible);
    headerCounts: list[list[str]] = [
        [str(openCount), "open", ""],
        [str(blockedCount), "blocked", "alarm" if blockedCount > 0 else ""],
        [str(len(recentDone)), "done in the last 7 days", ""]
    ];
    if anyFilter and hiddenByFilters > 0 {
        headerCounts.append([str(hiddenByFilters), "hidden by filters", ""]);
    }

    def expandAll {
        closed = [];
        doneOpen = True;
    }

    def collapseAll {
        closed = [
            k
            for k in colKeys
            if k != doneKey
        ];
        doneOpen = False;
    }

    def isOpen(key: str) -> bool {
        return doneOpen if key == doneKey else key not in closed;
    }

    def toggleGroup(key: str) {
        if key == doneKey {
            doneOpen = not doneOpen;
        } elif key in closed {
            closed = [
                k
                for k in closed
                if k != key
            ];
        } else {
            closed = closed + [key];
        }
    }

    allOpen = len(
        [
            k
            for k in colKeys
            if not isOpen(k)
        ]
    )
        == 0;

    def toggleAll {
        doneOpen = not allOpen;
        closed = []
            if not allOpen
            else [
                k
                for k in colKeys
                if k != doneKey
            ];
    }

    return
        <div className="flex min-w-0 flex-col gap-6">
            <BoardHeader
                projects={activeProjects}
                project={fProject}
                counts={headerCounts}
                ghConnected={ghConnected}
                syncing={syncing}
                syncNote={syncNote}
                busy={loading}
                onSync={syncGithub}
                onNew={lambda { openCreate(""); }}
            />
            {if workingTruncated and not loading {
                <div
                    key="truncated"
                    className="rounded-xl bg-warning/10 px-3 py-2 text-xs text-warning"
                    role="status"
                >
                    More open work than the board loads at once, so some tasks are missing. Narrow the filters, or archive what is finished.
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
            <Reveal ready={not loading} frame={<BoardSkeleton/>} className="min-w-0">
                {if nothingLoaded {
                    <LoadFailed
                        key="failed"
                        title="Could not load the board"
                        onRetry={retryLoad}
                        retrying={retrying}
                    />
                } elif noFlowLine {
                    <NoFlowLine key="noflowline"/>
                } else {
                    <div key="board" className="flex min-w-0 flex-col gap-5">
                        <FlowStrip
                            name={flowName}
                            keys={colKeys}
                            labels={colLabels}
                            colors={colColors}
                            counts={groupCounts}
                        />
                        <div
                            data-board-toolbar="true"
                            className="flex flex-wrap items-center gap-2"
                        >
                            <FilterBar
                                members={activeMembers}
                                project={fProject}
                                assignee={fAssignee}
                                category={fCategory}
                                hideDone={hideDone}
                                onAssignee={setAssigneeFilter}
                                onCategory={setCategoryFilter}
                                onHideDone={lambda { hideDone = not hideDone; }}
                                categories={allCategories}
                                tags={allTags}
                                tag={fTag}
                                estimate={fEstimate}
                                onTag={lambda (v: str) { fTag = v; }}
                                onEstimate={lambda (v: str) { fEstimate = v; }}
                                priority={fPriority}
                                onPriority={lambda (v: str) { fPriority = v; }}
                                query={boardQuery}
                                onQuery={lambda (v: str) { boardQuery = v; }}
                                onClear={clearFilters}
                                shownCount={shownCount}
                                hideEmpty={hideEmpty}
                                onHideEmpty={lambda { hideEmpty = not hideEmpty; }}
                                onExpandAll={expandAll}
                                onCollapseAll={collapseAll}
                            />
                            <FilterSetMenu
                                sets={boardSets}
                                activeId={activeSet}
                                filters={nowFilters}
                                members={members}
                                onApply={applySet}
                                onAll={showAllTasks}
                                onSaved={absorbSet}
                                onDeleted={dropSet}
                                lastName={lastSetName}
                            />
                            <Button
                                variant="ghost"
                                className="rounded-full text-muted-foreground"
                                onClick={toggleAll}
                            >
                                {"Collapse all" if allOpen else "Expand all"}
                            </Button>
                        </div>
                        {if anyFilter and shownCount == 0 {
                            <FilteredEmpty
                                key="none"
                                hidden={hiddenByFilters}
                                onClear={clearFilters}
                            />
                        }}
                        {if not (anyFilter and shownCount == 0) {
                            <ColumnHeads key="heads"/>
                        }}
                        <div className="flex flex-col gap-2">
                            {for (ci, key) in enumerate(colKeys) {
                                <>
                                    {if (not hideEmpty)
                                        or groupCounts[ci] > 0
                                        or key == doneKey {
                                        <StepGroup
                                            key={key}
                                            columnKey={key}
                                            label={colLabels[ci]}
                                            kind={columnKind(key)}
                                            color={colColors[ci]}
                                            dot={DOT_FILL[colorKey(colColors[ci])]}
                                            tasks={groupRows[ci]}
                                            open={isOpen(key)}
                                            overdue={groupOverdue[ci]}
                                            today={today}
                                            selectedId={selectedId}
                                            doneKey={doneKey}
                                            route={route}
                                            onToggle={lambda { toggleGroup(key); }}
                                            onOpen={openEdit}
                                            onMove={arrowMove}
                                            onDropTask={moveTo}
                                            onDropBeside={moveBeside}
                                            onAdd={openCreate
                                                if key != doneKey
                                                else None}
                                            empty={"Done tasks are hidden"
                                                if hideDone and key == doneKey
                                                else "No tasks here"}
                                            footer={<OlderDone
                                                total={olderTotal
                                                    if not hideDone
                                                    else 0}
                                                showing={showAllDone and not hideDone}
                                                shown={len(olderShown)}
                                                more={olderMore}
                                                loading={loadingOlder}
                                                onToggle={toggleOlder}
                                                onMore={lambda { loadOlder(
                                                    olderPage + 1,
                                                    fProject,
                                                    fAssignee,
                                                    fCategory
                                                ); }}
                                            />
                                                if key == doneKey
                                                else None}
                                        />
                                    }}
                                </>
                            }}
                        </div>
                    </div>
                }  }
            </Reveal>
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
                onOpenTask={openTaskById}
                taskId={editingId}
                onLoaded={absorbDetails}
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
