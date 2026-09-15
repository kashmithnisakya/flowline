"""⌘K palette: jump to a page, run an action, reopen a recent task or find one
by title. Pages match on keywords as well as labels; tasks are searched on the
server (ListTasks with `q`) once the query has two characters. NAV_PAGES and
PageIcon are also the top bar's and the tab bar's, so every list agrees.
"""

import from "@jac/runtime" { navigate, useLocation, jacLogout }
import from "react" { useEffect }
import from ...models { TaskView, StepView }
import from ...constants { STATUS_KIND }
import from ...services.tasks.tasks { ListTasks }
import from ...services.flowlines.flowlines { GetFlowLine }
import from ...lib.theme { setThemePref, isDarkNow }
import from ..ui.dialog { Dialog, DialogContent, DialogTitle }
import from .Avatar { AvatarStack }
import from .StepName { StepName }

glob:pub NAV_PAGES: list[dict[str, str]] = [
         {
             "key": "board",
             "label": "Board",
             "to": "/board",
             "group": "daily",
             "keywords": "kanban columns cards lanes steps"
         },
         {
             "key": "tasks",
             "label": "Tasks",
             "to": "/tasks",
             "group": "daily",
             "keywords": "table list every task sort filter"
         },
         {
             "key": "roadmap",
             "label": "Roadmap",
             "to": "/roadmap",
             "group": "daily",
             "keywords": "timeline iterations sprints schedule plan"
         },
         {
             "key": "log",
             "label": "Log",
             "to": "/log",
             "group": "daily",
             "keywords": "daily record standup history activity"
         },
         {
             "key": "overview",
             "label": "Overview",
             "to": "/overview",
             "group": "daily",
             "keywords": "insights charts progress blocked overdue report"
         },
         {
             "key": "flowline",
             "label": "Flow line",
             "to": "/flowlines",
             "group": "setup",
             "keywords": "workflow steps process transitions design"
         },
         {
             "key": "workspace",
             "label": "Workspace",
             "to": "/workspace",
             "group": "setup",
             "keywords": "organization people members roster roles projects team"
         },
         {
             "key": "github",
             "label": "GitHub",
             "to": "/github",
             "group": "setup",
             "keywords": "issues pull requests repositories sync"
         }
     ];

glob PREFERENCES_PAGE: dict[str, str] = {
         "key": "preferences",
         "label": "Preferences",
         "to": "/workspace?tab=preferences",
         "group": "setup",
         "keywords": "settings theme dark light appearance"
     },
     ACTIONS: list[dict[str, str]] = [
         {"key": "new-task", "label": "New task", "keywords": "create add card"},
         {
             "key": "ask",
             "label": "Ask about this workspace",
             "keywords": "assistant question standup note help"
         },
         {
             "key": "theme",
             "label": "Switch theme",
             "keywords": "dark light mode appearance"
         },
         {"key": "signout", "label": "Sign out", "keywords": "log out logout"}
     ],
     RECENT_KEY: str = "flowline-recent-tasks",
     MAX_TASKS: int = 8,
     MAX_RECENT: int = 5;

# Every whitespace-separated term of the query appears in the label or keywords.
def matches(label: str, keywords: str, q: str) -> bool {
    if q == "" {
        return True;
    }
    hay = (label + " " + keywords).lower();
    for term in q.split(" ") {
        if term and term not in hay {
            return False;
        }
    }
    return True;
}

# Mac keyboards say ⌘; everything else says Ctrl.
def:pub modKey -> str {
    nav: any = navigator;
    platform = str(nav.platform or nav.userAgent or "");
    return "⌘" if "Mac" in platform or "iP" in platform else "Ctrl ";
}

# Recently opened tasks as [{id, title, project}], newest first.
def readRecent -> list[dict[str, str]] {
    try {
        raw = localStorage.getItem(RECENT_KEY);
        if not raw {
            return [];
        }
        parsed: any = JSON.parse(raw);
        rows: list[dict[str, str]] = parsed;
        return rows[:MAX_RECENT];
    } except Exception as e {
        return [];
    }
}

def rememberTask(id: str, title: str, project: str) {
    try {
        kept: list[dict[str, str]] = [{"id": id, "title": title, "project": project}];
        for r in readRecent() {
            if r["id"] != id {
                kept.append(r);
            }
        }
        localStorage.setItem(RECENT_KEY, JSON.stringify(kept[:MAX_RECENT]));
    } except Exception as e {}
}

# The 16px outline icon for a page, action or row. Unknown names draw a task.
def:pub PageIcon(name: str, size: int = 16, className: str = "") -> JsxElement {
    return
        <svg
            className={"shrink-0 " + className}
            width={size}
            height={size}
            viewBox="0 0 16 16"
            fill="none"
            stroke="currentColor"
            strokeWidth={1.5}
            strokeLinecap="round"
            strokeLinejoin="round"
            aria-hidden="true"
        >
            {if name == "board" {
                <g key="board">
                    <rect x={2.25} y={2.75} width={11.5} height={10.5} rx={1.5}/>
                    <path d="M6.1 2.75v10.5M9.9 2.75v10.5"/>
                </g>
            } elif name == "tasks" {
                <g key="tasks">
                    <path d="M6.25 4.5h7.25M6.25 8h7.25M6.25 11.5h7.25"/>
                    <path d="M2.75 4.5h.5M2.75 8h.5M2.75 11.5h.5" strokeWidth={2}/>
                </g>
            } elif name == "roadmap" {
                <path key="roadmap" d="M2.5 4h6M5.5 8h8M3.5 12h5" strokeWidth={2}/>
            } elif name == "log" {
                <g key="log">
                    <rect x={2.5} y={3.5} width={11} height={10} rx={1.5}/>
                    <path d="M2.5 6.5h11M5.5 2v3M10.5 2v3"/>
                </g>
            } elif name == "overview" {
                <path key="overview" d="M2.5 13.5h11M3.5 10.5l3-3 2.5 2 4-5"/>
            } elif name == "flowline" {
                <g key="flowline" transform="scale(0.6667)" strokeWidth={2.2}>
                    <circle cx={5} cy={17} r={3}/>
                    <path d="M8 17h3.5a3 3 0 0 0 3-3v-4a3 3 0 0 1 1.5-2.6"/>
                    <circle cx={19} cy={7} r={3} fill="currentColor" stroke="none"/>
                </g>
            } elif name == "workspace" {
                <g key="workspace">
                    <circle cx={6} cy={5.75} r={2.25}/>
                    <path d="M2.25 13.25c0-2.2 1.7-3.75 3.75-3.75s3.75 1.55 3.75 3.75"/>
                    <path
                        d="M10.75 3.6a2.1 2.1 0 0 1 0 4.2M11.75 9.6c1.2.4 2 1.6 2 3.65"
                    />
                </g>
            } elif name == "github" {
                <path
                    key="github"
                    stroke="none"
                    fill="currentColor"
                    d="M8 .8a7.2 7.2 0 0 0-2.3 14c.4.1.5-.1.5-.3v-1.3c-2 .4-2.4-.9-2.4-.9-.3-.8-.8-1-.8-1-.7-.5 0-.5 0-.5.7.1 1.1.8 1.1.8.6 1.1 1.7.8 2.1.6.1-.5.3-.8.5-1-1.6-.2-3.3-.8-3.3-3.6 0-.8.3-1.4.8-1.9-.1-.2-.3-.9.1-1.9 0 0 .6-.2 2 .7a6.9 6.9 0 0 1 3.6 0c1.4-.9 2-.7 2-.7.4 1 .2 1.7.1 1.9.5.5.8 1.1.8 1.9 0 2.8-1.7 3.4-3.3 3.6.3.2.5.7.5 1.4v2c0 .2.1.4.5.3A7.2 7.2 0 0 0 8 .8"
                />
            } elif name == "preferences" {
                <g key="preferences">
                    <path d="M2.5 5h2.75M8.75 5h4.75M2.5 11h6M11.75 11h1.75"/>
                    <circle cx={7} cy={5} r={1.75}/>
                    <circle cx={10} cy={11} r={1.75}/>
                </g>
            } elif name == "new-task" {
                <path key="new-task" d="M8 3v10M3 8h10"/>
            } elif name == "ask" {
                <path key="ask" d="M3 3.5h10v7H7.5L4.5 13v-2.5H3z"/>
            } elif name == "theme" {
                <path
                    key="theme"
                    d="M13 9.6A5.5 5.5 0 1 1 6.4 3a4.5 4.5 0 0 0 6.6 6.6z"
                />
            } elif name == "signout" {
                <path
                    key="signout"
                    d="M6.5 2.75h-3a1 1 0 0 0-1 1v8.5a1 1 0 0 0 1 1h3M10.25 5l3 3-3 3M13 8H6"
                />
            } elif name == "search" {
                <g key="search">
                    <circle cx={7} cy={7} r={4.5}/>
                    <path d="m10.5 10.5 3 3"/>
                </g>
            } elif name == "more" {
                <path key="more" d="M3.5 8h.01M8 8h.01M12.5 8h.01" strokeWidth={2.6}/>
            } elif name == "chevron" {
                <path key="chevron" d="m4.5 6.5 3.5 3.5 3.5-3.5"/>
            } else {
                <g key="task">
                    <rect x={3} y={2.5} width={10} height={11} rx={1.5}/>
                    <path d="M5.75 6h4.5M5.75 9h2.75"/>
                </g>
            }                }
        </svg>;
}

def:pub CommandPalette(
    open: bool, onOpenChange: Callable[[bool], None], canAsk: bool = True
) -> JsxElement {
    has query: str = "",
        active: int = 0,
        tasks: list[TaskView] = [],
        recent: list[dict[str, str]] = [],
        steps: list[StepView] = [],
        stepsAsked: bool = False,
        # The query the loaded rows answer; the list shows "Searching…"
        # while it lags the box. A ref carries the latest query into the
        # timer so a slow answer to an old query cannot overwrite a newer one.
        searched: str = "",
        latestRef: Ref[any] = Ref();

    location = useLocation();
    mod = modKey();

    # Reset the query each time the palette opens and reread the recent tasks.
    useEffect(
        lambda { if open {
            query = "";
            active = -1;
            tasks = [];
            searched = "";
            recent = readRecent();
        }},
        [open]
    );

    q = query.strip().lower();
    latestRef.current = q;

    # Search the server a beat after typing stops; the runtime's short read
    # cache makes repeats free.
    useEffect(
        lambda {
            # Always return a cleanup FUNCTION: React only skips a destroy
            # that is `undefined`, so an effect that returns None (which is
            # `null` in the emitted JS) gets called and throws.
            timer: any = 0;
            if len(q) >= 2 {
                timer = window.setTimeout(lambda { fetchTasks(q); }, 180);
            }
            return lambda { if timer { window.clearTimeout(timer); }};
        },
        [q]
    );

    async def fetchTasks(wanted: str) {
        rows: list[TaskView] = [];
        try {
            result = root spawn ListTasks(scope="all", q=wanted, page_size=MAX_TASKS);
            page = result.reports[0] if result.reports else None;
            rows = page.rows if page else [];
        } except Exception as e {
            rows = [];
        }
        if latestRef.current == wanted {
            tasks = rows;
            searched = wanted;
        }
        if len(rows) > 0 and not stepsAsked {
            stepsAsked = True;
            try {
                line = root spawn GetFlowLine(with_counts=False);
                steps = line.reports[0] if line.reports else [];
            } except Exception as e {
                steps = [];
            }
        }
    }

    # The board's placement rule: the task's own step, else the first step of
    # the kind its legacy status maps to, else the status itself.
    def stepOf(t: TaskView) -> dict[str, str] {
        kind = STATUS_KIND[t.status] if t.status in STATUS_KIND else "start";
        byKind: dict[str, str] = {};
        hasKind = False;
        for s in steps {
            if s.id == t.step_id {
                return {"name": s.name, "color": s.color};
            }
            if not hasKind and s.kind == kind {
                byKind = {"name": s.name, "color": s.color};
                hasKind = True;
            }
        }
        if hasKind {
            return byKind;
        }
        return {"name": t.status, "color": "slate"};
    }

    def isCurrent(to: str) -> bool {
        parts = to.split("?");
        search = str(location.search or "");
        if location.pathname != parts[0] {
            return False;
        }
        if len(parts) > 1 {
            return parts[1] in search;
        }
        return "tab=preferences" not in search;
    }

    darkNow = isDarkNow();
    pageItems = [
        p
        for p in NAV_PAGES + [PREFERENCES_PAGE]
        if matches(p["label"], p["keywords"], q)
    ];
    actionItems: list[dict[str, str]] = [];
    for a in ACTIONS {
        label = a["label"];
        if a["key"] == "theme" {
            label = "Switch to light theme" if darkNow else "Switch to dark theme";
        }
        if a["key"] == "ask" {
            if not canAsk {
                continue;
            }
            # A typed query becomes the last row instead, so Enter on a title
            # still opens the task.
            if len(q) >= 2 {
                continue;
            }
        }
        if matches(label, a["keywords"], q) {
            actionItems.append({"key": a["key"], "label": label, "icon": a["key"]});
        }
    }
    recentItems = recent if q == "" else [];
    taskItems = tasks if len(q) >= 2 and searched == q else [];
    askTail = canAsk and len(q) >= 2;
    # One flat list for the cursor: pages, actions, recent tasks, tasks, Ask.
    nPages = len(pageItems);
    nActions = len(actionItems);
    nRecent = len(recentItems);
    nTasks = len(taskItems);
    total = nPages + nActions + nRecent + nTasks + (1 if askTail else 0);

    # Until the user moves, the cursor rests on the first row that is not the
    # page they are already on.
    firstFree = 0;
    for (i, p) in enumerate(pageItems) {
        if firstFree == i and isCurrent(p["to"]) {
            firstFree = i + 1;
        }
    }
    cursor = active
        if active >= 0 and active < total
        else (firstFree if firstFree < total else 0);

    def close {
        onOpenChange(False);
    }

    def go(to: str, event: str, detail: str) {
        close();
        if event and location.pathname == to.split("?")[0] {
            # Already there: the page cannot remount, so tell it directly.
            w: any = window;
            w.dispatchEvent(new(w.CustomEvent, event, {"detail": detail}));
            return;
        }
        navigate(to);
    }

    def openTask(id: str, title: str, project: str) {
        rememberTask(id, title, project);
        go("/board?task=" + id, "flowline:open-task", id);
    }

    def askQuestion(question: str) {
        close();
        w: any = window;
        w.dispatchEvent(
            new(w.CustomEvent, "flowline:ask", {"detail": {"question": question}})
        );
    }

    def runItem(index: int) {
        if index < nPages {
            go(pageItems[index]["to"], "", "");
            return;
        }
        index = index - nPages;
        if index < nActions {
            key = actionItems[index]["key"];
            if key == "new-task" {
                go("/board?new=1", "flowline:new-task", "");
            } elif key == "ask" {
                askQuestion("");
            } elif key == "theme" {
                setThemePref("light" if isDarkNow() else "dark");
                close();
            } elif key == "signout" {
                close();
                jacLogout();
                window.location.href = "/login";
            }
            return;
        }
        index = index - nActions;
        if index < nRecent {
            r = recentItems[index];
            openTask(r["id"], r["title"], r["project"]);
            return;
        }
        index = index - nRecent;
        if index < nTasks {
            t = taskItems[index];
            openTask(t.id, t.title, t.project_name);
            return;
        }
        if askTail {
            askQuestion(query.strip());
        }
    }

    def onKey(e: KeyboardEvent) {
        if e.key == "ArrowDown" {
            e.preventDefault();
            active = (cursor + 1) % total if total > 0 else 0;
        } elif e.key == "ArrowUp" {
            e.preventDefault();
            active = (cursor - 1 + total) % total if total > 0 else 0;
        } elif e.key == "Enter" {
            e.preventDefault();
            if total > 0 {
                runItem(cursor);
            }
        }
    }

    def rowClass(index: int) -> str {
        base = "flex h-9 w-full cursor-pointer items-center gap-2.5 rounded-md px-2.5 text-left text-[13.5px] ";
        return base
            + ("bg-accent text-foreground" if index == cursor else "text-foreground");
    }

    groupClass = "px-2.5 pt-2.5 pb-1 text-xs font-medium text-muted-foreground";

    return
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent
                className="top-[14vh] max-h-[72dvh] translate-y-0 grid-rows-[auto_minmax(0,1fr)_auto] gap-0 overflow-hidden rounded-xl bg-card p-0 sm:max-w-[560px]"
                showCloseButton={False}
            >
                <DialogTitle className="sr-only">Search or jump</DialogTitle>
                <div className="flex items-center gap-2.5 border-b px-3.5">
                    <PageIcon name="search" className="text-muted-foreground"/>
                    <input
                        autoFocus={True}
                        value={query}
                        onChange={lambda (e: any) {
                            query = e.target.value;
                            active = -1;
                        }}
                        onKeyDown={onKey}
                        placeholder="Jump to a page, run an action, or find a task"
                        aria-label="Search pages, actions and tasks"
                        className="h-12 w-full min-w-0 bg-transparent text-[15px] outline-none placeholder:text-subtle"
                    />
                    <span className="kbd hidden sm:inline-flex">Esc</span>
                </div>
                <div className="min-h-0 overflow-y-auto p-1.5" role="listbox">
                    {if total == 0 {
                        <div
                            key="none"
                            className="px-3 py-8 text-center text-sm text-muted-foreground"
                        >
                            {"Nothing matches “" + query.strip() + "”"
                                if searched == q or len(q) < 2
                                else "Searching…"}
                        </div>
                    }}
                    {if nPages > 0 {
                        <div key="pages">
                            <div className={groupClass}>Pages</div>
                            {for (i, p) in enumerate(pageItems) {
                                <button
                                    key={p["key"]}
                                    type="button"
                                    role="option"
                                    aria-selected={i == cursor}
                                    aria-current={"page"
                                        if isCurrent(p["to"])
                                        else None}
                                    className={rowClass(i)}
                                    onMouseMove={lambda { if active != i {
                                        active = i;
                                    }}}
                                    onClick={lambda { runItem(i); }}
                                >
                                    <PageIcon
                                        name={p["key"]}
                                        className="text-muted-foreground"
                                    />
                                    <span className="truncate">{p["label"]}</span>
                                    {if isCurrent(p["to"]) {
                                        <span key="here" className="meta ml-auto">
                                            Current
                                        </span>
                                    }}
                                </button>
                            }}
                        </div>
                    }}
                    {if nActions > 0 {
                        <div key="actions">
                            <div className={groupClass}>Actions</div>
                            {for (i, a) in enumerate(actionItems) {
                                <button
                                    key={a["key"]}
                                    type="button"
                                    role="option"
                                    aria-selected={nPages + i == cursor}
                                    className={rowClass(nPages + i)}
                                    onMouseMove={lambda { if active != nPages + i {
                                        active = nPages + i;
                                    }}}
                                    onClick={lambda { runItem(nPages + i); }}
                                >
                                    <PageIcon
                                        name={a["icon"]}
                                        className="text-muted-foreground"
                                    />
                                    <span className="truncate">{a["label"]}</span>
                                    {if a["key"] == "ask" {
                                        <span key="k" className="kbd ml-auto">
                                            {mod + "/"}
                                        </span>
                                    }}
                                </button>
                            }}
                        </div>
                    }}
                    {if nRecent > 0 {
                        <div key="recent">
                            <div className={groupClass}>Recent tasks</div>
                            {for (i, r) in enumerate(recentItems) {
                                <button
                                    key={"r" + r["id"]}
                                    type="button"
                                    role="option"
                                    aria-selected={nPages + nActions + i == cursor}
                                    className={rowClass(nPages + nActions + i)}
                                    onMouseMove={lambda { if active
                                        != nPages + nActions + i {
                                        active = nPages + nActions + i;
                                    }}}
                                    onClick={lambda { runItem(nPages + nActions + i); }}
                                >
                                    <PageIcon
                                        name="task"
                                        className="text-muted-foreground"
                                    />
                                    <span className="min-w-0 truncate">
                                        {r["title"]}
                                    </span>
                                    {if r["project"] {
                                        <span
                                            key="p"
                                            className="meta ml-auto shrink-0 truncate"
                                        >
                                            {r["project"]}
                                        </span>
                                    }}
                                </button>
                            }}
                        </div>
                    }}
                    {if len(taskItems) > 0 {
                        <div key="tasks">
                            <div className={groupClass}>Tasks</div>
                            {for (i, t) in enumerate(taskItems) {
                                <button
                                    key={t.id}
                                    type="button"
                                    role="option"
                                    aria-selected={nPages + nActions + nRecent + i
                                        == cursor}
                                    className={rowClass(
                                        nPages + nActions + nRecent + i
                                    )}
                                    onMouseMove={lambda { if active
                                        != nPages + nActions + nRecent + i {
                                        active = nPages + nActions + nRecent + i;
                                    }}}
                                    onClick={lambda { runItem(
                                        nPages + nActions + nRecent + i
                                    ); }}
                                >
                                    <PageIcon
                                        name="task"
                                        className="text-muted-foreground"
                                    />
                                    <span className="min-w-0 flex-1 truncate">
                                        {t.title}
                                        {if t.project_name {
                                            <span key="p" className="meta">
                                                {" · " + t.project_name}
                                            </span>
                                        }}
                                    </span>
                                    {if len(t.assignee_names) > 0 {
                                        <AvatarStack
                                            key="who"
                                            names={t.assignee_names}
                                            max={2}
                                        />
                                    }}
                                    <StepName
                                        name={stepOf(t)["name"]}
                                        color={stepOf(t)["color"]}
                                        className="w-28 shrink-0 text-xs text-muted-foreground"
                                    />
                                </button>
                            }}
                        </div>
                    }}
                    {if askTail {
                        <div key="ask">
                            <div className={groupClass}>Ask</div>
                            <button
                                type="button"
                                role="option"
                                aria-selected={total - 1 == cursor}
                                className={rowClass(total - 1)}
                                onMouseMove={lambda { if active != total - 1 {
                                    active = total - 1;
                                }}}
                                onClick={lambda { runItem(total - 1); }}
                            >
                                <PageIcon name="ask" className="text-muted-foreground"/>
                                <span className="truncate">
                                    {"Ask “" + query.strip() + "”"}
                                </span>
                                <span className="kbd ml-auto">{mod + "/"}</span>
                            </button>
                        </div>
                    }}
                </div>
                <div
                    className="flex items-center gap-3 border-t px-3.5 py-2 text-xs text-muted-foreground"
                >
                    <span className="flex items-center gap-1.5">
                        <span className="kbd">↑↓</span>
                        move
                    </span>
                    <span className="flex items-center gap-1.5">
                        <span className="kbd">↵</span>
                        open
                    </span>
                    <span className="ml-auto flex items-center gap-1.5">
                        <span className="kbd">{mod + "K"}</span>
                        anywhere
                    </span>
                </div>
            </DialogContent>
        </Dialog>;
}
