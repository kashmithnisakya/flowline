"""Detail panel for the step selected on the Flow canvas.

Read-only apart from the connection chips: editing content stays in the
dialog, so there is one save semantic in the app rather than two. The
incoming and outgoing arrows are listed as removable chips because that is
the accessible way to delete a connection, with the canvas ✕ as the
shortcut rather than the only route.
"""

import from ...models { MilestoneView, TaskView }
import from ..ui.badge { Badge }
import from ..ui.button { Button }
import from ..ui.card { Card, CardContent }


def:pub StepInspector(
    step: MilestoneView,
    tasks: list[TaskView] = [],
    incoming: list[MilestoneView] = [],
    outgoing: list[MilestoneView] = [],
    connecting: bool = False,
    onConnect: Callable[[], None] = None,
    onCancelConnect: Callable[[], None] = None,
    onEdit: Callable[[MilestoneView], None] = None,
    onAttach: Callable[[str], None] = None,
    onDetach: Callable[[str], None] = None,
    onUnlink: Callable[[str, str], None] = None
) -> JsxElement {
    return <Card className="lg:sticky lg:top-6">
        <CardContent className="space-y-4 py-4">
            <div className="space-y-1">
                <div className="flex items-start justify-between gap-2">
                    <h3 className="font-display text-base font-semibold leading-tight">
                        {step.title}
                    </h3>
                    <Badge variant={"secondary" if step.status == "Done" else "outline"}>
                        {step.status}
                    </Badge>
                </div>
                <p className="text-xs text-muted-foreground">
                    {
                        (str(step.done_count) + " of " + str(step.task_count)
                            + " tasks done")
                        if step.task_count > 0 else "No tasks yet"
                    }
                </p>
            </div>

            {if step.description {
                <p key="desc" className="text-sm text-muted-foreground">
                    {step.description}
                </p>
            }}

            {if step.ready {
                <p key="ready" className="rounded-md border border-emerald-500/40 bg-emerald-500/10 px-2.5 py-1.5 text-xs text-emerald-700">
                    Ready to start. Everything this waits on is done.
                </p>
            }}

            {if step.blocked_by > 0 {
                <div key="blocked" className="space-y-1">
                    <div className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                        Waiting on
                    </div>
                    <div className="flex flex-wrap gap-1.5">
                        {for m in incoming {
                            <span key={m.id}>
                                {if m.status != "Done" {
                                    <Badge key="b" variant="outline">{m.title}</Badge>
                                }}
                            </span>
                        }}
                    </div>
                </div>
            }}

            <div className="space-y-1">
                <div className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                    Comes after
                </div>
                {if len(incoming) == 0 {
                    <p key="none" className="text-xs text-muted-foreground">
                        Nothing. This is a starting point.
                    </p>
                } else {
                    <div key="chips" className="flex flex-wrap gap-1.5">
                        {for m in incoming {
                            <span
                                key={m.id}
                                className="inline-flex items-center gap-1 rounded-md border bg-muted/40 px-2 py-0.5 text-xs"
                            >
                                {m.title}
                                <button
                                    type="button"
                                    title={"Disconnect " + m.title}
                                    className="text-muted-foreground hover:text-destructive"
                                    onClick={lambda { if onUnlink { onUnlink(m.id, step.id); } }}
                                >
                                    ✕
                                </button>
                            </span>
                        }}
                    </div>
                }}
            </div>

            <div className="space-y-1">
                <div className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                    Leads to
                </div>
                {if len(outgoing) == 0 {
                    <p key="none" className="text-xs text-muted-foreground">
                        Nothing yet.
                    </p>
                } else {
                    <div key="chips" className="flex flex-wrap gap-1.5">
                        {for m in outgoing {
                            <span
                                key={m.id}
                                className="inline-flex items-center gap-1 rounded-md border bg-muted/40 px-2 py-0.5 text-xs"
                            >
                                {m.title}
                                <button
                                    type="button"
                                    title={"Disconnect " + m.title}
                                    className="text-muted-foreground hover:text-destructive"
                                    onClick={lambda { if onUnlink { onUnlink(step.id, m.id); } }}
                                >
                                    ✕
                                </button>
                            </span>
                        }}
                    </div>
                }}
            </div>

            {if len(tasks) > 0 {
                <div key="tasks" className="space-y-1">
                    <div className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                        Tasks
                    </div>
                    <div className="flex flex-wrap gap-1.5">
                        {for t in tasks {
                            <span
                                key={t.id}
                                className={
                                    "inline-flex items-center gap-1 rounded-md border px-2 py-0.5 text-xs "
                                    + (
                                        "text-muted-foreground line-through"
                                        if t.status == "Done" else ""
                                    )
                                }
                            >
                                {t.title}
                                <button
                                    type="button"
                                    title={"Remove " + t.title + " from this step"}
                                    className="text-muted-foreground hover:text-destructive"
                                    onClick={lambda { if onDetach { onDetach(t.id); } }}
                                >
                                    ✕
                                </button>
                            </span>
                        }}
                    </div>
                </div>
            }}

            <div className="flex flex-wrap gap-2 border-t pt-3">
                {if connecting {
                    <Button
                        key="cancel"
                        variant="outline"
                        size="sm"
                        onClick={lambda { if onCancelConnect { onCancelConnect(); } }}
                    >
                        Cancel connect
                    </Button>
                } else {
                    <Button
                        key="connect"
                        size="sm"
                        onClick={lambda { if onConnect { onConnect(); } }}
                    >
                        Connect →
                    </Button>
                }}
                <Button
                    variant="outline"
                    size="sm"
                    onClick={lambda { if onEdit { onEdit(step); } }}
                >
                    Edit
                </Button>
                <Button
                    variant="outline"
                    size="sm"
                    onClick={lambda { if onAttach { onAttach(step.id); } }}
                >
                    Add tasks
                </Button>
            </div>
        </CardContent>
    </Card>;
}
