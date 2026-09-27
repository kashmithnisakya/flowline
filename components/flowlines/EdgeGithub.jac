"""The transition editor's GitHub part: the arrow's label, whether it stays on
once the task moves past, and in words what the label does (a label trigger
moves work when it appears; a repo with label sync writes it on each move)."""

import from .kinds { triggerNote }
import from ..ui.input { Input }
import from ..ui.checkbox { Checkbox }

def:pub EdgeGithub(
    form: dict[str, str],
    onField: Callable[[str, str], None] = None,
    onSave: Callable[[], None] = None
) -> JsxElement {
    named = (form["github_label"] or "").strip();
    trigger = form["trigger"] or "";
    moves = triggerNote(trigger, named or "…");
    said = ("The task " + moves + ". " if moves else "")
        + (
            "Moving work across adds it on GitHub for repos that write labels."
                if named
                else ""
        );
    return
        <div className="mt-2 flex flex-col gap-1.5">
            <span className="text-xs text-muted-foreground">GitHub label</span>
            <Input
                aria-label="GitHub label"
                value={form["github_label"] or ""}
                placeholder="e.g. ready-to-review"
                className="h-8 text-[13px]"
                onChange={lambda (e: any) { if onField {
                    onField("github_label", e.target.value);
                }}}
                onKeyDown={lambda (e: any) { if e.key == "Enter" and onSave {
                    onSave();
                }}}
            />
            {if named {
                <label
                    key="keep"
                    htmlFor="edge-keep-label"
                    className="flex items-center gap-2 text-xs text-muted-foreground"
                >
                    <Checkbox
                        id="edge-keep-label"
                        checked={form["keep_label"] == "yes"}
                        onCheckedChange={lambda (on: bool) { if onField {
                            onField("keep_label", "yes" if on else "");
                        }}}
                    />
                    Keep it after the task moves on
                </label>
            }}
            {if said {
                <p key="note" className="text-xs text-subtle">{said}</p>
            }}
        </div>;
}
