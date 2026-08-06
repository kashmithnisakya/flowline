"""standup - Workflow page (/workflow): how work moves through the org.

Stateful shell over three faces of one graph: the template picker when no
workflow exists yet, the designer when editing, and a read-only diagram the
rest of the time. One workflow per organization — steps hang off the root
like everything else, so there is no project selector here.

Validation is advisory on purpose: the chip points out a missing start or
done step and unreachable steps, but never blocks saving. The graph belongs
to the org, loops and all.
"""

import from ...models { StepView }
import from ...constants { STEP_KINDS, KIND_COLORS }
import from ...walkers.workflow {
    GetWorkflow,
    ApplyTemplate,
    SaveStep,
    MoveStep,
    DeleteStep,
    LinkTransition,
    UnlinkTransition,
    GetWorkflowMeta,
    RenameWorkflow
}
import from ...components.workflow.FlowCanvas { FlowCanvas }
import from ...components.workflow.TemplatePicker { TemplatePicker }
import from ...components.workflow.StepInspector { StepInspector }
import from ...components.workflow.geometry { hitStep, stepXY }
import from ...components.workflow.kinds { KIND_LABEL, DOT_FILL }
import from ...components.ui.button { Button }
import from ...components.ui.input { Input }
import from ...components.ui.skeleton { Skeleton }
import from "sonner" { toast }

glob BLANK_STEP: dict[str, str] = {
         "name": "",
         "kind": "active",
         "color": "indigo"
     },
     HOW_TO: list[list[str]] = [
         ["Add step", "asks for a name, then drops the card on the canvas."],
         ["Drag a card", "to move it. The position saves when you let go."],
         [
             "Drag from a card's border",
             "onto another card to draw a transition. Backwards is fine — loops are the point."
         ],
         ["Click a transition", "for its remove chip. Click a card to edit it here."]
     ];


# The canvas is direct-manipulation and nothing about it is discoverable
# from looking, so the panel says plainly what the drags do.
def:pub WorkflowPage -> JsxPage {
    has steps: list[StepView] = [],
        loading: bool = True,
        editing: bool = False,
        scratch: bool = False,
        applying: str = "",
        wfName: str = "Workflow",
        renaming: bool = False,
        nameDraft: str = "",
        selectedId: str = "",
        connectFrom: str = "",
        selectedEdge: str = "",
        form: dict[str, str] = BLANK_STEP,
        saving: bool = False,
        confirmDelete: bool = False,
        # Add step opens a naming panel first: the step only exists once the
        # user has called it something, never as a placeholder card.
        creatingStep: bool = False,
        # A dragged step's live position, canvas px, for this drag only. The
        # persisted x/y takes over again after MoveStep + reload.
        live: dict[str, list[float]] = {},
        busyRef: Ref[any] = Ref(),
        dragRef: Ref[any] = Ref(),
        wireRef: Ref[any] = Ref(),
        swallowRef: Ref[any] = Ref(),
        stepsRef: Ref[any] = Ref(),
        liveRef: Ref[any] = Ref(),
        canvasRef: Ref[any] = Ref();

    async can with entry {
        boot();
    }

    async def boot -> None;
    async def reload -> None;
    async def loadMeta -> None;
    async def pickTemplate(key: str) -> None;
    def startScratch -> None;
    def startRename -> None;
    async def saveRename -> None;
    def addStep -> None;
    async def commitName -> None;
    async def commitField(key: str, value: str) -> None;
    async def deleteStep -> None;
    async def linkSteps(fromId: str, toId: str) -> None;
    async def deleteEdge(fromId: str, toId: str) -> None;
    def selectStep(stepId: str) -> None;
    def armConnect -> None;
    def clearCanvas -> None;
    def setField(key: str, value: str) -> None;
    def pointerXY(e: MouseEvent) -> list[float];
    def beginDrag(e: MouseEvent) -> None;
    def moveDrag(e: MouseEvent) -> None;
    async def endDrag(e: MouseEvent) -> None;

    stepsRef.current = steps;
    liveRef.current = live;

    byId: dict[str, StepView] = {};
    for s in steps {
        byId[s.id] = s;
    }
    picked = [
        s
        for s in steps
        if s.id == selectedId
    ];
    sourced = [
        s
        for s in steps
        if s.id == connectFrom
    ];
    connectTitle = sourced[0].name if sourced else "";

    linkCount = 0;
    startCount = 0;
    doneCount = 0;
    for s in steps {
        if s.kind == "start" {
            startCount = startCount + 1;
        }
        if s.kind == "done" {
            doneCount = doneCount + 1;
        }
        for nid in s.next_ids {
            if nid in byId {
                linkCount = linkCount + 1;
            }
        }
    }

    # Advisory checks. All plain BFS over the views already in hand.
    issues: list[str] = [];
    if len(steps) > 0 {
        if startCount == 0 {
            issues.append("No start step yet — mark where new work lands.");
        }
        if doneCount == 0 {
            issues.append("No done step yet — every flow needs a terminal step.");
        }
        if startCount > 0 {
            seen: dict[str, bool] = {};
            frontier: list[str] = [];
            for s in steps {
                if s.kind == "start" {
                    frontier.append(s.id);
                    seen[s.id] = True;
                }
            }
            at = 0;
            while at < len(frontier) {
                current = frontier[at];
                at = at + 1;
                for nid in byId[current].next_ids {
                    if nid in byId and nid not in seen {
                        seen[nid] = True;
                        frontier.append(nid);
                    }
                }
            }
            stranded = 0;
            for s in steps {
                if s.id not in seen {
                    stranded = stranded + 1;
                }
            }
            if stranded > 0 {
                issues.append(
                    str(stranded)
                        + (" step has" if stranded == 1 else " steps have")
                        + " no path from a start step."
                );
            }
        }
        if doneCount > 0 {
            reach: dict[str, bool] = {};
            backlog: list[str] = [];
            for s in steps {
                if s.kind == "done" {
                    backlog.append(s.id);
                    reach[s.id] = True;
                }
            }
            at2 = 0;
            while at2 < len(backlog) {
                current2 = backlog[at2];
                at2 = at2 + 1;
                for pid in byId[current2].prev_ids {
                    if pid in byId and pid not in reach {
                        reach[pid] = True;
                        backlog.append(pid);
                    }
                }
            }
            noPath = 0;
            for s in steps {
                if s.id not in reach {
                    noPath = noPath + 1;
                }
            }
            if noPath > 0 {
                issues.append(
                    str(noPath)
                        + (" step has" if noPath == 1 else " steps have")
                        + " no path to a done step."
                );
            }
        }
    }

    showPicker = not loading and len(steps) == 0 and not scratch;

    return
        <div className="mx-auto flex max-w-6xl flex-col gap-6">
            {if loading or showPicker {
                <div key="head" className="flex flex-col gap-2">
                    <h1 className="font-display text-3xl font-semibold tracking-tight">
                        Workflow
                    </h1>
                    <p className="text-sm text-muted-foreground">
                        The steps work moves through in your organization, drawn your way — branches and loops included.
                    </p>
                </div>
            }}
            {if loading {
                <div key="sk" className="space-y-4">
                    <Skeleton key="s1" className="h-44 w-full"/>
                    <Skeleton key="s2" className="h-52 w-full"/>
                </div>
            } elif showPicker {
                <TemplatePicker
                    key="picker"
                    applying={applying}
                    onPick={pickTemplate}
                    onScratch={startScratch}
                />
            } elif editing {
                <div key="designer" className="flex flex-col gap-4">
                    <div className="flex flex-wrap items-center gap-2">
                        {if renaming {
                            <Input
                                key="rename"
                                className="w-64"
                                value={nameDraft}
                                autoFocus={True}
                                onChange={lambda (e: any) { nameDraft = e.target.value; }}
                                onBlur={saveRename}
                                onKeyDown={lambda (e: any) { if e.key == "Enter" {
                                    saveRename();
                                }}}
                            />
                        } else {
                            <h1
                                key="name"
                                className="font-display text-2xl font-semibold tracking-tight"
                            >
                                {wfName}
                            </h1>
                        } }
                        {if not renaming {
                            <Button
                                key="rename-btn"
                                variant="ghost"
                                size="sm"
                                onClick={startRename}
                            >
                                Rename
                            </Button>
                        }}
                        <div className="flex-1"/>
                        {if len(issues) > 0 {
                            <span
                                key="issues"
                                className="rounded-full border border-warning/50 bg-warning/15 px-3 py-1 text-xs font-medium"
                            >
                                {"⚠ "
                                    + issues[0]
                                    + (
                                        " (+" + str(len(issues) - 1) + ")"
                                            if len(issues) > 1
                                            else ""
                                    )}
                            </span>
                        }}
                        <Button
                            key="add"
                            variant="outline"
                            onClick={addStep}
                            disabled={saving or creatingStep}
                        >
                            + Add step
                        </Button>
                        <Button
                            key="doneediting"
                            onClick={lambda {
                                editing = False;
                                renaming = False;
                                connectFrom = "";
                                selectedId = "";
                                selectedEdge = "";
                                confirmDelete = False;
                                creatingStep = False;
                            }}
                        >
                            Done editing
                        </Button>
                    </div>
                    {if connectFrom {
                        <div
                            key="connecting"
                            className="flex items-center justify-between gap-4 rounded-lg border border-dashed bg-muted p-3"
                        >
                            <p className="text-sm text-pretty">
                                <span className="font-medium">
                                    {"Drawing a transition out of "
                                        + connectTitle
                                        + "."}
                                </span>
                                <span className="text-muted-foreground">
                                    {" Click the step it flows into — backwards is fine,"
                                        + " loops are the point."}
                                </span>
                            </p>
                            <Button
                                size="sm"
                                variant="ghost"
                                onClick={lambda { connectFrom = ""; }}
                            >
                                Cancel
                            </Button>
                        </div>
                    }}
                    <div
                        className="grid items-start gap-6"
                        style={{"gridTemplateColumns": "minmax(0,1fr) 21rem"}}
                    >
                        <div
                            onMouseDown={beginDrag}
                            onMouseMove={moveDrag}
                            onMouseUp={endDrag}
                            onMouseLeave={endDrag}
                        >
                            <FlowCanvas
                                steps={steps}
                                live={live}
                                selectedId={selectedId}
                                connectFrom={connectFrom}
                                selectedEdge={selectedEdge}
                                canvasRef={canvasRef}
                                onSelect={selectStep}
                                onSelectEdge={lambda (k: str) { selectedEdge = k; }}
                                onDeleteEdge={deleteEdge}
                                onCanvasClick={clearCanvas}
                            />
                        </div>
                        <div className="flex flex-col gap-4">
                            {if creatingStep {
                                <div
                                    key="create"
                                    className="flex flex-col gap-3 rounded-lg border bg-card p-4"
                                >
                                    <div
                                        className="text-[11px] font-medium uppercase tracking-wider text-muted-foreground"
                                    >
                                        New step
                                    </div>
                                    <Input
                                        value={form["name"] or ""}
                                        placeholder="What should this step be called?"
                                        autoFocus={True}
                                        onChange={lambda (e: any) { setField(
                                            "name", e.target.value
                                        ); }}
                                        onKeyDown={lambda (e: any) { if e.key
                                            == "Enter" {
                                            commitName();
                                        }}}
                                    />
                                    <div className="flex gap-2">
                                        <Button
                                            size="sm"
                                            disabled={saving
                                                or not (form["name"] or "").strip()}
                                            onClick={commitName}
                                        >
                                            Add to canvas
                                        </Button>
                                        <Button
                                            size="sm"
                                            variant="ghost"
                                            onClick={lambda { creatingStep = False; }}
                                        >
                                            Cancel
                                        </Button>
                                    </div>
                                    <p className="text-xs text-muted-foreground">
                                        Kind and color can be set once it lands.
                                    </p>
                                </div>
                            } elif len(picked) > 0 {
                                <StepInspector
                                    key={picked[0].id}
                                    step={picked[0]}
                                    steps={steps}
                                    form={form}
                                    connecting={bool(connectFrom)}
                                    saving={saving}
                                    confirmingDelete={confirmDelete}
                                    onField={setField}
                                    onNameCommit={commitName}
                                    onConnect={armConnect}
                                    onCancelConnect={lambda { connectFrom = ""; }}
                                    onDelete={deleteStep}
                                    onUnlink={deleteEdge}
                                />
                            } else {
                                <div
                                    key="hint"
                                    className="rounded-lg border border-dashed p-6"
                                >
                                    <p className="text-sm font-medium">
                                        Nothing selected
                                    </p>
                                    <p
                                        className="mt-1 text-sm text-pretty text-muted-foreground"
                                    >
                                        Click a step to rename it, change what it means, or connect it onward.
                                    </p>
                                </div>
                            }  }
                            <div
                                className="flex flex-col gap-3 rounded-lg border bg-card p-4"
                            >
                                <h2 className="font-display text-sm font-semibold">
                                    Designing the flow
                                </h2>
                                <div className="flex flex-col gap-2">
                                    {for (i, line) in enumerate(HOW_TO) {
                                        <div
                                            key={str(i)}
                                            className="flex items-baseline gap-2"
                                        >
                                            <span
                                                className="text-xs font-medium tabular-nums text-muted-foreground"
                                            >
                                                {str(i + 1)}
                                            </span>
                                            <p
                                                className="text-xs text-pretty text-muted-foreground"
                                            >
                                                <span
                                                    className="font-medium text-foreground"
                                                >
                                                    {line[0]}
                                                </span>
                                                {" " + line[1]}
                                            </p>
                                        </div>
                                    }}
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            } else {
                <div key="viewer" className="flex flex-col gap-3">
                    <div className="flex flex-wrap items-center gap-3">
                        <h1
                            className="font-display text-2xl font-semibold tracking-tight"
                        >
                            {wfName}
                        </h1>
                        <span
                            className="rounded-full border px-3 py-1 text-xs text-muted-foreground"
                        >
                            {str(len(steps))
                                + " steps · "
                                + str(linkCount)
                                + " transitions"}
                        </span>
                        <div className="flex-1"/>
                        {if len(issues) > 0 {
                            <span
                                key="issues"
                                className="rounded-full border border-warning/50 bg-warning/15 px-3 py-1 text-xs font-medium"
                            >
                                {"⚠ " + issues[0]}
                            </span>
                        }}
                        <Button key="edit" onClick={lambda { editing = True; }}>
                            Edit workflow
                        </Button>
                    </div>
                    <div className="flex flex-wrap items-center gap-x-5 gap-y-2">
                        {for k in STEP_KINDS {
                            <span
                                key={k}
                                className="inline-flex items-center gap-1.5 text-xs text-muted-foreground"
                            >
                                <span
                                    className={"h-2 w-2 rounded-full "
                                        + DOT_FILL[KIND_COLORS[k]]}
                                />
                                {KIND_LABEL[k]}
                            </span>
                        }}
                    </div>
                    <FlowCanvas steps={steps}/>
                </div>
            }   }
        </div>;
}
