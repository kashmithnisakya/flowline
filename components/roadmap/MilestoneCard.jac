"""One milestone: dates, progress, its tasks, and the actions on it.

Presentational. Every action is a callback the Roadmap page owns; detaching
a task only cuts it loose from this phase, it stays on the board.
"""

import from ...models { MilestoneView, TaskView }
import from ..ui.badge { Badge }
import from ..ui.button { Button }
import from ..ui.card {
    Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter
}

glob MONTH_NAMES: list[str] = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
];

# Colour keys again map to literal class strings so Tailwind keeps them.
glob COLOR_KEYS: list[str] = [
    "violet", "sky", "emerald", "amber", "rose", "slate"
];

glob ACCENT: dict[str, str] = {
    "violet": "border-l-violet-500",
    "sky": "border-l-sky-500",
    "emerald": "border-l-emerald-500",
    "amber": "border-l-amber-500",
    "rose": "border-l-rose-500",
    "slate": "border-l-slate-500"
};

glob DOT: dict[str, str] = {
    "violet": "bg-violet-500",
    "sky": "bg-sky-500",
    "emerald": "bg-emerald-500",
    "amber": "bg-amber-500",
    "rose": "bg-rose-500",
    "slate": "bg-slate-500"
};

def colorKey(color: str) -> str {
    return color if color in COLOR_KEYS else "slate";
}

def statusVariant(status: str) -> str {
    if status == "Done" {
        return "secondary";
    }
    if status == "In Progress" {
        return "default";
    }
    return "outline";
}

def shortDate(iso: str) -> str {
    if len(iso) < 10 {
        return "";
    }
    return MONTH_NAMES[int(iso[5:7]) - 1] + " " + iso[8:10] + ", " + iso[0:4];
}

def dateRange(m: MilestoneView) -> str {
    if m.start_date and m.due_date {
        return shortDate(m.start_date) + " to " + shortDate(m.due_date);
    }
    if m.due_date {
        return "Target " + shortDate(m.due_date);
    }
    if m.start_date {
        return "Starts " + shortDate(m.start_date);
    }
    return "No dates yet";
}

def taskProgress(m: MilestoneView) -> str {
    if m.task_count == 0 {
        return "No tasks yet";
    }
    return str(m.done_count) + " of " + str(m.task_count) + " tasks done";
}

def:pub MilestoneCard(
    milestone: MilestoneView,
    tasks: list[TaskView],
    canMoveUp: bool,
    canMoveDown: bool,
    onEdit: Callable[[MilestoneView], None],
    onMove: Callable[[str, int], None],
    onAttach: Callable[[str], None],
    onDetach: Callable[[str], None]
) -> JsxElement {
    return <Card className={"gap-3 border-l-4 py-5 " + ACCENT[colorKey(milestone.color)]}>
        <CardHeader className="gap-1">
            <CardTitle className="flex items-center gap-2 text-base">
                <span className={"h-2 w-2 shrink-0 rounded-full " + DOT[colorKey(milestone.color)]} />
                <span className="truncate" title={milestone.title}>{milestone.title}</span>
                <Badge variant={statusVariant(milestone.status)} className="ml-auto shrink-0 font-normal">
                    {milestone.status}
                </Badge>
            </CardTitle>
            <CardDescription className="text-sm">
                {dateRange(milestone)}
                {" · "}
                {taskProgress(milestone)}
            </CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
            {if milestone.description {
                <p key="desc" className="text-sm text-muted-foreground">
                    {milestone.description}
                </p>
            }}
            <div className="space-y-1.5">
                <div className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                    Tasks
                </div>
                {if len(tasks) > 0 {
                    <div key="chips" className="flex flex-wrap gap-1.5">
                        {for t in tasks {
                            <span
                                key={t.id}
                                className={
                                    "inline-flex max-w-full items-center gap-1 rounded-md border px-2 py-0.5 text-xs "
                                    + ("text-muted-foreground line-through" if t.status == "Done" else "bg-card")
                                }
                            >
                                <span className="truncate" title={t.title + " (" + t.status + ")"}>
                                    {t.title}
                                </span>
                                <button
                                    type="button"
                                    className="shrink-0 text-muted-foreground hover:text-destructive"
                                    title="Take this task off the milestone"
                                    onClick={lambda { onDetach(t.id); }}
                                >
                                    ✕
                                </button>
                            </span>
                        }}
                    </div>
                } else {
                    <p key="none" className="text-xs text-muted-foreground">
                        Nothing here yet. Add tasks from the board below.
                    </p>
                }}
            </div>
        </CardContent>
        <CardFooter className="justify-between gap-1 pt-0">
            <div className="flex gap-1">
                <Button variant="ghost" size="sm" onClick={lambda { onEdit(milestone); }}>
                    Edit
                </Button>
                <Button
                    variant="ghost"
                    size="sm"
                    title="Move earlier in the order"
                    disabled={not canMoveUp}
                    onClick={lambda { onMove(milestone.id, -1); }}
                >
                    ↑
                </Button>
                <Button
                    variant="ghost"
                    size="sm"
                    title="Move later in the order"
                    disabled={not canMoveDown}
                    onClick={lambda { onMove(milestone.id, 1); }}
                >
                    ↓
                </Button>
            </div>
            <Button variant="outline" size="sm" onClick={lambda { onAttach(milestone.id); }}>
                Add tasks
            </Button>
        </CardFooter>
    </Card>;
}
