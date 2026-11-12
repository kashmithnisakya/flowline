"""The task sheet's foot, shown only when there is something to answer: unsaved
edits, or the question of what to do with them before opening something else."""

import from ...ui.button { Button }
import from ...common.glyphs { Spinner }

glob FOOT: str = "shrink-0 border-t px-5 py-3 pb-[calc(0.75rem+env(safe-area-inset-bottom))]";

def:pub SheetFooter(
    switchLabel: str,
    canSave: bool,
    saving: bool,
    onSwitch: Callable[[bool], None],
    onStay: Callable[[], None],
    onDiscard: Callable[[], None],
    onSave: Callable[[], None]
) -> JsxElement {
    if switchLabel {
        return
            <div
                role="group"
                aria-label="Unsaved changes"
                className={"grid gap-2 " + FOOT}
            >
                <p id="task-switch-note" className="text-[13px]">
                    <span className="font-semibold">Unsaved changes.</span>
                    {" Save or discard them to open " + switchLabel + "."}
                </p>
                <div className="flex flex-wrap items-center gap-2">
                    <Button
                        variant="ghost"
                        className="-ml-2"
                        data-switch-stay="true"
                        onClick={lambda { if onStay { onStay(); }}}
                    >
                        Keep editing
                    </Button>
                    <div className="ml-auto flex gap-2">
                        <Button
                            variant="outline"
                            disabled={saving}
                            onClick={lambda { if onSwitch { onSwitch(False); }}}
                        >
                            Discard
                        </Button>
                        <Button
                            data-switch-save="true"
                            aria-describedby="task-switch-note"
                            disabled={not canSave}
                            onClick={lambda { if onSwitch and canSave {
                                onSwitch(True);
                            }}}
                        >
                            {if saving {
                                <Spinner key="sp"/>
                            }}
                            {"Saving…" if saving else "Save and open"}
                        </Button>
                    </div>
                </div>
            </div>;
    }
    return
        <div className={"flex items-center gap-2 " + FOOT}>
            <span className="text-[12.5px] text-text-tertiary">Unsaved changes</span>
            <div className="ml-auto flex gap-2">
                <Button variant="ghost" onClick={lambda { onDiscard(); }}>
                    Discard
                </Button>
                <Button disabled={not canSave} onClick={lambda { onSave(); }}>
                    {if saving {
                        <Spinner key="sp"/>
                    }}
                    {"Saving…" if saving else "Save"}
                </Button>
            </div>
        </div>;
}
