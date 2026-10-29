"""Review saved delivery flows using the native canvas, controls and details.
Definitions and notes remain separate from operational workflow execution."""

import from "react" { useEffect }
import from ...models { ProcessView }
import from ...services.processes.processes { ListProcesses, InstallProcessExamples }
import from ...components.processes.ProcessMap { ProcessMap, nodeById }
import from ...components.processes.StepReview { StepReview }
import from ...components.processes.ProcessPolicies { ProcessPolicies }
import from ...components.flowlines.controls { Segmented, ZoomControls }
import from ...components.ui.button { Button }
import from ...components.ui.skeleton { Skeleton }
import from ...components.ui.select {
    Select,
    SelectTrigger,
    SelectContent,
    SelectItem,
    SelectGroup,
    SelectLabel
}
import from ...components.ui.dropdown_menu {
    DropdownMenu,
    DropdownMenuTrigger,
    DropdownMenuContent,
    DropdownMenuItem
}
import from ...components.ui.sheet { Sheet, SheetContent, SheetTitle, SheetDescription }
import from ...components.common.LoadFailed { LoadFailed }
import from ...lib.workspace { loadWorkspace }

glob FAMILIES: list[dict[str, str]] = [
         {"value": "react", "label": "React migration"},
         {"value": "bau", "label": "BAU"}
     ],
     VERSIONS: list[dict[str, str]] = [
         {"value": "current", "label": "Current"},
         {"value": "proposed", "label": "Proposed"},
         {"value": "compare", "label": "Compare", "aria": "Compare versions"}
     ],
     VIEWS: list[dict[str, str]] = [
         {"value": "diagram", "label": "Diagram"},
         {"value": "list", "label": "List"}
     ];

def:pub ProcessesPage -> JsxPage {
    has processes: list[ProcessView] = [],
        family: str = "react",
        variant: str = "current",
        compare: bool = False,
        view: str = "auto",
        tab: str = "flow",
        selectedId: str = "",
        loading: bool = True,
        busy: bool = False,
        error: str = "",
        panelOpen: bool = False,
        drafts: dict[str, str] = {},
        zoom: float = 0.75,
        fitTick: int = 0,
        focusTick: int = 0,
        phone: bool = False,
        availableWidth: float = 1200.0,
        pageRef: Ref[any] = Ref(),
        headingRef: Ref[any] = Ref(),
        returnFocus: Ref[any] = Ref(),
        jumpRef: Ref[any] = Ref();

    async can with entry {
        w: any = window;
        params: any = new(w.URLSearchParams, w.location.search);
        if params.get("family") in ["react", "bau"] {
            family = str(params.get("family"));
        }
        if params.get("version") in ["current", "proposed"] {
            variant = str(params.get("version"));
        }
        compare = params.get("compare") == "1";
        load();
        loadWorkspace();
    }

    useEffect(
        lambda {
            el = pageRef.current;
            if not el {
                return;
            }
            w: any = window;
            observer = new(
                w.ResizeObserver,
                lambda {
                    availableWidth = float(el.clientWidth);
                    phone = bool(w.innerWidth < 640);
                }
            );
            observer.observe(el);
            return lambda { observer.disconnect(); };
        },
        []
    );

    useEffect(lambda { fitDiagram(); }, [compare, availableWidth]);

    useEffect(
        lambda {
            w: any = window;
            handler = lambda (e: any) {
                target: any = e.target;
                if e.key == "Escape"
                    and panelOpen
                    and not phone
                    and not target.closest("input,textarea,[role=dialog]") {
                    e.preventDefault();
                    closeReview();
                }
            };
            w.addEventListener("keydown", handler);
            return lambda { w.removeEventListener("keydown", handler); };
        },
        [panelOpen, phone]
    );

    async def load {
        loading = True;
        error = "";
        try {
            result = root spawn ListProcesses();
            processes = result.reports[0] if result.reports else [];
        } except Exception {
            error = "Could not load the process library. Your saved work has not changed.";
        }
        loading = False;
    }

    async def install {
        busy = True;
        error = "";
        try {
            result = root spawn InstallProcessExamples();
            data = result.reports[0] if result.reports else {};
            if data.get("ok", False) {
                await load();
            } else {
                error = "Could not install the examples. Please try again.";
            }
        } except Exception {
            error = "Could not install the examples. Please try again.";
        }
        busy = False;
    }

    async def refreshNotes {
        result = root spawn ListProcesses();
        processes = result.reports[0] if result.reports else processes;
    }

    def rememberSelection {
        window.history.replaceState(
            None,
            "",
            "/processes?family="
                + family
                + "&version="
                + variant
                + ("&compare=1" if compare else "")
        );
    }
    def pickFamily(value: str) {
        family = value;
        panelOpen = False;
        fitTick = fitTick + 1;
        rememberSelection();
    }
    def pickVersion(value: str) {
        compare = value == "compare";
        if not compare {
            variant = value;
        }
        panelOpen = False;
        rememberSelection();
    }
    def setZoom(value: float) {
        zoom = max(0.3, min(1.5, value));
    }
    def fitDiagram {
        paneWidth = availableWidth / (2.0 if compare and not phone else 1.0);
        setZoom(min(1.0, (paneWidth - 56.0) / 760.0));
        fitTick = fitTick + 1;
    }
    def showStep(value: str, version: str, focus: bool = False) {
        doc: any = document;
        if not panelOpen {
            returnFocus.current = jumpRef.current if focus else doc.activeElement;
        }
        selectedId = value;
        variant = version;
        panelOpen = True;
        if focus {
            focusTick = focusTick + 1;
        }
        rememberSelection();
    }
    def closeReview {
        panelOpen = False;
        restoreFocus();
    }
    def restoreFocus {
        el = returnFocus.current;
        if el and el.isConnected {
            el.focus();
        } elif headingRef.current {
            headingRef.current.focus();
        }
    }
    def updateDraft(key: str, value: str) {
        drafts = {** drafts, key: value};
    }
    def openSection(value: str) {
        tab = value;
        panelOpen = False;
    }

    visible = [
        p
        for p in processes
        if p.family == family and (compare or p.variant == variant)
    ];
    picked = [
        p
        for p in processes
        if p.family == family and p.variant == variant
    ];
    active = picked[0] if picked else None;
    selected = nodeById(active.steps, selectedId) if active else {};
    draftKey = active.id + ":" + selectedId if active else "";
    storedNote = active.review_notes[selectedId]
        if active and selectedId in active.review_notes
        else "";
    note = drafts[draftKey] if draftKey in drafts else storedNote;
    listView = view == "list"
        or (view == "auto" and (phone or (compare and availableWidth < 960.0)));
    title = "React migration process" if family == "react" else "BAU process";
    sectionTitle = "Shared QA & rules"
        if tab == "rules"
        else ("To configure" if tab == "setup" else "Build stages");
    modeLabel = "Current and proposed"
        if compare
        else ("Current" if variant == "current" else "Proposed");

    return
        <div ref={pageRef} className="process-library flex min-w-0 flex-col gap-4">
            <header
                className="flex min-w-0 flex-wrap items-end justify-between gap-x-6 gap-y-3"
            >
                <div className="min-w-0">
                    <p className="meta mb-1">Process review</p>
                    <h1
                        ref={headingRef}
                        tabIndex={-1}
                        className="page-title outline-none"
                    >
                        {title}
                    </h1>
                    <p className="mt-1 text-[13px] text-muted-foreground">
                        {modeLabel + " · Review only"}
                    </p>
                </div>
                <div className="flex min-w-0 flex-wrap items-center gap-2">
                    <Segmented
                        label="Process family"
                        options={FAMILIES}
                        value={family}
                        onChange={pickFamily}
                    />
                    <Segmented
                        label="Process version"
                        options={VERSIONS}
                        value={"compare" if compare else variant}
                        onChange={pickVersion}
                    />
                </div>
            </header>
            {if loading {
                <div
                    key="loading"
                    className="surface flex flex-col gap-4 p-4"
                    role="status"
                    aria-label="Loading process library"
                >
                    <Skeleton className="h-8 w-64"/>
                    <Skeleton className="h-[28rem] w-full"/>
                </div>
            } elif error {
                <LoadFailed
                    key="error"
                    title="Could not load the process library"
                    detail={error}
                    onRetry={load}
                />
            } elif not processes {
                <section
                    key="empty"
                    className="surface flex flex-col items-start gap-4 p-6"
                >
                    <h2 className="section-title">Four flows to review</h2>
                    <p className="max-w-xl text-sm text-muted-foreground">
                        Add the current and proposed React migration and BAU flows. Review their steps and save notes; automation remains planned.
                    </p>
                    <Button disabled={busy} onClick={install}>
                        {"Installing…" if busy else "Add the four example flows"}
                    </Button>
                </section>
            } elif active {
                <div key="library" className="flex min-w-0 flex-col gap-4">
                    <div className="flex min-w-0 flex-wrap items-center gap-2">
                        {if tab == "flow" {
                            <Segmented
                                key="view"
                                label="Flow view"
                                options={VIEWS}
                                value={"list" if listView else "diagram"}
                                onChange={lambda (v: str) { view = v; }}
                            />
                            if not listView {
                                <ZoomControls
                                    key="zoom"
                                    zoom={zoom}
                                    fitTitle="Fit diagram width (F)"
                                    onOut={lambda { setZoom(zoom / 1.2); }}
                                    onIn={lambda { setZoom(zoom * 1.2); }}
                                    onActual={lambda { setZoom(1.0); }}
                                    onFit={fitDiagram}
                                />
                            }
                            <Select
                                key="jump"
                                value=""
                                onValueChange={lambda (v: str) {
                                    parts = v.split(":");
                                    showStep(parts[1], parts[0], True);
                                }}
                            >
                                <SelectTrigger
                                    ref={jumpRef}
                                    aria-label="Jump to step"
                                    size="sm"
                                    className="ml-auto max-w-[min(15rem,100%)] bg-background"
                                >
                                    <span className="truncate">Jump to step</span>
                                </SelectTrigger>
                                <SelectContent position="popper" align="end">
                                    {for p in visible {
                                        <SelectGroup key={p.id}>
                                            <SelectLabel>
                                                {"Current"
                                                    if p.variant == "current"
                                                    else "Proposed"}
                                            </SelectLabel>
                                            {for step in p.steps {
                                                <SelectItem
                                                    key={step["id"]}
                                                    value={p.variant + ":" + step["id"]}
                                                >
                                                    {step["title"]}
                                                </SelectItem>
                                            }}
                                        </SelectGroup>
                                    }}
                                </SelectContent>
                            </Select>
                        } else {
                            <h2 key="section" className="section-title">
                                {sectionTitle}
                            </h2>
                            <Button
                                key="back"
                                variant="ghost"
                                size="sm"
                                className="ml-auto"
                                onClick={lambda { openSection("flow"); }}
                            >
                                Back to flow
                            </Button>
                        } }
                        <DropdownMenu>
                            <DropdownMenuTrigger asChild={True}>
                                <Button variant="ghost" size="sm">
                                    Review options
                                </Button>
                            </DropdownMenuTrigger>
                            <DropdownMenuContent align="end">
                                <DropdownMenuItem
                                    onSelect={lambda { openSection("rules"); }}
                                >
                                    Shared QA & rules
                                </DropdownMenuItem>
                                <DropdownMenuItem
                                    onSelect={lambda { openSection("setup"); }}
                                >
                                    To configure
                                </DropdownMenuItem>
                                <DropdownMenuItem
                                    onSelect={lambda { openSection("delivery"); }}
                                >
                                    Build stages
                                </DropdownMenuItem>
                            </DropdownMenuContent>
                        </DropdownMenu>
                    </div>
                    {if tab == "flow" {
                        <div
                            key="flow"
                            className="surface process-workspace relative flex min-w-0 flex-col overflow-hidden rounded-2xl"
                        >
                            <div
                                className={"process-diagrams min-h-0 flex-1 "
                                    + ("is-comparing" if compare else "")}
                            >
                                {for p in visible {
                                    <section
                                        key={p.id}
                                        className="process-diagram-panel flex min-h-0 min-w-0 flex-col"
                                        aria-label={p.title}
                                    >
                                        <header
                                            className="flex items-center justify-between gap-2 border-b border-border-subtle px-4 py-2"
                                        >
                                            <h2 className="text-[13px] font-semibold">
                                                {"Current"
                                                    if p.variant == "current"
                                                    else "Proposed"}
                                            </h2>
                                            <p
                                                className="num text-xs text-text-tertiary"
                                            >
                                                {str(len(p.steps))
                                                    + " steps · v"
                                                    + str(p.revision)}
                                            </p>
                                        </header>
                                        <ProcessMap
                                            process={p}
                                            selectedId={selectedId
                                                if p.variant == variant
                                                else ""}
                                            listView={listView}
                                            zoom={zoom}
                                            fitTick={fitTick}
                                            focusTick={focusTick}
                                            focusId={selectedId}
                                            onZoom={setZoom}
                                            onFit={fitDiagram}
                                            onSelect={lambda (value: str) { showStep(
                                                value, p.variant
                                            ); }}
                                        />
                                    </section>
                                }}
                            </div>
                            <footer
                                className="flex flex-wrap items-center gap-x-4 gap-y-1 border-t px-4 py-2 text-xs text-muted-foreground"
                            >
                                <span>
                                    Review only. Agents, QA execution, timers and integrations are unfinished.
                                </span>
                                <span className="ml-auto">
                                    {"Select a step to inspect"
                                        if listView
                                        else "Drag or scroll to pan · F fits width"}
                                </span>
                            </footer>
                            {if panelOpen and selected and not phone {
                                <div
                                    key="inspector"
                                    className="process-floating-panel absolute top-3 right-3 z-40 flex w-[22rem] max-w-[calc(100%-1.5rem)] flex-col overflow-hidden rounded-2xl bg-card shadow-xl ring-1 ring-border"
                                >
                                    <StepReview
                                        key={draftKey}
                                        process={active}
                                        step={selected}
                                        note={note}
                                        onNote={lambda (v: str) { updateDraft(
                                            draftKey, v
                                        ); }}
                                        onSaved={refreshNotes}
                                        onJump={lambda (v: str) { showStep(
                                            v, variant, True
                                        ); }}
                                        onClose={closeReview}
                                    />
                                </div>
                            }}
                        </div>
                    } else {
                        <div key="requirements" className="flex flex-col gap-3">
                            <p className="text-[13px] text-muted-foreground">
                                {"Required values remain unset. This review does not configure a project."
                                    if tab == "setup"
                                    else "These requirements describe the delivery process. Automated enforcement is planned."}
                            </p>
                            <ProcessPolicies process={active} section={tab}/>
                        </div>
                    } }
                    <Sheet
                        open={phone and panelOpen and bool(selected)}
                        onOpenChange={lambda (open_: bool) { if not open_ {
                            closeReview();
                        }}}
                    >
                        <SheetContent
                            side="bottom"
                            showCloseButton={False}
                            className="h-[85dvh] max-h-[85dvh] gap-0 p-0"
                            onCloseAutoFocus={lambda (e: any) {
                                e.preventDefault();
                                restoreFocus();
                            }}
                        >
                            <SheetTitle className="sr-only">Step details</SheetTitle>
                            <SheetDescription className="sr-only">
                                Review intended behavior and save a note. This does not execute the step.
                            </SheetDescription>
                            {if selected {
                                <StepReview
                                    key={draftKey}
                                    process={active}
                                    step={selected}
                                    note={note}
                                    onNote={lambda (v: str) { updateDraft(
                                        draftKey, v
                                    ); }}
                                    onSaved={refreshNotes}
                                    onJump={lambda (v: str) { showStep(
                                        v, variant, True
                                    ); }}
                                    onClose={closeReview}
                                />
                            }}
                        </SheetContent>
                    </Sheet>
                </div>
            }   }
        </div>;
}
