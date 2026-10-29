"""Native contextual step inspection. Drafts belong to the page so moving
between steps, versions or view modes cannot discard an unsaved note."""

import from ...models { ProcessView }
import from ...services.processes.processes { SaveProcessNote }
import from ..ui.button { Button }
import from ..ui.textarea { Textarea }
import from ..ui.label { Label }
import from ..common.glyphs { Spinner }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Cancel01Icon }
import from .ProcessMap { nodeById }

def:pub StepReview(
    process: ProcessView,
    step: dict[str, str],
    note: str,
    onNote: Callable[[str], None],
    onSaved: Callable[[], any],
    onJump: Callable[[str], None],
    onClose: Callable[[], None]
) -> JsxElement {
    has message: str = "",
        busy: bool = False,
        failed: bool = False;

    async def save {
        busy = True;
        failed = False;
        message = "";
        try {
            result = root spawn SaveProcessNote(
                process_id=process.id, step_id=step["id"], note=note
            );
            data = result.reports[0] if result.reports else {};
            if data.get("ok", False) {
                await onSaved();
                message = "Saved to this workspace";
            } else {
                failed = True;
                message = "Could not save. Your note is still here.";
            }
        } except Exception {
            failed = True;
            message = "Could not save. Your note is still here.";
        }
        busy = False;
    }

    saved = process.review_notes[step["id"]]
        if step["id"] in process.review_notes
        else "";
    dirty = note.strip() != saved;
    versionName = "Current" if process.variant == "current" else "Proposed";
    return
        <aside
            aria-label="Step details"
            className="flex min-h-0 flex-1 flex-col overflow-hidden"
        >
            <header
                className="flex items-start gap-2 border-b border-border-subtle px-4 py-3"
            >
                <div className="min-w-0 flex-1">
                    <p className="mb-1 text-xs text-text-tertiary">
                        {versionName + " · " + step["status"]}
                    </p>
                    <h2 className="section-title">{step["title"]}</h2>
                    <p className="mt-1 text-xs text-muted-foreground">
                        {step["owner"]}
                    </p>
                </div>
                <Button
                    variant="ghost"
                    size="icon-sm"
                    aria-label="Close step details"
                    onClick={onClose}
                >
                    <HugeiconsIcon icon={Cancel01Icon} strokeWidth={2}/>
                </Button>
            </header>
            <div className="min-h-0 flex-1 overflow-y-auto p-4 text-[13px] leading-5">
                <p>{step["detail"]}</p>
                <dl className="mt-4 grid gap-3">
                    {for field in [
                        ["Entry / decision rule", "guard"],
                        ["Inputs", "inputs"],
                        ["Outputs", "outputs"],
                        ["Tools / dependencies", "tool"]
                    ] {
                        <div key={field[1]}>
                            <dt
                                className="mb-0.5 text-xs font-medium text-text-tertiary"
                            >
                                {field[0]}
                            </dt>
                            <dd>{step[field[1]]}</dd>
                        </div>
                    }}
                </dl>
                <h3 className="mt-5 mb-2 text-[13px] font-semibold">
                    Next steps and rework
                </h3>
                <ul className="grid gap-2">
                    {for (i, t) in enumerate(process.transitions) {
                        if t["source"] == step["id"] {
                            <li key={str(i)} className="min-w-0">
                                <p className="text-xs text-muted-foreground">
                                    {t["label"] or "Continue"}
                                </p>
                                <button
                                    type="button"
                                    className="text-left font-medium text-foreground underline decoration-border-strong underline-offset-4 hover:decoration-foreground"
                                    onClick={lambda { onJump(t["target"]); }}
                                >
                                    {nodeById(process.steps, t["target"])["title"]
                                        + " →"}
                                </button>
                                {if t["kind"] == "return" {
                                    <span
                                        key="return"
                                        className="ml-1 text-xs text-text-tertiary"
                                    >
                                        Rework
                                    </span>
                                }}
                            </li>
                        }
                    }}
                </ul>
                <div className="mt-5 border-t pt-4">
                    <Label htmlFor="process-note">Review note</Label>
                    <p className="mt-1 mb-2 text-xs text-muted-foreground">
                        A comment, not an approval or execution result.
                    </p>
                    <Textarea
                        id="process-note"
                        value={note}
                        rows={4}
                        maxLength={6000}
                        disabled={busy}
                        placeholder="What should we change or clarify?"
                        onChange={lambda (e: ChangeEvent) {
                            onNote(e.target.value);
                            message = "";
                            failed = False;
                        }}
                    />
                    <div className="mt-3 flex flex-wrap items-center gap-3">
                        <Button size="sm" disabled={busy} onClick={save}>
                            {if busy {
                                <Spinner key="busy"/>
                            }}
                            {"Saving…"
                                if busy
                                else ("Try again" if failed else "Save note")}
                        </Button>
                        <p
                            role={"alert" if failed else "status"}
                            className={"text-xs "
                                + (
                                    "text-destructive"
                                        if failed
                                        else "text-muted-foreground"
                                )}
                        >
                            {message or ("Unsaved changes" if dirty else "")}
                        </p>
                    </div>
                    <p className="mt-2 text-xs text-text-tertiary">
                        Drafts stay while you switch views. Save to keep after reload.
                    </p>
                </div>
            </div>
        </aside>;
}
