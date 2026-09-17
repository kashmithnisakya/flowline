"""The roadmap's one toolbar row: Project and Iteration filters that read
"Label: value" with their own clear button once set (the Tasks pattern), then
the weeks shown, earlier / this week / later, and the Iterations dialog."""

import from ...models { Project, IterationView }
import from ..common.Busy { Busy }
import from ..ui.button { Button }
import from ..ui.dropdown_menu {
    DropdownMenu,
    DropdownMenuTrigger,
    DropdownMenuContent,
    DropdownMenuRadioGroup,
    DropdownMenuRadioItem
}
import from ...lib.dates { prettyDay }

glob ALL: str = "all",
     NAV_BTN: str = "inline-flex h-7 min-w-7 items-center justify-center rounded-sm px-2 text-[12.5px] font-medium text-muted-foreground outline-none hover:bg-accent hover:text-foreground focus-visible:outline-2 focus-visible:outline-ring focus-visible:outline-solid";

def Chevron(facing: str = "down") -> JsxElement {
    path = "m4.5 6.5 3.5 3.5 3.5-3.5";
    if facing == "left" {
        path = "m9.5 4.5-3.5 3.5 3.5 3.5";
    } elif facing == "right" {
        path = "m6.5 4.5 3.5 3.5-3.5 3.5";
    }
    return
        <svg
            width={14}
            height={14}
            viewBox="0 0 16 16"
            aria-hidden="true"
            className="shrink-0"
        >
            <path
                d={path}
                fill="none"
                stroke="currentColor"
                strokeWidth={1.6}
                strokeLinecap="round"
                strokeLinejoin="round"
            />
        </svg>;
}

def Cross -> JsxElement {
    return
        <svg width={14} height={14} viewBox="0 0 16 16" aria-hidden="true">
            <path
                d="m4 4 8 8M12 4l-8 8"
                stroke="currentColor"
                strokeWidth={1.7}
                strokeLinecap="round"
            />
        </svg>;
}

# Options are [value, label] or [value, label, mono detail].
def optionLabel(options: list[list[str]], value: str) -> str {
    for o in options {
        if o[0] == value {
            return o[1];
        }
    }
    return value;
}

# A ghost trigger that turns into "Label: value ×" once a value is picked. The
# × hands focus back to the trigger before it unmounts itself.
def FilterMenu(
    label: str, value: str, options: list[list[str]], onChange: Callable[[str], None]
) -> JsxElement {
    active = value != ALL;

    def clear(e: MouseEvent) {
        cell: any = e.currentTarget;
        trigger: any = cell.previousElementSibling;
        if trigger {
            trigger.focus();
        }
        onChange(ALL);
    }

    return
        <DropdownMenu>
            <span
                className={"toolbar-filter gap-0! pr-0.5!" if active else "inline-flex"}
                data-active={"true" if active else "false"}
            >
                <DropdownMenuTrigger
                    className={"inline-flex h-full max-w-56 items-center gap-1 rounded-sm outline-none focus-visible:outline-2 focus-visible:outline-ring focus-visible:outline-solid"
                        if active
                        else "toolbar-filter"}
                >
                    {if active {
                        <span key="on" className="truncate">
                            {label + ": " + optionLabel(options, value)}
                        </span>
                    } else {
                        <span key="off" className="inline-flex items-center gap-1">
                            {label}
                            <Chevron/>
                        </span>
                    } }
                </DropdownMenuTrigger>
                {if active {
                    <button
                        key="clear"
                        type="button"
                        aria-label={"Clear the " + label.lower() + " filter"}
                        className="ml-0.5 inline-flex size-6 items-center justify-center rounded-sm text-muted-foreground hover:bg-accent hover:text-foreground focus-visible:outline-2 focus-visible:outline-ring"
                        onClick={clear}
                    >
                        <Cross/>
                    </button>
                }}
            </span>
            <DropdownMenuContent
                align="start"
                collisionPadding={16}
                className="max-h-80 w-64"
            >
                <DropdownMenuRadioGroup value={value} onValueChange={onChange}>
                    {for o in options {
                        <DropdownMenuRadioItem key={o[0]} value={o[0]}>
                            <span className="truncate">{o[1]}</span>
                            {if len(o) > 2 {
                                <span
                                    key="detail"
                                    className="ml-auto shrink-0 font-mono text-xs text-muted-foreground tabular-nums"
                                >
                                    {o[2]}
                                </span>
                            }}
                        </DropdownMenuRadioItem>
                    }}
                </DropdownMenuRadioGroup>
            </DropdownMenuContent>
        </DropdownMenu>;
}

def:pub RoadmapToolbar(
    projects: list[Project],
    iterations: list[IterationView],
    project: str,
    iteration: str,
    rangeLabel: str,
    onProject: Callable[[str], None],
    onIteration: Callable[[str], None],
    onClear: Callable[[], None],
    onEarlier: Callable[[], None],
    onToday: Callable[[], None],
    onLater: Callable[[], None],
    onIterations: Callable[[], None],
    # A refetch is in flight behind the rows on screen.
    busy: bool = False
) -> JsxElement {
    projectOptions: list[list[str]] = [[ALL, "All projects"]];
    for p in projects {
        projectOptions.append([jid(p), p.name]);
    }
    iterationOptions: list[list[str]] = [[ALL, "Any iteration"]];
    for it in iterations {
        iterationOptions.append(
            [it.id, it.name, prettyDay(it.start_date) + " – " + prettyDay(it.end_date)]
        );
    }

    # The page keeps "" for no filter; the menus need a real value for it.
    def pickProject(v: str) {
        onProject("" if v == ALL else v);
    }
    def pickIteration(v: str) {
        onIteration("" if v == ALL else v);
    }

    return
        <div className="toolbar rounded-t-md border-t-0">
            <FilterMenu
                label="Project"
                value={project or ALL}
                options={projectOptions}
                onChange={pickProject}
            />
            {if len(iterations) > 0 or iteration {
                <FilterMenu
                    key="iteration"
                    label="Iteration"
                    value={iteration or ALL}
                    options={iterationOptions}
                    onChange={pickIteration}
                />
            }}
            {if project or iteration {
                <button
                    key="clearall"
                    type="button"
                    className="toolbar-filter text-primary! hover:bg-transparent! hover:underline"
                    onClick={lambda { onClear(); }}
                >
                    Clear filters
                </button>
            }}
            <div className="ml-auto flex flex-wrap items-center gap-2">
                <Busy active={busy}/>
                <span className="meta num whitespace-nowrap" aria-live="polite">
                    {rangeLabel}
                </span>
                <div
                    className="inline-flex items-center gap-0.5 rounded-md border bg-card p-0.5"
                    role="group"
                    aria-label="Weeks shown"
                >
                    <button
                        type="button"
                        className={NAV_BTN}
                        aria-label="Earlier weeks"
                        title="Earlier weeks"
                        onClick={lambda { onEarlier(); }}
                    >
                        <Chevron facing="left"/>
                    </button>
                    <button
                        type="button"
                        className={NAV_BTN}
                        onClick={lambda { onToday(); }}
                    >
                        Today
                    </button>
                    <button
                        type="button"
                        className={NAV_BTN}
                        aria-label="Later weeks"
                        title="Later weeks"
                        onClick={lambda { onLater(); }}
                    >
                        <Chevron facing="right"/>
                    </button>
                </div>
                <Button
                    variant="outline"
                    size="sm"
                    onClick={lambda { onIterations(); }}
                >
                    Iterations
                </Button>
            </div>
        </div>;
}
