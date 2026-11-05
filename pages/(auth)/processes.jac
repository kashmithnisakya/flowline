"""Review user-supplied processes using the native canvas, controls and details.
Definitions and notes remain separate from operational workflow execution."""

import from "react" { useEffect }
import from ...models { ProcessView }
import from ...lib.processNotes { processNotesBusy }
import from ...services.processes.processes { ListProcesses, ImportProcessCatalog }
import from ...components.processes.ProcessMap { ProcessMap, nodeById }
import from ...components.processes.StepReview { StepReview }
import from ...components.processes.ProcessPolicies { ProcessPolicies }
import from ...components.flowlines.controls { Segmented }
import from ...components.flowlines.ZoomControls { ZoomControls }
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

glob VERSIONS: list[dict[str, str]] = [
         {"value": "current", "label": "Current"},
         {"value": "proposed", "label": "Proposed"},
         {"value": "compare", "label": "Compare", "aria": "Compare versions"}
     ],
     VIEWS: list[dict[str, str]] = [
         {"value": "diagram", "label": "Diagram"},
         {"value": "list", "label": "List"}
     ],
     PATHS: list[dict[str, str]] = [
         {"value": "main", "label": "Main path"},
         {"value": "all", "label": "All paths"}
     ];

def:pub ProcessesPage -> JsxPage {
    has processes: list[ProcessView] = [],
        family: str = "",
        importError: str = "",
        fileRef: Ref[any] = Ref(),
        importPending: Ref[bool] = Ref(False),
        variant: str = "current",
        compare: bool = False,
        view: str = "auto",
        paths: str = "main",
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
        workspaceHeight: float = 600.0,
        pageRef: Ref[any] = Ref(),
        workspaceRef: Ref[any] = Ref(),
        headingRef: Ref[any] = Ref(),
        returnFocus: Ref[any] = Ref(),
        jumpRef: Ref[any] = Ref(),
        readVersion: Ref[int] = Ref(0);

    async can with entry {
        w: any = window;
        params: any = new(w.URLSearchParams, w.location.search);
        if params.get("family") {
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
                    measureWorkspace();
                }
            );
            observer.observe(el);
            onResize = lambda { measureWorkspace(); };
            w.addEventListener("resize", onResize);
            return lambda {
                observer.disconnect();
                w.removeEventListener("resize", onResize);
            };
        },
        []
    );

    useEffect(lambda { fitDiagram(); }, [compare, availableWidth]);
    useEffect(
        lambda { measureWorkspace(); },
        [loading, tab, compare, availableWidth, len(processes)]
    );

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
        readVersion.current = readVersion.current + 1;
        version = readVersion.current;
        loading = True;
        error = "";
        try {
            result = root spawn ListProcesses();
            if version != readVersion.current {
                return;
            }
            processes = result.reports[0] if result.reports else [];
            families = [p.family for p in processes];
            if family not in families {
                family = families[0] if families else "";
            }
            variants = [
                p.variant
                for p in processes
                if p.family == family
            ];
            if variant not in variants and variants {
                variant = variants[0];
            }
            if len(variants) < 2 {
                compare = False;
            }
        } except Exception {
            if version != readVersion.current {
                return;
            }
            error = "Could not load the process library. Your saved work has not changed.";
        }
        loading = False;
        if not error {
            fitDiagram();
        }
    }

    def notesNeedSaving -> bool {
        if processNotesBusy() {
            return True;
        }
        for p in processes {
            prefix = p.id + ":";
            for key in drafts {
                if key.startswith(prefix)
                    and drafts[key].strip()
                        != p.review_notes.get(key[len(prefix):], "") {
                    return True;
                }
            }
        }
        return False;
    }

    def chooseCatalog {
        if importPending.current {
            return;
        }
        if notesNeedSaving() {
            importError = "Save or discard your review-note changes before importing definitions.";
            return;
        }
        if fileRef.current {
            fileRef.current.click();
        }
    }

    async def importCatalog(e: any) {
        if importPending.current {
            return;
        }
        inputEl: any = e.target;
        files: any = inputEl.files;
        if not files or len(files) == 0 {
            return;
        }
        file: any = files[0];
        if notesNeedSaving() {
            importError = "Save or discard your review-note changes before importing definitions.";
            inputEl.value = "";
            return;
        }
        importPending.current = True;
        busy = True;
        importError = "";
        try {
            if float(file.size) > 1048576 {
                raise ValueError("catalog_too_large");
            }
            content: str = await file.text();
            w: any = window;
            definitions = w.JSON.parse(content) as list[dict[str, any]];
            result = root spawn ImportProcessCatalog(definitions=definitions);
            data = result.reports[0] if result.reports else {};
            if data.get("ok", False) {
                await load();
                selectedId = "";
                panelOpen = False;
            } else {
                importError = "Could not import the catalog. Check its format, revisions and process groups; saved definitions and notes are unchanged.";
            }
        } except Exception {
            importError = "Could not import the catalog. Choose valid JSON no larger than 1 MiB and try again.";
        }
        inputEl.value = "";
        importPending.current = False;
        busy = False;
    }

    async def refreshNotes {
        readVersion.current = readVersion.current + 1;
        version = readVersion.current;
        try {
            result = root spawn ListProcesses();
        } except Exception {
            if version == readVersion.current and loading {
                loading = False;
                error = "Could not refresh the process library. Please try again.";
            }
            raise;
        }
        if version == readVersion.current {
            processes = result.reports[0] if result.reports else processes;
            loading = False;
            error = "";
        }
    }

    def rememberSelection {
        w: any = window;
        params: any = new(w.URLSearchParams);
        params.set("family", family);
        params.set("version", variant);
        if compare {
            params.set("compare", "1");
        }
        w.history.replaceState(None, "", "/processes?" + params.toString());
    }
    def pickFamily(value: str) {
        family = value;
        variants = [
            p.variant
            for p in processes
            if p.family == value
        ];
        if variant not in variants and variants {
            variant = variants[0];
        }
        if len(variants) < 2 {
            compare = False;
        }
        panelOpen = False;
        fitDiagram();
        rememberSelection();
    }
    def pickVersion(value: str) {
        compare = value == "compare";
        if not compare {
            variant = value;
        }
        panelOpen = False;
        fitDiagram();
        rememberSelection();
    }
    def setZoom(value: float) {
        zoom = max(0.3, min(1.5, value));
    }
    def measureWorkspace {
        el: any = workspaceRef.current;
        if not el {
            return;
        }
        w: any = window;
        doc: any = document;
        navigation = doc.querySelector("nav.fixed[aria-label=Pages]");
        bottom = float(navigation.getBoundingClientRect().height)
            if navigation
            else 0.0;
        top = float(el.getBoundingClientRect().top) + float(w.scrollY);
        height = max(320.0, float(w.innerHeight) - top - bottom - 16.0);
        if height != workspaceHeight {
            workspaceHeight = height;
        }
    }
    def fitDiagram {
        paneWidth = availableWidth / (2.0 if compare and not phone else 1.0);
        worldWidth = 760.0;
        for p in processes {
            if p.family == family and (compare or p.variant == variant) and p.steps {
                xs: list[float] = [float(s["x"]) for s in p.steps];
                padding = 300.0;
                if compare {
                    padding = 500.0;
                }
                if paths == "all" {
                    padding = 500.0;
                }
                worldWidth = max(worldWidth, max(xs) - min(xs) + padding);
            }
        }
        setZoom(min(1.0, (paneWidth - 56.0) / worldWidth));
        fitTick = fitTick + 1;
    }
    def showStep(value: str, version: str, focus: bool = False) {
        doc: any = document;
        if not panelOpen {
            returnFocus.current = jumpRef.current if focus else doc.activeElement;
        }
        selectedId = value;
        for p in processes {
            if p.family == family and p.variant == version {
                step = nodeById(p.steps, value);
                if step.get("path", "main") == "branch" {
                    paths = "all";
                }
            }
        }
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
        if not importPending.current {
            drafts = {** drafts, key: value};
        }
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
        or (view == "auto" and (phone or (compare and availableWidth < 1360.0)));
    families: list[str] = [];
    for process in processes {
        if process.family not in families {
            families.append(process.family);
        }
    }
    familyOptions = [{"value": name, "label": name} for name in families];
    versionIds = [
        p.variant
        for p in processes
        if p.family == family
    ];
    versionOptions = [
        v
        for v in VERSIONS
        if v["value"] in versionIds or (v["value"] == "compare" and len(versionIds) > 1)
    ];
    title = family or "Processes";
    sectionTitle = "Policies"
        if tab == "rules"
        else (
            "Earlier definitions & notes"
                if tab == "history"
                else ("Configuration" if tab == "setup" else "Capabilities")
        );
    modeLabel = "Current and proposed"
        if compare
        else ("Current" if variant == "current" else "Proposed");

    return
        <div ref={pageRef} className="process-library flex min-w-0 flex-col gap-4">
            <input
                ref={fileRef}
                type="file"
                accept=".json,application/json"
                aria-label="Choose process catalog"
                className="sr-only"
                disabled={busy}
                onChange={importCatalog}
            />
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
                    {if processes {
                        <Button
                            key="import"
                            variant="outline"
                            size="sm"
                            disabled={busy}
                            onClick={chooseCatalog}
                        >
                            {"Importing…" if busy else "Import process catalog"}
                        </Button>
                        <Segmented
                            key="families"
                            label="Process family"
                            options={familyOptions}
                            value={family}
                            onChange={pickFamily}
                        />
                        <Segmented
                            key="versions"
                            label="Process version"
                            options={versionOptions}
                            value={"compare" if compare else variant}
                            onChange={pickVersion}
                        />
                    }}
                </div>
            </header>
            {if importError {
                <p key="import-error" role="alert" className="text-sm text-destructive">
                    {importError}
                </p>
            }}
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
                    <h2 className="section-title">No processes yet</h2>
                    <p className="max-w-xl text-sm text-muted-foreground">
                        Import a JSON catalog from your computer. Definitions and review notes belong to this workspace; operational tasks are unaffected.
                    </p>
                    <Button disabled={busy} onClick={chooseCatalog}>
                        {"Importing…" if busy else "Import process catalog"}
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
                                <Segmented
                                    key="paths"
                                    label="Process paths"
                                    options={PATHS}
                                    value={paths}
                                    onChange={lambda (v: str) {
                                        paths = v;
                                        fitDiagram();
                                    }}
                                />
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
                                    Policies
                                </DropdownMenuItem>
                                <DropdownMenuItem
                                    onSelect={lambda { openSection("setup"); }}
                                >
                                    Configuration
                                </DropdownMenuItem>
                                <DropdownMenuItem
                                    onSelect={lambda { openSection("delivery"); }}
                                >
                                    Capabilities
                                </DropdownMenuItem>
                                <DropdownMenuItem
                                    onSelect={lambda { openSection("history"); }}
                                >
                                    Earlier definitions & notes
                                </DropdownMenuItem>
                            </DropdownMenuContent>
                        </DropdownMenu>
                    </div>
                    {if tab == "flow" {
                        <div
                            key="flow"
                            ref={workspaceRef}
                            style={{
                                "--process-workspace-height": str(workspaceHeight)
                                    + "px"
                            }}
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
                                                    + (
                                                        " steps · main path · v"
                                                            if not listView
                                                                and paths == "main"
                                                            else " steps · v"
                                                    )
                                                    + str(p.revision)}
                                            </p>
                                        </header>
                                        <ProcessMap
                                            process={p}
                                            selectedId={selectedId
                                                if p.variant == variant
                                                else ""}
                                            listView={listView}
                                            allPaths={paths == "all"}
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
                                    Review only. This library does not execute process steps.
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
                                        disabled={busy}
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
                                {"Previous definitions and saved review notes are read only. Updating definitions preserves this history."
                                    if tab == "history"
                                    else (
                                        "Policies describe this definition; displaying them does not enforce them."
                                            if variant == "current"
                                            else (
                                                "Configuration describes this definition; this review does not configure a project."
                                                    if tab == "setup"
                                                    else "These capabilities describe the process review library."
                                            )
                                    )}
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
                                    disabled={busy}
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
