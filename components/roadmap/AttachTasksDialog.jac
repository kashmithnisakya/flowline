"""Pull existing board tasks into a milestone.

Only the project's open, unattached tasks are offered: a task carries at
most one milestone, and Done work has nothing left to schedule.
"""

import from ...models { TaskView }
import from ..ui.badge { Badge }
import from ..ui.button { Button }
import from ..ui.dialog {
    Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter
}

def:pub AttachTasksDialog(
    open: bool,
    milestoneTitle: str,
    tasks: list[TaskView],
    selected: list[str],
    saving: bool,
    onToggle: Callable[[str], None],
    onOpenChange: Callable[[bool], None],
    onConfirm: Callable[[], None]
) -> JsxElement {
    return <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="sm:max-w-lg">
            <DialogHeader>
                <DialogTitle>Add tasks to {milestoneTitle}</DialogTitle>
                <DialogDescription>
                    Open tasks on this project that are not on a milestone yet.
                </DialogDescription>
            </DialogHeader>
            <div className="max-h-80 space-y-1 overflow-y-auto py-2">
                {if len(tasks) > 0 {
                    <div key="rows" className="space-y-1">
                        {for t in tasks {
                            <label
                                key={t.id}
                                className="flex cursor-pointer items-center gap-3 rounded-lg border p-2 hover:bg-accent"
                            >
                                <input
                                    type="checkbox"
                                    className="h-4 w-4 shrink-0 accent-primary"
                                    checked={t.id in selected}
                                    onChange={lambda { onToggle(t.id); }}
                                />
                                <span className="min-w-0 flex-1 truncate text-sm">{t.title}</span>
                                <Badge variant="outline" className="shrink-0 font-normal">
                                    {t.status}
                                </Badge>
                            </label>
                        }}
                    </div>
                } else {
                    <p key="none" className="py-6 text-center text-sm text-muted-foreground">
                        Every open task on this project already belongs to a milestone.
                    </p>
                }}
            </div>
            <DialogFooter className="gap-2">
                <Button variant="outline" onClick={lambda { onOpenChange(False); }}>
                    Cancel
                </Button>
                <Button onClick={onConfirm} disabled={saving or len(selected) == 0}>
                    {"Add " + str(len(selected)) + " task(s)" if len(selected) > 0 else "Add tasks"}
                </Button>
            </DialogFooter>
        </DialogContent>
    </Dialog>;
}
