"""The dialog that adds or edits one AI responsibility on a role. The role's
section owns the form; this renders it and reports each change through
`onField` / `onToggleStep`. Remove sits apart from Save, on the left.
"""

import from ....models { StepView }
import from ...ui.button { Button }
import from ...ui.dialog {
    Dialog,
    DialogContent,
    DialogHeader,
    DialogTitle,
    DialogDescription,
    DialogFooter
}
import from ...common.glyphs { Spinner }
import from ...common.AiMark { AiMark }
import from .ResponsibilityFields { ResponsibilityFields }

def:pub ResponsibilityEditor(
    open: bool,
    editing: bool,
    title: str,
    form: dict[str, str],
    picked: list[str],
    steps: list[StepView],
    saving: bool,
    onField: Callable[[str, str], None],
    onToggleStep: Callable[[str], None],
    onOpenChange: Callable[[bool], None],
    onSave: Callable[[], None],
    onDelete: Callable[[], None]
) -> JsxElement {
    return
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="bg-popover sm:max-w-lg">
                <DialogHeader>
                    <DialogTitle className="flex items-center gap-2">
                        <AiMark/>
                        {title}
                    </DialogTitle>
                    <DialogDescription>
                        Runs when a task lands on one of this role's steps with a linked pull request.
                    </DialogDescription>
                </DialogHeader>
                <form
                    className="flex flex-col gap-5"
                    onSubmit={lambda (e: FormEvent) {
                        e.preventDefault();
                        onSave();
                    }}
                >
                    <ResponsibilityFields
                        form={form}
                        picked={picked}
                        steps={steps}
                        onField={onField}
                        onToggleStep={onToggleStep}
                    />
                    <DialogFooter className="items-center sm:justify-between">
                        {if editing {
                            <Button
                                key="remove"
                                type="button"
                                variant="destructive"
                                disabled={saving}
                                onClick={lambda { onDelete(); }}
                            >
                                Remove
                            </Button>
                        } else {
                            <span key="spacer"/>
                        } }
                        <div className="flex gap-2">
                            <Button
                                type="button"
                                variant="ghost"
                                disabled={saving}
                                onClick={lambda { onOpenChange(False); }}
                            >
                                Cancel
                            </Button>
                            <Button type="submit" disabled={saving}>
                                {if saving {
                                    <Spinner key="sp"/>
                                }}
                                {"Saving…" if saving else "Save"}
                            </Button>
                        </div>
                    </DialogFooter>
                </form>
            </DialogContent>
        </Dialog>;
}
