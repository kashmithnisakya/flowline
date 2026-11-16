"""Step 4: the prompt (who the agent is and how it works) and its rules. Access
is enforced by the server, not by this text."""

import from ...constants { AGENT_SETUP }
import from ..ui.label { Label }
import from ..ui.textarea { Textarea }

glob VARS: list[str] = [
         "{task.title}",
         "{task.notes}",
         "{pr.diff}",
         "{step.name}"
     ];

def:pub StepPrompt(
    draft: dict[str, any], onField: Callable[[str, any], None]
) -> JsxElement {
    return
        <div className="flex flex-col gap-5">
            <div className="grid gap-2">
                <Label htmlFor="agent-prompt">Prompt</Label>
                <Textarea
                    id="agent-prompt"
                    rows={6}
                    maxLength={AGENT_SETUP["prompt"]}
                    className="font-mono text-[12.5px]"
                    value={draft["prompt"]}
                    onChange={lambda (e: ChangeEvent) { onField(
                        "prompt", e.target.value
                    ); }}
                />
                <div className="flex flex-wrap gap-1.5">
                    {for v in VARS {
                        <button
                            key={v}
                            type="button"
                            className="num h-6 rounded-sm border px-1.5 font-mono text-[12px] hover:bg-accent"
                            onClick={lambda { onField(
                                "prompt",
                                draft["prompt"] + (" " if draft["prompt"] else "") + v
                            ); }}
                        >
                            {v}
                        </button>
                    }}
                </div>
            </div>
            <div className="grid gap-2">
                <Label htmlFor="agent-rules">Duties and rules</Label>
                <Textarea
                    id="agent-rules"
                    rows={3}
                    maxLength={AGENT_SETUP["rules"]}
                    placeholder="Never approve your own work. Ask a person when unsure."
                    value={draft["rules"]}
                    onChange={lambda (e: ChangeEvent) { onField(
                        "rules", e.target.value
                    ); }}
                />
            </div>
        </div>;
}
