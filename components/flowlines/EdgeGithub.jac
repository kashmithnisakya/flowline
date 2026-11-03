"""The arrow editor's GitHub part: the arrow's label, whether it stays on once
the task moves past, and in words what the label does (a label trigger moves
work when it appears; a repo with label sync writes it on each move)."""

import from .kinds { triggerNote }
import from ..ui.input { Input }
import from ..ui.switch { Switch }

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
        <>
            <div className="flex flex-col gap-1.5">
                <label className="text-[13px] font-medium" htmlFor="edge-github-label">
                    GitHub label
                </label>
                <Input
                    id="edge-github-label"
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
            </div>
            <label
                htmlFor="edge-keep-label"
                className="flex items-center gap-2 text-[13px]"
            >
                <Switch
                    id="edge-keep-label"
                    checked={form["keep_label"] == "yes"}
                    disabled={not named}
                    onCheckedChange={lambda (on: bool) { if onField {
                        onField("keep_label", "yes" if on else "");
                    }}}
                />
                Keep the label after the task leaves
            </label>
            {if said {
                <p key="note" className="meta">{said}</p>
            }}
        </>;
}
