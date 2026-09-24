"""The selected transition's editor over the canvas: `form` holds its label,
carries, trigger and trigger_label, and every field saves together."""

import from .kinds { TRIGGER_PICKS, triggerNote }
import from .EdgePicks { EdgePicks }
import from .EdgeActions { EdgeActions }
import from ..ui.input { Input }

glob CARRY_PICKS: list[dict[str, str]] = [
         {"key": "", "text": "None"},
         {"key": "issue", "text": "Issue"},
         {"key": "pr", "text": "PR"}
     ];


def:pub EdgeEditor(
    fromName: str,
    toName: str,
    form: dict[str, str],
    left: float = 0.0,
    top: float = 0.0,
    clearable: bool = False,
    onField: Callable[[str, str], None] = None,
    onSave: Callable[[], None] = None,
    onClear: Callable[[], None] = None,
    onDelete: Callable[[], None] = None
) -> JsxElement {
    trigger = form["trigger"] or "";
    note = triggerNote(trigger, form["trigger_label"] or "…");
    return
        <div
            className="absolute z-40 w-72 -translate-x-1/2 rounded-xl border bg-popover p-2.5 shadow-lg"
            style={{"left": str(left) + "px", "top": str(top) + "px"}}
            onClick={lambda (e: MouseEvent) { e.stopPropagation(); }}
            onPointerDown={lambda (e: any) { e.stopPropagation(); }}
        >
            <div
                className="mb-1.5 flex items-center gap-1 text-xs font-medium text-muted-foreground"
            >
                <span className="truncate">{fromName}</span>
                <span aria-hidden="true">→</span>
                <span className="truncate">{toName}</span>
            </div>
            <Input
                autoFocus={True}
                aria-label="What has to be true to move on"
                value={form["label"] or ""}
                placeholder="What has to be true to move on"
                className="h-8 text-[13px]"
                onChange={lambda (e: any) { if onField {
                    onField("label", e.target.value);
                }}}
                onKeyDown={lambda (e: any) { if e.key == "Enter" and onSave {
                    onSave();
                }}}
            />
            <EdgePicks
                label="Carries"
                picks={CARRY_PICKS}
                value={form["carries"] or ""}
                onPick={lambda (v: str) { if onField { onField("carries", v); }}}
            />
            <EdgePicks
                label="Moves"
                picks={TRIGGER_PICKS}
                value={trigger}
                onPick={lambda (v: str) { if onField { onField("trigger", v); }}}
            />
            {if trigger == "label" {
                <Input
                    key="match"
                    aria-label="GitHub label"
                    value={form["trigger_label"] or ""}
                    placeholder="GitHub label, e.g. ready-to-review"
                    className="mt-2 h-8 text-[13px]"
                    onChange={lambda (e: any) { if onField {
                        onField("trigger_label", e.target.value);
                    }}}
                    onKeyDown={lambda (e: any) { if e.key == "Enter" and onSave {
                        onSave();
                    }}}
                />
            }}
            {if note {
                <p key="note" className="mt-1.5 text-xs text-subtle">
                    {"On the issue or its PR, the task " + note + "."
                        if trigger == "label"
                        else "The task " + note + "."}
                </p>
            }}
            <EdgeActions
                clearable={clearable}
                onSave={onSave}
                onClear={onClear}
                onDelete={onDelete}
            />
        </div>;
}
