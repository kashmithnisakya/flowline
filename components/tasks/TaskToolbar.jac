"""The Tasks page controls: `ScopeSwitch` (Working, Done, All, the rest under
More) and `TaskToolbar` (a live title search, Project, Assignee, Step and
Priority, the rest under More). A set filter reads "Label: value" with its own
clear button. Below md it folds into the search plus a Filters sheet."""

import from ...models { Project, MemberView }
import from ..common.StepName { StepName }
import from ..common.glyphs { Spinner }
import from ..ui.button { Button }
import from ..ui.dropdown_menu {
    DropdownMenu,
    DropdownMenuTrigger,
    DropdownMenuContent,
    DropdownMenuRadioGroup,
    DropdownMenuRadioItem,
    DropdownMenuSub,
    DropdownMenuSubTrigger,
    DropdownMenuSubContent
}
import from ..ui.select {
    Select,
    SelectTrigger,
    SelectValue,
    SelectContent,
    SelectItem
}
import from ..ui.sheet { Sheet, SheetContent, SheetHeader, SheetTitle }

glob MAIN_SCOPES: list[list[str]] = [
         ["working", "Working"],
         ["done", "Done"],
         ["all", "All"]
     ],
     MORE_SCOPES: list[list[str]] = [["attention", "Needs attention"]],
     PRIORITY_OPTIONS: list[list[str]] = [
         ["All", "Any priority"],
         ["High", "High"],
         ["Medium", "Medium"],
         ["Low", "Low"]
     ],
     ESTIMATE_OPTIONS: list[list[str]] = [
         ["All", "Any estimate"],
         ["yes", "Estimated"],
         ["no", "Unestimated"]
     ];

def Chevron -> JsxElement {
    return
        <svg
            width={14}
            height={14}
            viewBox="0 0 16 16"
            aria-hidden="true"
            className="shrink-0 opacity-80"
        >
            <path
                d="m4.5 6.5 3.5 3.5 3.5-3.5"
                fill="none"
                stroke="currentColor"
                strokeWidth={1.6}
                strokeLinecap="round"
                strokeLinejoin="round"
            />
        </svg>;
}

def Cross(size: int = 14) -> JsxElement {
    return
        <svg width={size} height={size} viewBox="0 0 16 16" aria-hidden="true">
            <path
                d="m4 4 8 8M12 4l-8 8"
                stroke="currentColor"
                strokeWidth={1.7}
                strokeLinecap="round"
            />
        </svg>;
}

def optionLabel(options: list[list[str]], value: str) -> str {
    for o in options {
        if o[0] == value {
            return o[1];
        }
    }
    return value;
}

# An option row: a step's swatch and name when the option carries a colour.
def OptionText(o: list[str]) -> JsxElement {
    if len(o) > 2 {
        return <StepName name={o[1]} color={o[2]}/>;
    }
    return <span className="truncate">{o[1]}</span>;
}

def segClass(on: bool) -> str {
    return "inline-flex h-7 items-center gap-1 rounded-sm px-2.5 text-[12.5px] whitespace-nowrap outline-none focus-visible:outline-2 focus-visible:outline-ring "
        + (
            "bg-muted font-semibold text-foreground"
                if on
                else "font-medium text-muted-foreground hover:text-foreground"
        );
}

def:pub ScopeSwitch(scope: str, onScope: Callable[[str], None]) -> JsxElement {
    extra = optionLabel(MORE_SCOPES, scope)
        if scope not in ["working", "done", "all"]
        else "";
    return
        <div
            role="group"
            aria-label="Scope"
            className="inline-flex items-center gap-0.5 rounded-md border bg-card p-0.5"
        >
            {for s in MAIN_SCOPES {
                <button
                    key={s[0]}
                    type="button"
                    aria-pressed={scope == s[0]}
                    className={segClass(scope == s[0])}
                    onClick={lambda { onScope(s[0]); }}
                >
                    {s[1]}
                </button>
            }}
            <DropdownMenu>
                <DropdownMenuTrigger
                    className={segClass(bool(extra))}
                    aria-label={("Scope: " + extra) if extra else "More scopes"}
                >
                    {extra or "More"}
                    <Chevron/>
                </DropdownMenuTrigger>
                <DropdownMenuContent
                    align="start"
                    collisionPadding={16}
                    className="w-48"
                >
                    <DropdownMenuRadioGroup value={scope} onValueChange={onScope}>
                        {for s in MORE_SCOPES {
                            <DropdownMenuRadioItem key={s[0]} value={s[0]}>
                                {s[1]}
                            </DropdownMenuRadioItem>
                        }}
                    </DropdownMenuRadioGroup>
                </DropdownMenuContent>
            </DropdownMenu>
        </div>;
}

# A ghost trigger that turns into "Label: value ×" once a value is picked.
def FilterMenu(
    label: str,
    value: str,
    allValue: str,
    options: list[list[str]],
    onChange: Callable[[str], None]
) -> JsxElement {
    active = value != allValue;
    return
        <DropdownMenu>
            {if active {
                <span
                    key="on"
                    className="toolbar-filter gap-0! pr-0.5!"
                    data-active="true"
                >
                    <DropdownMenuTrigger
                        className="inline-flex h-full max-w-56 items-center gap-1 rounded-sm outline-none focus-visible:outline-2 focus-visible:outline-ring"
                    >
                        <span className="truncate">
                            {label + ": " + optionLabel(options, value)}
                        </span>
                    </DropdownMenuTrigger>
                    <button
                        type="button"
                        aria-label={"Clear the " + label.lower() + " filter"}
                        className="ml-0.5 inline-flex size-6 items-center justify-center rounded-sm text-muted-foreground hover:bg-accent hover:text-foreground focus-visible:outline-2 focus-visible:outline-ring"
                        onClick={lambda { onChange(allValue); }}
                    >
                        <Cross/>
                    </button>
                </span>
            } else {
                <DropdownMenuTrigger key="off" className="toolbar-filter">
                    {label}
                    <Chevron/>
                </DropdownMenuTrigger>
            } }
            <DropdownMenuContent
                align="start"
                collisionPadding={16}
                className="max-h-80 w-56"
            >
                <DropdownMenuRadioGroup value={value} onValueChange={onChange}>
                    {for o in options {
                        <DropdownMenuRadioItem key={o[0]} value={o[0]}>
                            <OptionText o={o}/>
                        </DropdownMenuRadioItem>
                    }}
                </DropdownMenuRadioGroup>
            </DropdownMenuContent>
        </DropdownMenu>;
}

def SubMenu(
    label: str, value: str, options: list[list[str]], onChange: Callable[[str], None]
) -> JsxElement {
    return
        <DropdownMenuSub>
            <DropdownMenuSubTrigger>{label}</DropdownMenuSubTrigger>
            <DropdownMenuSubContent className="max-h-80 w-52 overflow-y-auto">
                <DropdownMenuRadioGroup value={value} onValueChange={onChange}>
                    {for o in options {
                        <DropdownMenuRadioItem key={o[0]} value={o[0]}>
                            {o[1]}
                        </DropdownMenuRadioItem>
                    }}
                </DropdownMenuRadioGroup>
            </DropdownMenuSubContent>
        </DropdownMenuSub>;
}

def SheetSelect(
    label: str, value: str, options: list[list[str]], onChange: Callable[[str], None]
) -> JsxElement {
    return
        <label className="grid gap-1.5">
            <span className="text-[13px] font-semibold">{label}</span>
            <Select value={value} onValueChange={onChange}>
                <SelectTrigger className="h-10 w-full" aria-label={label}>
                    <SelectValue/>
                </SelectTrigger>
                <SelectContent>
                    {for o in options {
                        <SelectItem key={o[0]} value={o[0]}>
                            <OptionText o={o}/>
                        </SelectItem>
                    }}
                </SelectContent>
            </Select>
        </label>;
}

def SearchBox(
    query: str, onQuery: Callable[[str], None], className: str
) -> JsxElement {
    return
        <label
            className={"flex items-center gap-1.5 rounded-md border border-input bg-card px-2 text-[13px] focus-within:outline-2 focus-within:outline-ring "
                + className}
        >
            <svg
                width={14}
                height={14}
                viewBox="0 0 16 16"
                aria-hidden="true"
                className="shrink-0 text-muted-foreground"
            >
                <circle
                    cx={7}
                    cy={7}
                    r={4.5}
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={1.6}
                />
                <path
                    d="m10.5 10.5 3 3"
                    stroke="currentColor"
                    strokeWidth={1.6}
                    strokeLinecap="round"
                />
            </svg>
            <input
                data-tasks-search="true"
                type="search"
                className="h-full min-w-0 flex-1 bg-transparent text-foreground outline-none placeholder:text-subtle focus-visible:outline-none [&::-webkit-search-cancel-button]:hidden"
                placeholder="Search titles"
                aria-label="Search task titles"
                value={query}
                onChange={lambda (e: ChangeEvent) { onQuery(e.target.value); }}
                onKeyDown={lambda (e: KeyboardEvent) { if e.key == "Escape" and query {
                    e.preventDefault();
                    onQuery("");
                }}}
            />
            {if query {
                <button
                    key="clear"
                    type="button"
                    aria-label="Clear the search"
                    className="inline-flex size-5 items-center justify-center rounded-sm text-muted-foreground hover:text-foreground"
                    onClick={lambda (e: MouseEvent) {
                        e.preventDefault();
                        onQuery("");
                    }}
                >
                    <Cross size={12}/>
                </button>
            } else {
                <span key="kbd" className="kbd max-md:hidden" aria-hidden="true">
                    /
                </span>
            } }
        </label>;
}

def:pub TaskToolbar(
    projects: list[Project],
    members: list[MemberView],
    steps: list[list[str]],
    project: str,
    assignee: str,
    step: str,
    priority: str,
    onProject: Callable[[str], None],
    onAssignee: Callable[[str], None],
    onStep: Callable[[str], None],
    onPriority: Callable[[str], None],
    query: str,
    onQuery: Callable[[str], None],
    onClear: Callable[[], None],
    categories: list[str] = [],
    tags: list[str] = [],
    category: str = "All",
    tag: str = "All",
    estimate: str = "All",
    onCategory: Callable[[str], None] = None,
    onTag: Callable[[str], None] = None,
    onEstimate: Callable[[str], None] = None,
    refreshing: bool = False,
    countLabel: str = "",
    # "Status" when the workspace has no flow line and the options are statuses.
    stepLabel: str = "Step"
) -> JsxElement {
    has sheetOpen: bool = False;

    projectOptions: list[list[str]] = [["all", "All projects"]];
    for p in projects {
        projectOptions.append([jid(p), p.name]);
    }
    assigneeOptions: list[list[str]] = [["All", "Everyone"]];
    for m in members {
        if project == "all" or project in m.project_ids {
            assigneeOptions.append([m.id, m.name]);
        }
    }
    stepOptions: list[list[str]] = [["All", "Any " + stepLabel.lower()]];
    for s in steps {
        stepOptions.append(s);
    }
    categoryOptions: list[list[str]] = [["All", "All categories"]];
    for c in categories {
        categoryOptions.append([c, c]);
    }
    tagOptions: list[list[str]] = [["All", "All tags"]];
    for tg in tags {
        tagOptions.append([tg, tg]);
    }

    def pickCategory(v: str) {
        if onCategory {
            onCategory(v);
        }
    }
    def pickTag(v: str) {
        if onTag {
            onTag(v);
        }
    }
    def pickEstimate(v: str) {
        if onEstimate {
            onEstimate(v);
        }
    }

    picked = 0;
    for on in [
        project != "all",
        assignee != "All",
        step != "All",
        priority != "All",
        category != "All",
        tag != "All",
        estimate != "All"
    ] {
        if on {
            picked = picked + 1;
        }
    }
    anything = picked > 0 or bool(query.strip());
    showTags = len(tags) > 0 or tag != "All";

    return
        <div className="min-w-0">
            <div className="toolbar hidden rounded-t-md border-t-0 md:flex">
                <SearchBox
                    query={query}
                    onQuery={onQuery}
                    className="h-[30px] w-[210px]"
                />
                <FilterMenu
                    label="Project"
                    value={project}
                    allValue="all"
                    options={projectOptions}
                    onChange={onProject}
                />
                <FilterMenu
                    label="Assignee"
                    value={assignee}
                    allValue="All"
                    options={assigneeOptions}
                    onChange={onAssignee}
                />
                <FilterMenu
                    label={stepLabel}
                    value={step}
                    allValue="All"
                    options={stepOptions}
                    onChange={onStep}
                />
                <FilterMenu
                    label="Priority"
                    value={priority}
                    allValue="All"
                    options={PRIORITY_OPTIONS}
                    onChange={onPriority}
                />
                {if category != "All" {
                    <FilterMenu
                        key="category"
                        label="Category"
                        value={category}
                        allValue="All"
                        options={categoryOptions}
                        onChange={pickCategory}
                    />
                }}
                {if tag != "All" {
                    <FilterMenu
                        key="tag"
                        label="Tag"
                        value={tag}
                        allValue="All"
                        options={tagOptions}
                        onChange={pickTag}
                    />
                }}
                {if estimate != "All" {
                    <FilterMenu
                        key="estimate"
                        label="Estimate"
                        value={estimate}
                        allValue="All"
                        options={ESTIMATE_OPTIONS}
                        onChange={pickEstimate}
                    />
                }}
                <DropdownMenu>
                    <DropdownMenuTrigger className="toolbar-filter">
                        More
                        <Chevron/>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent
                        align="start"
                        collisionPadding={16}
                        className="w-48"
                    >
                        <SubMenu
                            label="Category"
                            value={category}
                            options={categoryOptions}
                            onChange={pickCategory}
                        />
                        {if showTags {
                            <SubMenu
                                key="tags"
                                label="Tag"
                                value={tag}
                                options={tagOptions}
                                onChange={pickTag}
                            />
                        }}
                        <SubMenu
                            label="Estimate"
                            value={estimate}
                            options={ESTIMATE_OPTIONS}
                            onChange={pickEstimate}
                        />
                    </DropdownMenuContent>
                </DropdownMenu>
                {if anything {
                    <button
                        key="clearall"
                        type="button"
                        className="toolbar-filter text-primary! hover:bg-transparent! hover:underline"
                        onClick={lambda { onClear(); }}
                    >
                        Clear filters
                    </button>
                }}
                <span
                    role="status"
                    className="ml-auto inline-flex items-center gap-1.5 text-xs text-muted-foreground"
                >
                    {if refreshing {
                        <span key="busy" className="inline-flex items-center gap-1.5">
                            <Spinner/>
                            Updating
                        </span>
                    }}
                </span>
            </div>
            <div
                className="toolbar flex-nowrap rounded-t-md border-t-0 px-3 py-2.5 md:hidden"
            >
                <SearchBox
                    query={query}
                    onQuery={onQuery}
                    className="h-10 min-w-0 flex-1"
                />
                <Button
                    variant="outline"
                    className={"h-10 shrink-0 gap-1.5 px-3 "
                        + ("border-input! font-semibold" if picked > 0 else "")}
                    aria-haspopup="dialog"
                    onClick={lambda { sheetOpen = True; }}
                >
                    <svg width={14} height={14} viewBox="0 0 16 16" aria-hidden="true">
                        <path
                            d="M2.5 4h11M4.5 8h7M6.5 12h3"
                            stroke="currentColor"
                            strokeWidth={1.6}
                            strokeLinecap="round"
                        />
                    </svg>
                    Filters
                    {if picked > 0 {
                        <span key="n" className="num text-xs text-muted-foreground">
                            {str(picked)}
                        </span>
                    }}
                </Button>
            </div>
            <Sheet open={sheetOpen} onOpenChange={lambda (o: bool) { sheetOpen = o; }}>
                <SheetContent
                    side="bottom"
                    className="max-h-[85dvh] gap-0 overflow-y-auto rounded-t-xl p-0"
                >
                    <SheetHeader className="border-b px-4 py-3">
                        <SheetTitle className="text-base font-semibold">
                            Filters
                        </SheetTitle>
                    </SheetHeader>
                    <div className="grid gap-3 px-4 py-4">
                        <SheetSelect
                            label="Project"
                            value={project}
                            options={projectOptions}
                            onChange={onProject}
                        />
                        <SheetSelect
                            label="Assignee"
                            value={assignee}
                            options={assigneeOptions}
                            onChange={onAssignee}
                        />
                        <SheetSelect
                            label={stepLabel}
                            value={step}
                            options={stepOptions}
                            onChange={onStep}
                        />
                        <SheetSelect
                            label="Priority"
                            value={priority}
                            options={PRIORITY_OPTIONS}
                            onChange={onPriority}
                        />
                        <SheetSelect
                            label="Category"
                            value={category}
                            options={categoryOptions}
                            onChange={pickCategory}
                        />
                        {if showTags {
                            <SheetSelect
                                key="tag"
                                label="Tag"
                                value={tag}
                                options={tagOptions}
                                onChange={pickTag}
                            />
                        }}
                        <SheetSelect
                            label="Estimate"
                            value={estimate}
                            options={ESTIMATE_OPTIONS}
                            onChange={pickEstimate}
                        />
                    </div>
                    <div
                        className="flex items-center gap-2 border-t px-4 py-3 pb-[calc(0.75rem+env(safe-area-inset-bottom))]"
                    >
                        <span className="num text-xs text-muted-foreground">
                            {countLabel}
                        </span>
                        {if anything {
                            <Button
                                key="clear"
                                variant="ghost"
                                className="ml-auto h-10"
                                onClick={lambda { onClear(); }}
                            >
                                Clear filters
                            </Button>
                        }}
                        <Button
                            className={"h-10 " + ("" if anything else "ml-auto")}
                            onClick={lambda { sheetOpen = False; }}
                        >
                            Show tasks
                        </Button>
                    </div>
                </SheetContent>
            </Sheet>
        </div>;
}
