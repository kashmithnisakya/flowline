"""The selected arrow's popover over the canvas: `form` holds its label, carries,
trigger, GitHub label and keep label, and every field saves together. Escape
cancels; its height is capped to the canvas so Save is never clipped away."""

import from .kinds { TRIGGER_PICKS }
import from .EdgeGithub { EdgeGithub }
import from .EdgePicks { EdgePicks }
import from .EdgeActions { EdgeActions }
import from ..ui.input { Input }

glob CARRY_PICKS: list[dict[str, str]] = [
         {"key": "", "text": "Nothing"},
         {"key": "issue", "text": "Issue"},
         {"key": "pr", "text": "Pull request"}
     ];

def:pub EdgeEditor(
    fromName: str,
    toName: str,
    form: dict[str, str],
    left: float = 0.0,
    top: float = 0.0,
    onField: Callable[[str, str], None] = None,
    onSave: Callable[[], None] = None,
    onCancel: Callable[[], None] = None,
    onDelete: Callable[[], None] = None
) -> JsxElement {
    return
        <div
            role="dialog"
            aria-label={"Edit arrow from " + fromName + " to " + toName}
            className="absolute z-40 flex max-h-[calc(100%-1rem)] w-80 max-w-[calc(100%-1rem)] -translate-x-1/2 flex-col gap-3 overflow-y-auto rounded-xl border bg-popover p-3.5 shadow-lg"
            style={{"left": str(left) + "px", "top": str(top) + "px"}}
            onClick={lambda (e: MouseEvent) { e.stopPropagation(); }}
            onPointerDown={lambda (e: any) { e.stopPropagation(); }}
            onKeyDown={lambda (e: any) { if e.key == "Escape" and onCancel {
                onCancel();
            }}}
        >
            <p className="flex min-w-0 items-center gap-1.5 text-[13px] font-semibold">
                <span className="truncate">{fromName}</span>
                <svg
                    width={13}
                    height={13}
                    viewBox="0 0 16 16"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={1.5}
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    aria-hidden="true"
                    className="shrink-0"
                >
                    <path d="M3 8h9.5M9 4.5 12.5 8 9 11.5"/>
                </svg>
                <span className="truncate">{toName}</span>
            </p>
            <div className="flex flex-col gap-1.5">
                <label className="text-[13px] font-medium" htmlFor="edge-label">
                    Label
                </label>
                <Input
                    id="edge-label"
                    autoFocus={True}
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
            </div>
            <EdgePicks
                label="Carries"
                picks={CARRY_PICKS}
                value={form["carries"] or ""}
                onPick={lambda (v: str) { if onField { onField("carries", v); }}}
            />
            <EdgePicks
                label="Moves on its own when"
                picks={TRIGGER_PICKS}
                value={form["trigger"] or ""}
                onPick={lambda (v: str) { if onField { onField("trigger", v); }}}
            />
            <EdgeGithub form={form} onField={onField} onSave={onSave}/>
            <EdgeActions onSave={onSave} onCancel={onCancel} onDelete={onDelete}/>
        </div>;
}
