"""The task sheet's notes: rendered once written, a textarea while editing, a
skeleton until GetTask lands, and a retry if it failed."""

import from ...common.Markdown { Markdown }
import from ...ui.button { Button }
import from ...ui.skeleton { Skeleton }
import from ...ui.textarea { Textarea }

def:pub SheetNotes(
    notes: str,
    hasNotes: bool,
    editing: bool,
    shown: bool,
    failed: bool,
    onEdit: Callable[[bool], None],
    onChange: Callable[[str], None],
    onRetry: Callable[[], None]
) -> JsxElement {
    return
        <section className="grid gap-1.5" aria-label="Notes">
            <div className="flex items-center justify-between">
                <h3 className="text-[13px] font-semibold">Notes</h3>
                {if hasNotes and shown {
                    <Button
                        key="toggle"
                        variant="ghost"
                        size="xs"
                        onClick={lambda { onEdit(not editing); }}
                    >
                        {"Preview" if editing else "Edit"}
                    </Button>
                }}
            </div>
            {if not shown {
                if failed {
                    <div
                        key="failed"
                        className="flex items-center justify-between gap-2 rounded-md border border-destructive/30 px-2.5 py-2 text-[13px] text-destructive"
                    >
                        <span>Notes and checklist could not be loaded.</span>
                        <Button
                            variant="ghost"
                            size="xs"
                            onClick={lambda { onRetry(); }}
                        >
                            Try again
                        </Button>
                    </div>
                } else {
                    <div key="loading" className="grid gap-2 py-1" aria-busy="true">
                        <Skeleton className="h-3.5 w-4/5"/>
                        <Skeleton className="h-3.5 w-3/5"/>
                        <Skeleton className="mt-3 h-3.5 w-2/5"/>
                    </div>
                }
            } elif editing or not hasNotes {
                <Textarea
                    key="write"
                    className="min-h-20 rounded-md text-[13px] md:text-[13px]"
                    placeholder="Add notes, acceptance criteria or links. Markdown works."
                    value={notes}
                    onChange={lambda (e: ChangeEvent) {
                        onEdit(True);
                        onChange(e.target.value);
                    }}
                />
            } else {
                <div
                    key="preview"
                    className="min-h-12 cursor-text rounded-md px-0.5 text-[13px] text-text-secondary"
                    onClick={lambda { onEdit(True); }}
                >
                    <Markdown text={notes}/>
                </div>
            }  }
        </section>;
}
