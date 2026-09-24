"""The board toolbar: a title filter, Project, Assignee and Priority, the rest
under More, and on the right the Done window and the task count. An active
filter reads as an outlined "Label: value" with a clear button. Below md it
folds into the title filter plus a Filters button that opens a sheet."""

import from ...models { Project, MemberView, IterationView }
import from ..ui.checkbox { Checkbox }
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
import from ..ui.skeleton { Skeleton }

glob CHEVRON_D: str = "m4.5 6.5 3.5 3.5 3.5-3.5";

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
                d={CHEVRON_D}
                fill="none"
                stroke="currentColor"
                strokeWidth={1.6}
                strokeLinecap="round"
                strokeLinejoin="round"
            />
        </svg>;
}

# One option list, shared by the desktop menus and the phone sheet's selects.
def optionLabel(options: list[list[str]], value: str) -> str {
    for o in options {
        if o[0] == value {
            return o[1];
        }
    }
    return value;
}

# A ghost trigger that turns into "Label: value ×" once a value is picked.
# `fixed` is a scope, not a filter: the trigger names the pick and never
# offers to clear it (the board's project).
def FilterMenu(
    label: str,
    value: str,
    allValue: str,
    options: list[list[str]],
    onChange: Callable[[str], None],
    fixed: bool = False
) -> JsxElement {
    active = value != allValue and not fixed;
    shown = optionLabel(options, value) if value else label;
    return
        <DropdownMenu>
            {if active {
                <span
                    key="on"
                    className="toolbar-filter gap-0! pr-0.5!"
                    data-active="true"
                >
                    <DropdownMenuTrigger
                        className="inline-flex h-full max-w-56 items-center gap-1 rounded-sm outline-none focus-visible:outline-2 focus-visible:outline-solid focus-visible:outline-ring"
                    >
                        <span className="truncate">{label + ": " + shown}</span>
                    </DropdownMenuTrigger>
                    <button
                        type="button"
                        aria-label={"Clear the " + label.lower() + " filter"}
                        className="ml-0.5 inline-flex size-6 items-center justify-center rounded-sm text-subtle hover:bg-accent hover:text-foreground"
                        onClick={lambda { onChange(allValue); }}
                    >
                        <svg
                            width={14}
                            height={14}
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
                </span>
            } else {
                <DropdownMenuTrigger
                    key="off"
                    className="toolbar-filter"
                    data-active={"true" if fixed else "false"}
                >
                    {shown if fixed else label}
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
                            <span className="truncate">{o[1]}</span>
                        </DropdownMenuRadioItem>
                    }}
                </DropdownMenuRadioGroup>
            </DropdownMenuContent>
        </DropdownMenu>;
}

def SheetSelect(
    label: str, value: str, options: list[list[str]], onChange: Callable[[str], None]
) -> JsxElement {
    return
        <label className="grid gap-1.5">
            <span className="text-[13px] font-semibold">{label}</span>
            <Select value={value} onValueChange={onChange}>
                <SelectTrigger className="h-9 w-full" aria-label={label}>
                    <SelectValue/>
                </SelectTrigger>
                <SelectContent>
                    {for o in options {
                        <SelectItem key={o[0]} value={o[0]}>{o[1]}</SelectItem>
                    }}
                </SelectContent>
            </Select>
        </label>;
}

def:pub FilterBar(
    projects: list[Project],
    members: list[MemberView],
    project: str,
    assignee: str,
    category: str,
    hideDone: bool,
    onProject: Callable[[str], None],
    onAssignee: Callable[[str], None],
    onCategory: Callable[[str], None],
    onHideDone: Callable[[], None],
    categories: list[str] = [],
    tags: list[str] = [],
    tag: str = "All",
    estimate: str = "All",
    onTag: Callable[[str], None] = None,
    onEstimate: Callable[[str], None] = None,
    # "All", "current", "none" or an iteration jid; hidden with none defined.
    iterations: list[IterationView] = [],
    iteration: str = "All",
    onIteration: Callable[[str], None] = None,
    priority: str = "All",
    onPriority: Callable[[str], None] = None,
    query: str = "",
    onQuery: Callable[[str], None] = None,
    onClear: Callable[[], None] = None,
    shownCount: int = 0,
    doneDays: int = 7,
    # The first load: the count is not known yet, so its slot holds a block.
    busy: bool = False
) -> JsxElement {
    has sheetOpen: bool = False;

    shownMembers = [
        m
        for m in members
        if not project or project in m.project_ids
    ];
    projectOptions: list[list[str]] = [];
    for p in projects {
        projectOptions.append([jid(p), p.name]);
    }
    assigneeOptions: list[list[str]] = [["All", "Everyone"]];
    for m in shownMembers {
        assigneeOptions.append([m.id, m.name]);
    }
    priorityOptions: list[list[str]] = [
        ["All", "Any priority"],
        ["High", "High"],
        ["Medium", "Medium"],
        ["Low", "Low"]
    ];
    categoryOptions: list[list[str]] = [["All", "All categories"]];
    for c in categories {
        categoryOptions.append([c, c]);
    }
    tagOptions: list[list[str]] = [["All", "All tags"]];
    for tg in tags {
        tagOptions.append([tg, tg]);
    }
    estimateOptions: list[list[str]] = [
        ["All", "Any estimate"],
        ["yes", "Estimated"],
        ["no", "Unestimated"]
    ];
    iterationOptions: list[list[str]] = [
        ["All", "All iterations"],
        ["current", "Current iteration"]
    ];
    for it in iterations {
        iterationOptions.append([it.id, it.name]);
    }
    iterationOptions.append(["none", "No iteration"]);

    def setTag(v: str) {
        if onTag {
            onTag(v);
        }
    }
    def setEstimate(v: str) {
        if onEstimate {
            onEstimate(v);
        }
    }
    def setIteration(v: str) {
        if onIteration {
            onIteration(v);
        }
    }
    def setPriority(v: str) {
        if onPriority {
            onPriority(v);
        }
    }
    def setQuery(v: str) {
        if onQuery {
            onQuery(v);
        }
    }
    def clearAll {
        if onClear {
            onClear();
        }
    }

    picked = 0;
    for on in [
        assignee != "All",
        priority != "All",
        category != "All",
        tag != "All",
        estimate != "All",
        iteration != "All"
    ] {
        if on {
            picked = picked + 1;
        }
    }
    anything = picked > 0 or bool(query.strip());
    showTags = len(tags) > 0 or tag != "All";
    showIterations = len(iterations) > 0 or iteration != "All";
    countLabel = str(shownCount) + (" task" if shownCount == 1 else " tasks");
    doneLabel = "Done from last " + str(doneDays) + " days";

    def SearchBox(extra: str) -> JsxElement {
        return
            <label
                className={"flex h-[30px] items-center gap-1.5 rounded-md border border-input bg-card px-2 text-[13px] focus-within:outline-2 focus-within:outline-ring "
                    + extra}
            >
                <svg
                    width={14}
                    height={14}
                    viewBox="0 0 16 16"
                    aria-hidden="true"
                    className="shrink-0 text-subtle"
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
                    data-board-search="true"
                    className="h-full min-w-0 flex-1 bg-transparent text-foreground outline-none placeholder:text-subtle focus-visible:outline-none"
                    placeholder="Filter by title"
                    aria-label="Filter by title or issue number"
                    value={query}
                    onChange={lambda (e: ChangeEvent) { setQuery(e.target.value); }}
                    onKeyDown={lambda (e: KeyboardEvent) { if e.key == "Escape"
                        and query {
                        e.preventDefault();
                        setQuery("");
                    }}}
                />
                {if query {
                    <button
                        key="clear"
                        type="button"
                        aria-label="Clear the title filter"
                        className="inline-flex size-5 items-center justify-center rounded-sm text-subtle hover:text-foreground"
                        onClick={lambda (e: MouseEvent) {
                            e.preventDefault();
                            setQuery("");
                        }}
                    >
                        <svg
                            width={12}
                            height={12}
                            viewBox="0 0 16 16"
                            aria-hidden="true"
                        >
                            <path
                                d="m4 4 8 8M12 4l-8 8"
                                stroke="currentColor"
                                strokeWidth={1.8}
                                strokeLinecap="round"
                            />
                        </svg>
                    </button>
                } else {
                    <span key="kbd" className="kbd max-md:hidden" aria-hidden="true">
                        /
                    </span>
                } }
            </label>;
    }

    return
        <div className="min-w-0">
            <div
                data-board-toolbar="true"
                className="toolbar hidden rounded-md border-x md:flex"
            >
                {SearchBox("w-[210px]")}
                <FilterMenu
                    label="Project"
                    value={project}
                    allValue=""
                    options={projectOptions}
                    onChange={onProject}
                    fixed={True}
                />
                <FilterMenu
                    label="Assignee"
                    value={assignee}
                    allValue="All"
                    options={assigneeOptions}
                    onChange={onAssignee}
                />
                <FilterMenu
                    label="Priority"
                    value={priority}
                    allValue="All"
                    options={priorityOptions}
                    onChange={setPriority}
                />
                {if category != "All" {
                    <FilterMenu
                        key="category"
                        label="Category"
                        value={category}
                        allValue="All"
                        options={categoryOptions}
                        onChange={onCategory}
                    />
                }}
                {if tag != "All" {
                    <FilterMenu
                        key="tag"
                        label="Tag"
                        value={tag}
                        allValue="All"
                        options={tagOptions}
                        onChange={setTag}
                    />
                }}
                {if estimate != "All" {
                    <FilterMenu
                        key="estimate"
                        label="Estimate"
                        value={estimate}
                        allValue="All"
                        options={estimateOptions}
                        onChange={setEstimate}
                    />
                }}
                {if iteration != "All" {
                    <FilterMenu
                        key="iteration"
                        label="Iteration"
                        value={iteration}
                        allValue="All"
                        options={iterationOptions}
                        onChange={setIteration}
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
                        <DropdownMenuSub>
                            <DropdownMenuSubTrigger>Category</DropdownMenuSubTrigger>
                            <DropdownMenuSubContent
                                className="max-h-80 w-52 overflow-y-auto"
                            >
                                <DropdownMenuRadioGroup
                                    value={category}
                                    onValueChange={onCategory}
                                >
                                    {for o in categoryOptions {
                                        <DropdownMenuRadioItem key={o[0]} value={o[0]}>
                                            {o[1]}
                                        </DropdownMenuRadioItem>
                                    }}
                                </DropdownMenuRadioGroup>
                            </DropdownMenuSubContent>
                        </DropdownMenuSub>
                        {if showTags {
                            <DropdownMenuSub key="tags">
                                <DropdownMenuSubTrigger>Tag</DropdownMenuSubTrigger>
                                <DropdownMenuSubContent
                                    className="max-h-80 w-52 overflow-y-auto"
                                >
                                    <DropdownMenuRadioGroup
                                        value={tag}
                                        onValueChange={setTag}
                                    >
                                        {for o in tagOptions {
                                            <DropdownMenuRadioItem
                                                key={o[0]}
                                                value={o[0]}
                                            >
                                                {o[1]}
                                            </DropdownMenuRadioItem>
                                        }}
                                    </DropdownMenuRadioGroup>
                                </DropdownMenuSubContent>
                            </DropdownMenuSub>
                        }}
                        <DropdownMenuSub>
                            <DropdownMenuSubTrigger>Estimate</DropdownMenuSubTrigger>
                            <DropdownMenuSubContent className="w-44">
                                <DropdownMenuRadioGroup
                                    value={estimate}
                                    onValueChange={setEstimate}
                                >
                                    {for o in estimateOptions {
                                        <DropdownMenuRadioItem key={o[0]} value={o[0]}>
                                            {o[1]}
                                        </DropdownMenuRadioItem>
                                    }}
                                </DropdownMenuRadioGroup>
                            </DropdownMenuSubContent>
                        </DropdownMenuSub>
                        {if showIterations {
                            <DropdownMenuSub key="iterations">
                                <DropdownMenuSubTrigger>
                                    Iteration
                                </DropdownMenuSubTrigger>
                                <DropdownMenuSubContent
                                    className="max-h-80 w-52 overflow-y-auto"
                                >
                                    <DropdownMenuRadioGroup
                                        value={iteration}
                                        onValueChange={setIteration}
                                    >
                                        {for o in iterationOptions {
                                            <DropdownMenuRadioItem
                                                key={o[0]}
                                                value={o[0]}
                                            >
                                                {o[1]}
                                            </DropdownMenuRadioItem>
                                        }}
                                    </DropdownMenuRadioGroup>
                                </DropdownMenuSubContent>
                            </DropdownMenuSub>
                        }}
                    </DropdownMenuContent>
                </DropdownMenu>
                {if anything {
                    <button
                        key="clearall"
                        type="button"
                        className="toolbar-filter text-primary! hover:bg-transparent! hover:underline"
                        onClick={lambda { clearAll(); }}
                    >
                        Clear filters
                    </button>
                }}
                <div
                    className="ml-auto flex items-center gap-3 text-[12.5px] text-muted-foreground"
                >
                    <label
                        className="flex cursor-pointer items-center gap-2 whitespace-nowrap"
                    >
                        <Checkbox
                            checked={not hideDone}
                            onCheckedChange={lambda { onHideDone(); }}
                        />
                        {doneLabel}
                    </label>
                    {if busy {
                        <Skeleton key="count" className="h-3 w-14"/>
                    } else {
                        <span key="count" className="num text-xs whitespace-nowrap">
                            {countLabel}
                        </span>
                    } }
                </div>
            </div>
            <div className="flex items-center gap-2 md:hidden">
                {SearchBox("h-9 min-w-0 flex-1")}
                <Button
                    variant="outline"
                    className={"h-9 shrink-0 gap-1.5 "
                        + ("border-input! font-semibold" if picked > 0 else "")}
                    onClick={lambda { sheetOpen = True; }}
                >
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
                            label="Priority"
                            value={priority}
                            options={priorityOptions}
                            onChange={setPriority}
                        />
                        <SheetSelect
                            label="Category"
                            value={category}
                            options={categoryOptions}
                            onChange={onCategory}
                        />
                        {if showTags {
                            <SheetSelect
                                key="tag"
                                label="Tag"
                                value={tag}
                                options={tagOptions}
                                onChange={setTag}
                            />
                        }}
                        <SheetSelect
                            label="Estimate"
                            value={estimate}
                            options={estimateOptions}
                            onChange={setEstimate}
                        />
                        {if showIterations {
                            <SheetSelect
                                key="iteration"
                                label="Iteration"
                                value={iteration}
                                options={iterationOptions}
                                onChange={setIteration}
                            />
                        }}
                        <label className="flex items-center gap-2 pt-1 text-[13px]">
                            <Checkbox
                                checked={not hideDone}
                                onCheckedChange={lambda { onHideDone(); }}
                            />
                            {doneLabel}
                        </label>
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
                                className="ml-auto"
                                onClick={lambda { clearAll(); }}
                            >
                                Clear filters
                            </Button>
                        }}
                        <Button
                            className={"" if anything else "ml-auto"}
                            onClick={lambda { sheetOpen = False; }}
                        >
                            Show tasks
                        </Button>
                    </div>
                </SheetContent>
            </Sheet>
        </div>;
}
