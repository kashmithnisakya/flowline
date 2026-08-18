"""⌘K palette: jump to a page, run an action, or open a task by title. Tasks
load when the palette opens (one ListTasks call) and match once the query
has two characters, so the empty palette stays a short list of places.
Navigation goes through the runtime's navigate(); the board reacts to
`standup:new-task` / `standup:open-task` when it is already mounted.
"""

import from "@jac/runtime" { navigate, useLocation, jacLogout }
import from "react" { useEffect }
import from ...models { TaskView }
import from ...walkers.tasks { ListTasks }
import from ...lib.theme { getThemePref, setThemePref }
import from ..ui.dialog { Dialog, DialogContent, DialogTitle }
import from .Avatar { AvatarStack, dotFor }

glob PAGES: list[dict[str, str]] = [
         {
             "kind": "page",
             "label": "Flow line",
             "to": "/flowlines",
             "hint": "Design the steps"
         },
         {
             "kind": "page",
             "label": "Board",
             "to": "/board",
             "hint": "Kanban of the flow line"
         },
         {
             "kind": "page",
             "label": "Overview",
             "to": "/overview",
             "hint": "Where the work stands"
         },
         {"kind": "page", "label": "Log", "to": "/log", "hint": "The daily record"},
         {
             "kind": "page",
             "label": "GitHub",
             "to": "/github",
             "hint": "Issues and pull requests"
         },
         {
             "kind": "page",
             "label": "Workspace",
             "to": "/workspace",
             "hint": "Projects, people, roles"
         },
         {
             "kind": "page",
             "label": "Settings",
             "to": "/settings",
             "hint": "Preferences for this browser"
         }
     ],
     ACTIONS: list[dict[str, str]] = [
         {
             "kind": "new-task",
             "label": "New task",
             "to": "/board",
             "hint": "Opens the task dialog on the board"
         },
         {
             "kind": "theme",
             "label": "Toggle light / dark",
             "to": "",
             "hint": "Pins the choice for this browser"
         },
         {"kind": "logout", "label": "Log out", "to": "/login", "hint": ""}
     ],
     MAX_TASKS: int = 8;

def matches(label: str, q: str) -> bool {
    return q == "" or q in label.lower();
}

def:pub CommandPalette(open: bool, onOpenChange: Callable[[bool], None]) -> JsxElement {
    has query: str = "",
        active: int = 0,
        tasks: list[TaskView] = [],
        loadedTasks: bool = False;

    location = useLocation();

    # Load tasks once per opening; reset the query and cursor each time.
    useEffect(
        lambda { if open {
            query = "";
            active = 0;
            loadedTasks = False;
            fetchTasks();
        }},
        [open]
    );

    async def fetchTasks {
        try {
            result = root spawn ListTasks();
            tasks = result.reports[0] if result.reports else [];
        } except Exception as e {
            tasks = [];
        }
        loadedTasks = True;
    }

    q = query.strip().lower();
    pageItems = [
        p
        for p in PAGES
        if matches(p["label"], q)
    ];
    actionItems = [
        a
        for a in ACTIONS
        if matches(a["label"], q)
    ];
    taskItems = [
        t
        for t in tasks
        if q in t.title.lower()
    ][:MAX_TASKS]
        if len(q) >= 2
        else [];
    # One flat list for the cursor: pages, then actions, then tasks.
    total = len(pageItems) + len(actionItems) + len(taskItems);

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

    def runItem(index: int) {
        if index < len(pageItems) {
            go(pageItems[index]["to"], "", "");
            return;
        }
        index = index - len(pageItems);
        if index < len(actionItems) {
            a = actionItems[index];
            if a["kind"] == "new-task" {
                go("/board?new=1", "standup:new-task", "");
            } elif a["kind"] == "theme" {
                pref = getThemePref();
                doc: any = document;
                dark = bool(doc.documentElement.classList.contains("dark"));
                setThemePref("light" if dark else "dark");
                close();
            } elif a["kind"] == "logout" {
                close();
                jacLogout();
                window.location.href = "/login";
            }
            return;
        }
        index = index - len(actionItems);
        if index < len(taskItems) {
            t = taskItems[index];
            go("/board?task=" + t.id, "standup:open-task", t.id);
        }
    }

    def onKey(e: KeyboardEvent) {
        if e.key == "ArrowDown" {
            e.preventDefault();
            active = (active + 1) % total if total > 0 else 0;
        } elif e.key == "ArrowUp" {
            e.preventDefault();
            active = (active - 1 + total) % total if total > 0 else 0;
        } elif e.key == "Enter" {
            e.preventDefault();
            if total > 0 {
                runItem(active if active < total else 0);
            }
        }
    }

    def rowClass(index: int) -> str {
        base = "flex w-full cursor-pointer items-center gap-3 rounded-lg px-3 py-2 text-left text-sm transition-colors ";
        return base + (
            "bg-accent text-foreground" if index == active else "hover:bg-accent/60"
        );
    }

    return
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent
                className="top-[18%] max-w-lg translate-y-0 gap-0 overflow-hidden p-0"
                showCloseButton={False}
            >
                <DialogTitle className="sr-only">Command palette</DialogTitle>
                <div className="flex items-center gap-2 border-b px-3">
                    <svg
                        width={16}
                        height={16}
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth={2}
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        className="shrink-0 text-muted-foreground"
                        aria-hidden="true"
                    >
                        <circle cx={11} cy={11} r={8}/>
                        <path d="m21 21-4.3-4.3"/>
                    </svg>
                    <input
                        autoFocus={True}
                        value={query}
                        onChange={lambda (e: any) {
                            query = e.target.value;
                            active = 0;
                        }}
                        onKeyDown={onKey}
                        placeholder="Go to a page, run an action, or find a task…"
                        aria-label="Search pages, actions and tasks"
                        className="h-12 w-full bg-transparent text-sm outline-none placeholder:text-muted-foreground"
                    />
                    <kbd
                        className="hidden shrink-0 rounded border border-border bg-muted px-1.5 py-0.5 font-mono text-[10px] text-muted-foreground sm:inline"
                    >
                        esc
                    </kbd>
                </div>
                <div className="max-h-[60vh] overflow-y-auto p-2" role="listbox">
                    {if total == 0 {
                        <div
                            key="none"
                            className="px-3 py-8 text-center text-sm text-muted-foreground"
                        >
                            {"Nothing matches “" + query + "”"
                                if loadedTasks or len(q) < 2
                                else "Searching…"}
                        </div>
                    }}
                    {if len(pageItems) > 0 {
                        <div key="pages">
                            <div
                                className="px-3 pt-1 pb-1 text-[11px] font-semibold uppercase tracking-wide text-muted-foreground"
                            >
                                Pages
                            </div>
                            {for (i, p) in enumerate(pageItems) {
                                <button
                                    key={p["to"]}
                                    type="button"
                                    role="option"
                                    aria-selected={i == active}
                                    className={rowClass(i)}
                                    onMouseEnter={lambda { active = i; }}
                                    onClick={lambda { runItem(i); }}
                                >
                                    <span className="font-medium">{p["label"]}</span>
                                    <span
                                        className="ml-auto truncate text-xs text-muted-foreground"
                                    >
                                        {p["hint"]}
                                    </span>
                                </button>
                            }}
                        </div>
                    }}
                    {if len(actionItems) > 0 {
                        <div key="actions">
                            <div
                                className="px-3 pt-2 pb-1 text-[11px] font-semibold uppercase tracking-wide text-muted-foreground"
                            >
                                Actions
                            </div>
                            {for (i, a) in enumerate(actionItems) {
                                <button
                                    key={a["kind"]}
                                    type="button"
                                    role="option"
                                    aria-selected={len(pageItems) + i == active}
                                    className={rowClass(len(pageItems) + i)}
                                    onMouseEnter={lambda { active = len(
                                        pageItems
                                    ) + i; }}
                                    onClick={lambda { runItem(len(pageItems) + i); }}
                                >
                                    <span className="font-medium">{a["label"]}</span>
                                    <span
                                        className="ml-auto truncate text-xs text-muted-foreground"
                                    >
                                        {a["hint"]}
                                    </span>
                                </button>
                            }}
                        </div>
                    }}
                    {if len(taskItems) > 0 {
                        <div key="tasks">
                            <div
                                className="px-3 pt-2 pb-1 text-[11px] font-semibold uppercase tracking-wide text-muted-foreground"
                            >
                                Tasks
                            </div>
                            {for (i, t) in enumerate(taskItems) {
                                <button
                                    key={t.id}
                                    type="button"
                                    role="option"
                                    aria-selected={len(pageItems) + len(
                                        actionItems
                                    ) + i == active}
                                    className={rowClass(
                                        len(pageItems) + len(actionItems) + i
                                    )}
                                    onMouseEnter={lambda { active = len(pageItems) + len(
                                        actionItems
                                    ) + i; }}
                                    onClick={lambda { runItem(
                                        len(pageItems) + len(actionItems) + i
                                    ); }}
                                >
                                    {if t.project_name {
                                        <span
                                            key="dot"
                                            className={"h-1.5 w-1.5 shrink-0 rounded-full " + dotFor(
                                                t.project_name
                                            )}
                                        />
                                    }}
                                    <span
                                        className="min-w-0 flex-1 truncate font-medium"
                                    >
                                        {t.title}
                                    </span>
                                    {if len(t.assignee_names) > 0 {
                                        <AvatarStack
                                            key="who"
                                            names={t.assignee_names}
                                            max={2}
                                        />
                                    }}
                                    <span
                                        className="shrink-0 text-xs text-muted-foreground"
                                    >
                                        {t.status}
                                    </span>
                                </button>
                            }}
                        </div>
                    }}
                </div>
                <div
                    className="flex items-center gap-3 border-t px-3 py-2 text-[11px] text-muted-foreground"
                >
                    <span><kbd className="font-mono">↑↓</kbd> to move</span>
                    <span><kbd className="font-mono">↵</kbd> to open</span>
                    <span className="ml-auto">
                        <kbd className="font-mono">⌘K</kbd>{" "}
                        anywhere
                    </span>
                </div>
            </DialogContent>
        </Dialog>;
}
