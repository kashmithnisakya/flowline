"""The task sheet: a right-side Radix dialog (full screen below sm) with the
route breadcrumb, title, properties, notes, checklist and travel so far. The
page owns the form dict and UpdateTask overwrites every field, so every
property here goes out on Save. Modal unless the page opts into `beside`."""

import from "react" { useEffect }
import from ...models {
    Project,
    MemberView,
    RepoView,
    StepView,
    RoleView,
    TaskRow,
    TaskView,
    IterationView
}
import from ...services.tasks.tasks { GetTask }
import from ..common.Markdown { Markdown }
import from ..common.StepName { StepName }
import from ..common.Avatar { AvatarStack }
import from .Checklist { ChecklistEditor }
import from .MoveMenu { MoveMenu, routeFrom }
import from .TravelLog { TravelLog }
import from ..log.DatePicker { DatePicker }
import from ..ui.button { Button }
import from ..ui.sheet { Sheet, SheetContent, SheetTitle, SheetDescription }
import from ..ui.input { Input }
import from ..ui.textarea { Textarea }
import from ..ui.skeleton { Skeleton }
import from ..ui.select {
    Select,
    SelectTrigger,
    SelectValue,
    SelectContent,
    SelectItem
}
import from ..ui.dropdown_menu {
    DropdownMenu,
    DropdownMenuTrigger,
    DropdownMenuContent,
    DropdownMenuLabel,
    DropdownMenuSeparator,
    DropdownMenuCheckboxItem
}
import from ..common.glyphs { Spinner }
import from ...lib.dates { prettyDay }

glob PRIORITIES: list[str] = ["High", "Medium", "Low"],
     # A legacy status column's colour, by the kind its status maps to.
     LEGACY_COLOR: dict[str, str] = {
         "Backlog": "sky",
         "In Progress": "indigo",
         "Review": "amber",
         "Changes Requested": "indigo",
         "Done": "emerald",
         "Blocked": "rose"
     },
     # Property values read as text until hovered: ghost triggers and fields.
     GHOST_SELECT: str = "h-8 w-full min-w-0 justify-between border-transparent bg-transparent px-2 font-normal shadow-none hover:bg-accent data-[state=open]:bg-accent [&>svg:last-child]:opacity-0 hover:[&>svg:last-child]:opacity-100 data-[state=open]:[&>svg:last-child]:opacity-100",
     GHOST_INPUT: str = "h-8 border-transparent bg-transparent px-2 hover:border-border md:text-[13px] text-[13px] [&::-webkit-calendar-picker-indicator]:opacity-0 hover:[&::-webkit-calendar-picker-indicator]:opacity-100 focus:[&::-webkit-calendar-picker-indicator]:opacity-100",
     # Targets whose letter keys belong to a select or menu, not the sheet.
     WIDGET_ROLES: str = "[role=combobox], [role=listbox], [role=menu], [role=option], [role=menuitem], [role=menuitemcheckbox], [role=menuitemradio], [data-slot=select-trigger]",
     GHOST_DATE: str = "h-8! w-full justify-start border-transparent! bg-transparent! px-2! text-[13px]! font-normal! hover:bg-accent!";

# One label/value row of the property list.
def PropRow(label: str, children: any = None, top: bool = False) -> JsxElement {
    return
        <div
            className={"grid min-h-8 grid-cols-[6rem_minmax(0,1fr)] gap-x-2 "
                + ("items-start" if top else "items-center")}
        >
            <dt
                className={"text-[13px] text-muted-foreground "
                    + ("pt-1.5" if top else "")}
            >
                {label}
            </dt>
            <dd className="m-0 min-w-0">{children}</dd>
        </div>;
}

def OpenLink(url: str) -> JsxElement {
    return
        <a
            href={url}
            target="_blank"
            rel="noopener"
            title="Open in a new tab"
            aria-label="Open the link in a new tab"
            className="inline-flex size-8 shrink-0 items-center justify-center rounded-md text-muted-foreground hover:bg-accent hover:text-foreground"
        >
            <svg
                width={14}
                height={14}
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth={2}
                strokeLinecap="round"
                strokeLinejoin="round"
                aria-hidden="true"
            >
                <path d="M15 3h6v6"/>
                <path d="M10 14 21 3"/>
                <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>
            </svg>
        </a>;
}

def Arrow -> JsxElement {
    return
        <svg
            width={14}
            height={14}
            viewBox="0 0 16 16"
            aria-hidden="true"
            className="shrink-0 text-wire"
        >
            <path
                d="M3 8h9.5M9 4.5 12.5 8 9 11.5"
                fill="none"
                stroke="currentColor"
                strokeWidth={1.6}
                strokeLinecap="round"
                strokeLinejoin="round"
            />
        </svg>;
}

def Flag -> JsxElement {
    return
        <svg
            width={12}
            height={12}
            viewBox="0 0 16 16"
            aria-hidden="true"
            className="shrink-0"
        >
            <path
                d="M4 14V2.5M4 3h8l-1.8 3L12 9H4"
                fill="none"
                stroke="currentColor"
                strokeWidth={1.6}
                strokeLinejoin="round"
                strokeLinecap="round"
            />
        </svg>;
}

# A family row's column label: the child's step (or legacy status) mapped
# through the board's own key/label lists, so it says what the column says.
def familyStepLabel(kid: TaskRow, keys: list[str], labels: list[str]) -> str {
    for (i, k) in enumerate(keys) {
        if (k == kid.step_id or k == kid.status) and i < len(labels) {
            return labels[i];
        }
    }
    return kid.status;
}

def:pub TaskDialog(
    open: bool,
    editing: bool,
    form: dict[str, str],
    projects: list[Project],
    members: list[MemberView],
    saving: bool,
    onField: Callable[[str, str], None],
    onOpenChange: Callable[[bool], None],
    onSave: Callable[[], None],
    onDelete: Callable[[], None],
    categories: list[str] = [],
    # The board's columns, as parallel key/label lists: a column is a
    # flow line step (keyed by its jid) or a legacy status (keyed by itself),
    # so the sheet always offers exactly what the board shows.
    columnKeys: list[str] = [],
    columnLabels: list[str] = [],
    handoffKeys: list[str] = [],
    assignees: list[str] = [],
    onToggleAssignee: Callable[[str], None] = None,
    repos: list[RepoView] = [],
    ghConnected: bool = False,
    ghIssueNumber: int = 0,
    onCreateIssue: Callable[[str], None] = None,
    # The flow line: step colours, transitions for the Move menu and the
    # breadcrumb, and the lanes picture at the foot of the sheet.
    steps: list[StepView] = [],
    roles: list[RoleView] = [],
    # Sub-issue family of the open card, resolved by the caller from rows it
    # already holds. onOpenTask jumps the sheet to another card of the family.
    family: list[TaskRow] = [],
    familyTotal: int = 0,
    familyDone: int = 0,
    parentTaskId: str = "",
    parentLabel: str = "",
    onOpenTask: Callable[[str], None] = None,
    # The open task's id; without one the checklist and history stay hidden.
    # The sheet loads the task's notes and checklist itself (GetTask, a list
    # row carries neither) and hands the view to `onLoaded`, which seeds the
    # page's form notes. Checklist edits write at once, not on Save, and each
    # reports the task view to `onChecklist` so the page's row keeps count.
    taskId: str = "",
    onLoaded: Callable[[TaskView], None] = None,
    onChecklist: Callable[[TaskView], None] = None,
    # The workspace's iterations; the form's "iteration" is a jid or "none".
    iterations: list[IterationView] = [],
    # Move now (the board): the sheet's Move menu calls this with a column
    # key. Without it a pick only sets the Step field, applied on Save.
    onMove: Callable[[str], None] = None,
    # The task's created_at, the start of its travel history, and a key that
    # changes when the task does (its updated_at) so the history refreshes.
    createdAt: str = "",
    historyKey: str = "",
    # The linked pull request's GitHub state (open, draft, merged, closed).
    prState: str = "",
    # Beside the page (md+): no scrim, the page stays usable. Only for a page
    # that guards unsaved edits through switchLabel; topAnchor names the
    # element whose bottom edge the sheet starts at.
    beside: bool = False,
    topAnchor: str = "",
    # The page wants to open something else over unsaved edits: the footer
    # asks, onSwitch(True) saves first, onSwitch(False) discards, onStay keeps.
    switchLabel: str = "",
    onSwitch: Callable[[bool], None] = None,
    onStay: Callable[[], None] = None
) -> JsxElement {
    # Which repo a new issue goes in when the project tracks several. Notes
    # open rendered once written; pendingAction marks which button started
    # the shared `saving` flight. topPx and rightPx fit the sheet between the
    # app header and the right edge of <main>, so a docked column stays clear.
    # `checklist` and `detailsFor` (the task whose notes and checklist are
    # loaded, "" while GetTask is out) are the sheet's own; `failedFor` is the
    # task whose load failed, and `loadRef` drops a late answer for a task
    # the sheet has since left.
    has repoChoice: str = "",
        notesEditing: bool = False,
        pendingAction: str = "",
        moveOpen: bool = False,
        topPx: int = 0,
        rightPx: int = 0,
        viewW: int = 0,
        checklist: list[dict[str, any]] = [],
        detailsFor: str = "",
        failedFor: str = "",
        loadRef: Ref[any] = Ref();

    # The open task's notes and checklist, one GetTask.
    async def loadDetails(tid: str) {
        loadRef.current = tid;
        view: any = None;
        try {
            result = root spawn GetTask(task_id=tid);
            view = result.reports[0] if result.reports else None;
        } except Exception as e {
            view = None;
        }
        if loadRef.current != tid {
            return;
        }
        if not view {
            failedFor = tid;
            return;
        }
        checklist = view.checklist;
        if onLoaded {
            onLoaded(view);
        }
        detailsFor = tid;
    }

    # A checklist write reports the task's fresh view: the items stay here,
    # the view goes up so the page's row shows the new counts.
    def absorbChecklist(view: TaskView) {
        checklist = view.checklist;
        if onChecklist {
            onChecklist(view);
        }
    }

    def placeSheet {
        w: any = window;
        header: any = document.querySelector("header");
        main: any = document.querySelector("main");
        anchor: any = document.querySelector(topAnchor)
            if beside and topAnchor
            else None;
        wide = int(w.innerWidth);
        bottom = 0;
        inset = 0;
        if wide >= 640 {
            if header {
                bottom = int(header.getBoundingClientRect().bottom);
            }
            if anchor and wide >= 768 and anchor.offsetParent {
                below = int(anchor.getBoundingClientRect().bottom);
                bottom = below if below > bottom else bottom;
            }
            if main {
                inset = int(
                    document.documentElement.clientWidth
                        - main.getBoundingClientRect().right
                );
            }
        }
        top = bottom if bottom > 0 else 0;
        right = inset if inset > 0 else 0;
        if top != topPx {
            topPx = top;
        }
        if right != rightPx {
            rightPx = right;
        }
        if wide != viewW {
            viewW = wide;
        }
    }

    useEffect(
        lambda {
            onResize: any = lambda { placeSheet(); };
            if open {
                window.addEventListener("resize", onResize);
                window.addEventListener("scroll", onResize);
            }
            return lambda {
                window.removeEventListener("resize", onResize);
                window.removeEventListener("scroll", onResize);
            };
        },
        [open]
    );

    # The anchor moves when the page above it reflows (a filter chip wraps
    # the toolbar), so every render re-reads it; writes only on a change.
    useEffect(lambda { if open { placeSheet(); }});

    # The unsaved-changes question takes focus so a key or a click on a card
    # is answered where it was asked; once answered, focus returns to the sheet.
    useEffect(
        lambda {
            timer: any = 0;
            if open {
                timer = window.setTimeout(
                    lambda {
                        active: any = document.activeElement;
                        box: any = document.querySelector("[data-task-sheet]");
                        if switchLabel {
                            btn: any = document.querySelector(
                                "[data-switch-save]:not(:disabled)"
                            )
                                or document.querySelector("[data-switch-stay]");
                            if btn {
                                btn.focus({"preventScroll": True});
                            }
                        } elif box and (not active or active == document.body) {
                            box.focus({"preventScroll": True});
                        }
                    },
                    30
                );
            }
            return lambda { if timer { window.clearTimeout(timer); }};
        },
        [switchLabel]
    );

    async can with (open, taskId, editing) entry {
        notesEditing = False;
        moveOpen = False;
        checklist = [];
        detailsFor = "";
        failedFor = "";
        loadRef.current = "";
        if open {
            w: any = window;
            placeSheet();
            if not editing {
                w.setTimeout(
                    lambda {
                        field: any = document.querySelector("[data-task-title]");
                        if field {
                            field.focus();
                        }
                    },
                    30
                );
            }
            if editing and taskId {
                await loadDetails(taskId);
            }
        }
    }

    hasNotes = bool(form["notes"] and form["notes"].strip());
    selectedProject = form["project"];
    hasProject = bool(selectedProject);
    inProject = [
        m
        for m in members
        if hasProject and selectedProject in m.project_ids
    ];
    outsiders = [
        m
        for m in members
        if m not in inProject
    ];
    outsideSelected = False;
    for m in outsiders {
        if m.id in assignees and hasProject {
            outsideSelected = True;
        }
    }
    pickedNames = [
        m.name
        for m in members
        if m.id in assignees
    ];
    projectRepos = [
        r
        for r in repos
        if hasProject and r.project_id == selectedProject
    ];
    chosenRepo = "";
    if len(projectRepos) == 1 {
        chosenRepo = projectRepos[0].id;
    } else {
        # A stale pick from a previous project must not reach the walker.
        for r in projectRepos {
            if r.id == repoChoice {
                chosenRepo = r.id;
            }
        }
    }
    canCreateIssue = (
        editing and ghConnected and ghIssueNumber == 0 and len(projectRepos) > 0
    );
    # An existing task's notes and checklist come from GetTask; until they
    # are in, Save stays off, or it would write empty notes over the real ones.
    detailsShown = not (editing and taskId) or detailsFor == taskId;
    detailsFailed = not detailsShown and failedFor == taskId;
    canSave = (
        not saving and bool(form["title"].strip()) and hasProject and detailsShown
    );

    # The columns' colours and where this task stands on the route.
    colors: list[str] = [];
    for k in columnKeys {
        found = LEGACY_COLOR[k] if k in LEGACY_COLOR else "slate";
        for s in steps {
            if s.id == k {
                found = s.color;
            }
        }
        colors.append(found);
    }
    hereKey = form["status"];
    hereIdx = -1;
    for (i, k) in enumerate(columnKeys) {
        if k == hereKey {
            hereIdx = i;
        }
    }
    route = routeFrom(hereKey, columnKeys, steps);
    prevIdx = -1;
    nextIdx = -1;
    if len(route["back"]) > 0 {
        for (i, k) in enumerate(columnKeys) {
            if k == route["back"][0] {
                prevIdx = i;
            }
        }
    }
    if len(route["next"]) > 0 {
        for (i, k) in enumerate(columnKeys) {
            if k == route["next"][0] {
                nextIdx = i;
            }
        }
    }
    hereLabel = columnLabels[hereIdx]
        if hereIdx >= 0 and hereIdx < len(columnLabels)
        else "";
    hereColor = colors[hereIdx] if hereIdx >= 0 else "slate";

    # Under the Step row: which step of how many, who owns it, and who on
    # this project holds that role (the person a move would hand to).
    hereStep: list[StepView] = [
        s
        for s in steps
        if s.id == hereKey
    ];
    whereLine = "";
    if len(hereStep) > 0 {
        herePos = 0;
        for (si, s) in enumerate(steps) {
            if s.id == hereKey {
                herePos = si + 1;
            }
        }
        hereOwner = (hereStep[0].owner or "").strip();
        held: list[str] = [];
        pool = inProject if hasProject else members;
        for m in pool {
            if hereOwner and hereOwner in m.roles {
                held.append(m.name);
            }
        }
        whereLine = "step " + str(herePos) + " of " + str(len(steps));
        if hereOwner == "anyone" {
            whereLine = whereLine + " · anyone";
        } elif hereOwner {
            whereLine = whereLine
                + " · "
                + hereOwner
                + (
                    " · " + ", ".join(held)
                        if len(held) > 0
                        else " · no one on this project"
                );
        }
    }
    # CreateTask takes no reviewer or pull request, so those rows wait for
    # an existing task rather than drop what is typed into them.
    showReviewer = editing
        and (
            hereKey in handoffKeys
            or form["reviewer"] != "none"
            or bool(form["review_due"])
        );

    def pickStep(key: str) {
        if onMove {
            onMove(key);
        } else {
            onField("status", key);
        }
    }

    def save {
        if canSave {
            pendingAction = "save";
            onSave();
        }
    }

    # M opens the move menu only for keys the sheet itself receives: React
    # bubbles portalled select, menu and popover keys here too, and a select
    # trigger takes letters as typeahead, so those keys are left alone.
    def onSheetKey(e: KeyboardEvent) {
        t: any = e.target;
        box: any = e.currentTarget;
        tag = str(t.tagName or "").lower() if t else "";
        typing = tag == "input"
            or tag == "textarea"
            or tag == "select"
            or bool(t and t.isContentEditable);
        inside = bool(box and t and box.contains(t));
        widget = bool(t and t.closest(WIDGET_ROLES));
        popup = bool(document.querySelector("[role=listbox], [role=menu]"));
        if (e.key == "m" or e.key == "M")
            and editing
            and inside
            and not typing
            and not widget
            and not popup
            and not e.defaultPrevented
            and not e.metaKey
            and not e.ctrlKey
            and not e.altKey
            and len(columnKeys) > 0 {
            e.preventDefault();
            moveOpen = True;
        }
    }

    # Keyboard users land back on the card they opened, when the page has one.
    def returnFocus(e: Event) {
        card: any = None;
        if taskId {
            card = document.querySelector('[data-task-card="' + taskId + '"]');
        }
        if card {
            e.preventDefault();
            card.focus({"preventScroll": True});
        }
    }

    # Escape answers an open unsaved-changes question with "keep editing". In
    # a field outside the sheet (the board's title filter) it is that field's.
    def keepOnOutsideEscape(e: any) {
        if switchLabel {
            e.preventDefault();
            if onStay {
                onStay();
            }
            return;
        }
        active: any = document.activeElement;
        sheet: any = document.querySelector("[data-task-sheet]");
        tag = str(active.tagName or "").lower() if active else "";
        if (tag == "input" or tag == "textarea")
            and sheet
            and not sheet.contains(active) {
            e.preventDefault();
        }
    }

    # Beside the page only at md+: below that the sheet covers the board (full
    # screen on phones), so it traps focus like any modal. viewW re-renders
    # this on a resize.
    win: any = window;
    besideNow = beside and int(win.innerWidth) >= 768;

    return
        <Sheet open={open} onOpenChange={onOpenChange} modal={not besideNow}>
            <SheetContent
                side="right"
                data-task-sheet="true"
                data-beside={"true" if besideNow else "false"}
                aria-modal={"false" if besideNow else "true"}
                showCloseButton={False}
                className="gap-0 bg-card p-0 text-card-foreground outline-none data-[side=right]:w-full data-[side=right]:sm:max-w-[420px]"
                style={{
                    "top": str(topPx) + "px",
                    "right": str(rightPx) + "px",
                    "height": "auto",
                    "bottom": "0px"
                }}
                onOpenAutoFocus={lambda (e: Event) {
                    e.preventDefault();
                    box: any = e.target;
                    if editing and box {
                        box.focus({"preventScroll": True});
                    }
                }}
                onCloseAutoFocus={returnFocus}
                onEscapeKeyDown={keepOnOutsideEscape}
                onInteractOutside={lambda (e: any) {
                # Only Close, Cancel, Save and Escape close it. A click on
                # the page goes to the page, which asks before it swaps.
                e.preventDefault(); }}
                onKeyDown={onSheetKey}
            >
                <div
                    className="flex min-h-12 shrink-0 items-center gap-2 border-b px-4 py-2"
                >
                    <div
                        className="flex min-w-0 flex-1 items-center gap-1.5 overflow-hidden text-[12.5px] whitespace-nowrap text-muted-foreground"
                    >
                        {if not editing and hereLabel {
                            <span key="lands">Lands in</span>
                        }}
                        {if editing and prevIdx >= 0 {
                            <span key="prev" className="min-w-0 truncate">
                                {columnLabels[prevIdx]}
                            </span>
                        }}
                        {if editing and prevIdx >= 0 {
                            <Arrow key="prevarrow"/>
                        }}
                        {if hereLabel {
                            <StepName
                                key="here"
                                name={hereLabel}
                                color={hereColor}
                                className="max-w-40 shrink-0 font-semibold text-foreground"
                            />
                        }}
                        {if editing and nextIdx >= 0 {
                            <Arrow key="nextarrow"/>
                        }}
                        {if editing and nextIdx >= 0 {
                            <span key="next" className="min-w-0 truncate">
                                {columnLabels[nextIdx]}
                            </span>
                        }}
                    </div>
                    <div className="flex shrink-0 items-center gap-1">
                        {if editing and len(columnKeys) > 0 {
                            <MoveMenu
                                key="move"
                                open={moveOpen}
                                onOpenChange={lambda (o: bool) { moveOpen = o; }}
                                current={hereKey}
                                keys={columnKeys}
                                labels={columnLabels}
                                colors={colors}
                                steps={steps}
                                onPick={pickStep}
                                showLabel={True}
                                align="end"
                                triggerClass="inline-flex h-7 items-center gap-1.5 rounded-md border bg-card px-2 text-[12.5px] font-semibold text-foreground hover:bg-accent focus-visible:outline-2 focus-visible:outline-ring"
                            />
                        }}
                        <button
                            type="button"
                            aria-label="Close"
                            className="inline-flex size-7 items-center justify-center rounded-md text-muted-foreground hover:bg-accent hover:text-foreground"
                            onClick={lambda { onOpenChange(False); }}
                        >
                            <svg
                                width={16}
                                height={16}
                                viewBox="0 0 16 16"
                                aria-hidden="true"
                            >
                                <path
                                    d="m4 4 8 8M12 4l-8 8"
                                    stroke="currentColor"
                                    strokeWidth={1.6}
                                    strokeLinecap="round"
                                />
                            </svg>
                        </button>
                    </div>
                </div>
                <div className="min-h-0 flex-1 overflow-y-auto">
                    <div
                        className="grid grid-cols-[minmax(0,1fr)] gap-5 px-4 pt-3 pb-6"
                    >
                        <div className="grid gap-0.5">
                            <SheetTitle
                                className="px-0 text-xs font-normal text-subtle"
                            >
                                {"Edit task" if editing else "New task"}
                            </SheetTitle>
                            <SheetDescription className="sr-only">
                                {"The task's properties, notes and history."}
                            </SheetDescription>
                            <Input
                                data-task-title="true"
                                aria-label="Title"
                                placeholder="What needs doing?"
                                className="-mx-2 h-auto w-[calc(100%+1rem)] border-transparent bg-transparent px-2 py-1 text-[19px] leading-snug hover:border-border md:text-[19px]"
                                style={{"fontWeight": 650, "fontStretch": "108%"}}
                                value={form["title"]}
                                onChange={lambda (e: ChangeEvent) { onField(
                                    "title", e.target.value
                                ); }}
                                onKeyDown={lambda (e: KeyboardEvent) { if e.key
                                    == "Enter"
                                    and not e.isComposing {
                                    e.preventDefault();
                                    save();
                                }}}
                            />
                        </div>
                        <dl className="grid grid-cols-[minmax(0,1fr)] gap-y-px">
                            <PropRow label="Step" top={bool(editing and whereLine)}>
                                <Select
                                    value={hereKey}
                                    onValueChange={lambda (v: str) { onField(
                                        "status", v
                                    ); }}
                                >
                                    <SelectTrigger
                                        className={GHOST_SELECT}
                                        aria-label="Step"
                                    >
                                        <SelectValue placeholder="Pick a step"/>
                                    </SelectTrigger>
                                    <SelectContent>
                                        {for (si, s) in enumerate(columnKeys) {
                                            <SelectItem key={s} value={s}>
                                                <StepName
                                                    name={columnLabels[si]}
                                                    color={colors[si]}
                                                />
                                            </SelectItem>
                                        }}
                                    </SelectContent>
                                </Select>
                                {if editing and whereLine {
                                    <p
                                        key="where"
                                        className="px-2 pb-1 text-xs text-muted-foreground"
                                        title={whereLine}
                                    >
                                        {whereLine}
                                    </p>
                                }}
                            </PropRow>
                            <PropRow label="Project">
                                <Select
                                    value={form["project"]}
                                    onValueChange={lambda (v: str) { onField(
                                        "project", v
                                    ); }}
                                >
                                    <SelectTrigger
                                        className={GHOST_SELECT
                                            + ("" if hasProject else " text-subtle")}
                                        aria-label="Project"
                                    >
                                        <SelectValue placeholder="Pick a project"/>
                                    </SelectTrigger>
                                    <SelectContent>
                                        {for p in projects {
                                            <SelectItem key={jid(p)} value={jid(p)}>
                                                {p.name}
                                            </SelectItem>
                                        }}
                                    </SelectContent>
                                </Select>
                            </PropRow>
                            <PropRow label="Assignees" top={outsideSelected}>
                                <DropdownMenu>
                                    <DropdownMenuTrigger
                                        className="flex h-8 w-full min-w-0 cursor-pointer items-center gap-2 rounded-md px-2 text-left text-[13px] outline-none hover:bg-accent focus-visible:outline-2 focus-visible:outline-solid focus-visible:outline-ring data-[state=open]:bg-accent"
                                        aria-label="Assignees"
                                    >
                                        {if len(pickedNames) > 0 {
                                            <AvatarStack
                                                key="av"
                                                names={pickedNames}
                                                max={3}
                                            />
                                        }}
                                        <span
                                            className={"min-w-0 truncate"
                                                + (
                                                    ""
                                                        if len(pickedNames) > 0
                                                        else " text-subtle"
                                                )}
                                        >
                                            {", ".join(pickedNames)
                                                if len(pickedNames) > 0
                                                else "Pick assignees"}
                                        </span>
                                    </DropdownMenuTrigger>
                                    <DropdownMenuContent className="w-64" align="start">
                                        {if len(inProject) > 0 {
                                            <DropdownMenuLabel key="inl">
                                                On this project
                                            </DropdownMenuLabel>
                                        }}
                                        {for m in inProject {
                                            <DropdownMenuCheckboxItem
                                                key={m.id}
                                                checked={m.id in assignees}
                                                onCheckedChange={lambda { if onToggleAssignee {
                                                    onToggleAssignee(m.id);
                                                }}}
                                                onSelect={lambda (e: any) { e.preventDefault(); }}
                                            >
                                                {m.name}
                                            </DropdownMenuCheckboxItem>
                                        }}
                                        {if len(inProject) > 0 and len(outsiders) > 0 {
                                            <DropdownMenuSeparator key="sep"/>
                                        }}
                                        {if len(outsiders) > 0 {
                                            <DropdownMenuLabel key="ol">
                                                {"Other people"
                                                    if hasProject
                                                    else "People"}
                                            </DropdownMenuLabel>
                                        }}
                                        {for m in outsiders {
                                            <DropdownMenuCheckboxItem
                                                key={m.id}
                                                checked={m.id in assignees}
                                                onCheckedChange={lambda { if onToggleAssignee {
                                                    onToggleAssignee(m.id);
                                                }}}
                                                onSelect={lambda (e: any) { e.preventDefault(); }}
                                            >
                                                {m.name}
                                            </DropdownMenuCheckboxItem>
                                        }}
                                    </DropdownMenuContent>
                                </DropdownMenu>
                                {if outsideSelected {
                                    <p
                                        key="hint"
                                        className="px-2 pb-1 text-xs text-muted-foreground"
                                    >
                                        Some picks are not on this project yet. Saving adds them to it.
                                    </p>
                                }}
                            </PropRow>
                            {if showReviewer {
                                <PropRow key="reviewer" label="Reviewer">
                                    <Select
                                        value={form["reviewer"]}
                                        onValueChange={lambda (v: str) { onField(
                                            "reviewer", v
                                        ); }}
                                    >
                                        <SelectTrigger
                                            className={GHOST_SELECT
                                                + (
                                                    " text-subtle"
                                                        if form["reviewer"] == "none"
                                                        else ""
                                                )}
                                            aria-label="Reviewer"
                                        >
                                            <SelectValue placeholder="No reviewer"/>
                                        </SelectTrigger>
                                        <SelectContent>
                                            <SelectItem value="none">
                                                No reviewer
                                            </SelectItem>
                                            {for m in members {
                                                <SelectItem key={m.id} value={m.id}>
                                                    {m.name}
                                                </SelectItem>
                                            }}
                                        </SelectContent>
                                    </Select>
                                </PropRow>
                            }}
                            {if showReviewer {
                                <PropRow key="reviewby" label="Review by">
                                    <DatePicker
                                        value={form["review_due"]}
                                        clearable={True}
                                        className={GHOST_DATE
                                            + (
                                                " text-subtle!"
                                                    if not form["review_due"]
                                                    else ""
                                            )}
                                        onChange={lambda (d: str) { onField(
                                            "review_due", d
                                        ); }}
                                    />
                                </PropRow>
                            }}
                            <PropRow label="Start date">
                                <DatePicker
                                    value={form["start_date"]}
                                    clearable={True}
                                    className={GHOST_DATE
                                        + (
                                            " text-subtle!"
                                                if not form["start_date"]
                                                else ""
                                        )}
                                    onChange={lambda (d: str) { onField(
                                        "start_date", d
                                    ); }}
                                />
                            </PropRow>
                            <PropRow
                                label="Due"
                                top={bool(
                                    form["start_date"]
                                        and form["due_date"]
                                        and form["start_date"] > form["due_date"]
                                )}
                            >
                                <DatePicker
                                    value={form["due_date"]}
                                    clearable={True}
                                    className={GHOST_DATE
                                        + (
                                            " text-subtle!"
                                                if not form["due_date"]
                                                else ""
                                        )}
                                    onChange={lambda (d: str) { onField(
                                        "due_date", d
                                    ); }}
                                />
                                {if form["start_date"]
                                    and form["due_date"]
                                    and form["start_date"] > form["due_date"] {
                                    <p
                                        key="order"
                                        className="px-2 pb-1 text-xs text-destructive"
                                    >
                                        Due before it starts.
                                    </p>
                                }}
                            </PropRow>
                            {if len(iterations) > 0 or form["iteration"] != "none" {
                                <PropRow key="iteration" label="Iteration">
                                    <Select
                                        value={form["iteration"]}
                                        onValueChange={lambda (v: str) { onField(
                                            "iteration", v
                                        ); }}
                                    >
                                        <SelectTrigger
                                            className={GHOST_SELECT
                                                + (
                                                    " text-subtle"
                                                        if form["iteration"] == "none"
                                                        else ""
                                                )}
                                            aria-label="Iteration"
                                        >
                                            <SelectValue placeholder="No iteration"/>
                                        </SelectTrigger>
                                        <SelectContent>
                                            <SelectItem value="none">
                                                No iteration
                                            </SelectItem>
                                            {for it in iterations {
                                                <SelectItem key={it.id} value={it.id}>
                                                    {it.name
                                                        + " · "
                                                        + prettyDay(it.start_date)
                                                        + " to "
                                                        + prettyDay(it.end_date)}
                                                </SelectItem>
                                            }}
                                        </SelectContent>
                                    </Select>
                                </PropRow>
                            }}
                            <PropRow label="Priority">
                                <Select
                                    value={form["priority"]}
                                    onValueChange={lambda (v: str) { onField(
                                        "priority", v
                                    ); }}
                                >
                                    <SelectTrigger
                                        className={GHOST_SELECT}
                                        aria-label="Priority"
                                    >
                                        <SelectValue placeholder="Priority"/>
                                    </SelectTrigger>
                                    <SelectContent>
                                        {for p in PRIORITIES {
                                            <SelectItem key={p} value={p}>
                                                <span
                                                    className="inline-flex items-center gap-1.5"
                                                >
                                                    {if p == "High" {
                                                        <Flag key="flag"/>
                                                    }}
                                                    {p}
                                                </span>
                                            </SelectItem>
                                        }}
                                    </SelectContent>
                                </Select>
                            </PropRow>
                            <PropRow label="Estimate">
                                <Input
                                    id="task-estimate"
                                    type="number"
                                    min="0"
                                    step="0.5"
                                    aria-label="Estimate"
                                    className={GHOST_INPUT + " num"}
                                    placeholder="Points or hours"
                                    value={form["estimate"]}
                                    onChange={lambda (e: any) { onField(
                                        "estimate", e.target.value
                                    ); }}
                                />
                            </PropRow>
                            <PropRow label="Category">
                                <Input
                                    id="task-category"
                                    list="flowline-categories"
                                    aria-label="Category"
                                    className={GHOST_INPUT}
                                    placeholder="Type or pick"
                                    value={form["category"]}
                                    onChange={lambda (e: any) { onField(
                                        "category", e.target.value
                                    ); }}
                                />
                                <datalist id="flowline-categories">
                                    {for c in categories {
                                        <option key={c} value={c}/>
                                    }}
                                </datalist>
                            </PropRow>
                            <PropRow label="Tags">
                                <Input
                                    id="task-tags"
                                    aria-label="Tags"
                                    className={GHOST_INPUT}
                                    placeholder="Comma-separated, e.g. bug, payments"
                                    value={form["tags"]}
                                    onChange={lambda (e: any) { onField(
                                        "tags", e.target.value
                                    ); }}
                                />
                            </PropRow>
                            {if editing {
                                <PropRow key="pr" label="Pull request">
                                    <div className="flex items-center">
                                        <Input
                                            aria-label="Pull request link"
                                            className={GHOST_INPUT
                                                + " min-w-0 flex-1 font-mono text-xs md:text-xs"}
                                            placeholder="Paste a pull request link"
                                            value={form["pr"]}
                                            onChange={lambda (e: ChangeEvent) { onField(
                                                "pr", e.target.value
                                            ); }}
                                        />
                                        {if prState {
                                            <span
                                                key="state"
                                                className="shrink-0 px-1 text-xs text-muted-foreground"
                                                title={"Pull request " + prState}
                                            >
                                                {prState}
                                            </span>
                                        }}
                                        {if form["pr"].strip() {
                                            <OpenLink
                                                key="open"
                                                url={form["pr"].strip()}
                                            />
                                        }}
                                    </div>
                                </PropRow>
                            }}
                            <PropRow label="Issue">
                                <div className="flex items-center">
                                    <Input
                                        aria-label="GitHub issue link"
                                        className={GHOST_INPUT
                                            + " min-w-0 flex-1 font-mono text-xs md:text-xs"}
                                        placeholder="Paste a GitHub issue link"
                                        value={form["issue"]}
                                        onChange={lambda (e: ChangeEvent) { onField(
                                            "issue", e.target.value
                                        ); }}
                                    />
                                    {if form["issue"].strip() {
                                        <OpenLink
                                            key="open"
                                            url={form["issue"].strip()}
                                        />
                                    }}
                                </div>
                            </PropRow>
                            {if canCreateIssue {
                                <PropRow key="ghissue" label="">
                                    <div className="grid gap-1.5 px-2 pb-1">
                                        {if len(projectRepos) > 1 {
                                            <Select
                                                key="repopick"
                                                value={repoChoice}
                                                onValueChange={lambda (v: str) { repoChoice = v; }}
                                            >
                                                <SelectTrigger className="h-8 w-full">
                                                    <SelectValue
                                                        placeholder="Pick a repo"
                                                    />
                                                </SelectTrigger>
                                                <SelectContent>
                                                    {for r in projectRepos {
                                                        <SelectItem
                                                            key={r.id}
                                                            value={r.id}
                                                        >
                                                            {r.full_name}
                                                        </SelectItem>
                                                    }}
                                                </SelectContent>
                                            </Select>
                                        }}
                                        <div
                                            className="flex flex-wrap items-center gap-2"
                                        >
                                            <Button
                                                variant="outline"
                                                size="sm"
                                                disabled={saving or not chosenRepo}
                                                onClick={lambda { if onCreateIssue
                                                    and chosenRepo {
                                                    pendingAction = "issue";
                                                    onCreateIssue(chosenRepo);
                                                }}}
                                            >
                                                {if saving
                                                    and pendingAction == "issue" {
                                                    <Spinner key="sp"/>
                                                }}
                                                {"Opening issue…"
                                                    if saving
                                                        and pendingAction == "issue"
                                                    else "Create GitHub issue"}
                                            </Button>
                                            <span
                                                className="text-xs text-muted-foreground"
                                            >
                                                From the title and notes, then linked.
                                            </span>
                                        </div>
                                    </div>
                                </PropRow>
                            }}
                        </dl>
                        <section className="grid gap-1.5" aria-label="Notes">
                            <div className="flex items-center justify-between">
                                <h3 className="text-[13px] font-semibold">Notes</h3>
                                {if hasNotes and detailsShown {
                                    <Button
                                        key="toggle"
                                        variant="ghost"
                                        size="xs"
                                        onClick={lambda { notesEditing = not notesEditing; }}
                                    >
                                        {"Preview" if notesEditing else "Edit"}
                                    </Button>
                                }}
                            </div>
                            {if not detailsShown {
                                if detailsFailed {
                                    <div
                                        key="failed"
                                        className="flex items-center justify-between gap-2 rounded-md border border-destructive/30 px-2.5 py-2 text-[13px] text-destructive"
                                    >
                                        <span>
                                            Notes and checklist could not be loaded.
                                        </span>
                                        <Button
                                            variant="ghost"
                                            size="xs"
                                            onClick={lambda {
                                                failedFor = "";
                                                loadDetails(taskId);
                                            }}
                                        >
                                            Try again
                                        </Button>
                                    </div>
                                } else {
                                    <div
                                        key="loading"
                                        className="grid gap-2 py-1"
                                        aria-busy="true"
                                    >
                                        <Skeleton className="h-3.5 w-4/5"/>
                                        <Skeleton className="h-3.5 w-3/5"/>
                                        <Skeleton className="mt-3 h-3.5 w-2/5"/>
                                    </div>
                                }
                            } elif notesEditing or not hasNotes {
                                <Textarea
                                    key="write"
                                    className="min-h-20 rounded-md text-[13px] md:text-[13px]"
                                    placeholder="Add notes, acceptance criteria or links. Markdown works."
                                    value={form["notes"]}
                                    onChange={lambda (e: ChangeEvent) {
                                        notesEditing = True;
                                        onField("notes", e.target.value);
                                    }}
                                />
                            } else {
                                <div
                                    key="preview"
                                    className="min-h-12 cursor-text rounded-md border px-2.5 py-2 text-[13px]"
                                    onClick={lambda { notesEditing = True; }}
                                >
                                    <Markdown text={form["notes"]}/>
                                </div>
                            }  }
                        </section>
                        {if editing and familyTotal > 0 {
                            <section
                                key="family"
                                className="grid gap-1.5"
                                aria-label="Sub-issues"
                            >
                                <div
                                    className="flex items-baseline justify-between gap-3"
                                >
                                    <h3 className="text-[13px] font-semibold">
                                        Sub-issues
                                    </h3>
                                    <span className="num text-xs text-muted-foreground">
                                        {str(familyDone)
                                            + " of "
                                            + str(familyTotal)
                                            + " done"}
                                    </span>
                                </div>
                                <div className="border-t">
                                    {for kid in family {
                                        <button
                                            key={kid.id}
                                            type="button"
                                            className="flex w-full items-center gap-2 border-b px-1 py-1.5 text-left text-[13px] hover:bg-accent"
                                            title={"Open " + kid.title}
                                            onClick={lambda { if onOpenTask {
                                                onOpenTask(kid.id);
                                            }}}
                                        >
                                            <span
                                                className="num flex-none text-xs text-subtle"
                                            >
                                                {"#" + str(kid.gh_issue_number)}
                                            </span>
                                            <span className="min-w-0 flex-1 truncate">
                                                {kid.title}
                                            </span>
                                            <span
                                                className={"flex-none text-xs "
                                                    + (
                                                        "text-success"
                                                            if kid.status == "Done"
                                                            else "text-muted-foreground"
                                                    )}
                                            >
                                                {familyStepLabel(
                                                    kid, columnKeys, columnLabels
                                                )}
                                            </span>
                                        </button>
                                    }}
                                    {if len(family) < familyTotal {
                                        <p
                                            key="ghost"
                                            className="px-1 py-1.5 text-xs text-muted-foreground"
                                        >
                                            {str(familyTotal - len(family))
                                                + " more on GitHub, not on the board"}
                                        </p>
                                    }}
                                </div>
                            </section>
                        }}
                        {if editing and parentTaskId {
                            <button
                                key="parentlink"
                                type="button"
                                className="-mt-2 flex w-full items-center gap-2 rounded-md px-1 py-1 text-left text-[13px] text-muted-foreground hover:bg-accent hover:text-foreground"
                                title={"Open the parent issue " + parentLabel}
                                onClick={lambda { if onOpenTask {
                                    onOpenTask(parentTaskId);
                                }}}
                            >
                                <span className="flex-none">Part of</span>
                                <span
                                    className="min-w-0 flex-1 truncate text-foreground"
                                >
                                    {parentLabel}
                                </span>
                            </button>
                        }}
                        {if editing and taskId and detailsShown {
                            <ChecklistEditor
                                key={"checklist-" + taskId}
                                taskId={taskId}
                                items={checklist}
                                onChange={absorbChecklist}
                            />
                        }}
                        {if editing and taskId {
                            <TravelLog
                                key={"travel-" + taskId}
                                taskId={taskId}
                                since={createdAt}
                                refreshKey={historyKey}
                            />
                        }}
                    </div>
                </div>
                {if switchLabel {
                    <div
                        key="switch"
                        role="group"
                        aria-label="Unsaved changes"
                        className="grid shrink-0 gap-2 border-t px-4 py-3 pb-[calc(0.75rem+env(safe-area-inset-bottom))]"
                    >
                        <p id="task-switch-note" className="text-[13px]">
                            <span className="font-semibold">Unsaved changes.</span>
                            {" Save or discard them to open " + switchLabel + "."}
                        </p>
                        <div className="flex flex-wrap items-center gap-2">
                            <Button
                                variant="ghost"
                                className="-ml-2"
                                data-switch-stay="true"
                                onClick={lambda { if onStay { onStay(); }}}
                            >
                                Keep editing
                            </Button>
                            <div className="ml-auto flex gap-2">
                                <Button
                                    variant="outline"
                                    disabled={saving}
                                    onClick={lambda { if onSwitch { onSwitch(False); }}}
                                >
                                    Discard
                                </Button>
                                <Button
                                    data-switch-save="true"
                                    aria-describedby="task-switch-note"
                                    disabled={not canSave}
                                    onClick={lambda { if onSwitch and canSave {
                                        pendingAction = "save";
                                        onSwitch(True);
                                    }}}
                                >
                                    {if saving and pendingAction == "save" {
                                        <Spinner key="sp"/>
                                    }}
                                    {"Saving…"
                                        if saving and pendingAction == "save"
                                        else "Save and open"}
                                </Button>
                            </div>
                        </div>
                    </div>
                } else {
                    <div
                        key="footer"
                        className="flex shrink-0 items-center gap-2 border-t px-4 py-3 pb-[calc(0.75rem+env(safe-area-inset-bottom))]"
                    >
                        {if editing {
                            <Button
                                key="del"
                                variant="ghost"
                                className="-ml-2 text-destructive hover:bg-destructive/10 hover:text-destructive"
                                onClick={lambda {
                                    pendingAction = "delete";
                                    onDelete();
                                }}
                                disabled={saving}
                            >
                                {if saving and pendingAction == "delete" {
                                    <Spinner key="sp"/>
                                }}
                                {"Deleting…"
                                    if saving and pendingAction == "delete"
                                    else "Delete"}
                            </Button>
                        }}
                        <div className="ml-auto flex gap-2">
                            <Button
                                variant="outline"
                                onClick={lambda { onOpenChange(False); }}
                            >
                                Cancel
                            </Button>
                            <Button onClick={lambda { save(); }} disabled={not canSave}>
                                {if saving and pendingAction == "save" {
                                    <Spinner key="sp"/>
                                }}
                                {"Saving…"
                                    if saving and pendingAction == "save"
                                    else "Save"}
                            </Button>
                        </div>
                    </div>
                } }
            </SheetContent>
        </Sheet>;
}
