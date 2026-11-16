"""A Prompt node's settings: the text and the variables that can go in it."""

import from ....constants { AGENT_SETUP }
import from ...ui.label { Label }
import from ...ui.textarea { Textarea }

glob VARS: list[str] = [
         "{task.title}",
         "{task.notes}",
         "{pr.diff}",
         "{step.name}"
     ];

def:pub InspectPrompt(
    text: str, model: str, onText: Callable[[str], None]
) -> JsxElement {
    return
        <div className="grid gap-2">
            <Label htmlFor="insp-prompt">Prompt</Label>
            <Textarea
                id="insp-prompt"
                rows={7}
                maxLength={AGENT_SETUP["node_text"]}
                className="font-mono text-[12.5px]"
                value={text}
                onChange={lambda (e: ChangeEvent) { onText(e.target.value); }}
            />
            <div className="flex flex-wrap gap-1.5">
                {for v in VARS {
                    <button
                        key={v}
                        type="button"
                        className="h-6 rounded-sm border px-1.5 font-mono text-[12px] hover:bg-accent"
                        onClick={lambda { onText(text + (" " if text else "") + v); }}
                    >
                        {v}
                    </button>
                }}
            </div>
            <p className="meta">{"Model: " + (model or "none chosen")}</p>
        </div>;
}
