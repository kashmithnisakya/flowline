"""Step 5: the model, from the keys the workspace has saved. With none, a note
that agents run on the workspace's own key, never Flowline's, and a way there."""

import from ..ui.button { Button }
import from ..ui.label { Label }

def:pub StepModel(
    draft: dict[str, any],
    models: list[list[str]],
    onField: Callable[[str, any], None],
    onGoKeys: Callable[[], None]
) -> JsxElement {
    if len(models) == 0 {
        return
            <div
                className="flex flex-wrap items-center gap-3 rounded-md border border-dashed border-ai bg-ai-wash p-3 text-sm"
            >
                <span className="min-w-[240px] flex-1">
                    No API key yet. Agents run on your own key, so Flowline never spends its tokens on your work. You can create the agent now and add a key after.
                </span>
                <Button
                    type="button"
                    variant="outline"
                    onClick={lambda { onGoKeys(); }}
                >
                    Add an API key
                </Button>
            </div>;
    }
    return
        <div className="grid max-w-sm gap-2">
            <Label htmlFor="agent-model">Model</Label>
            <select
                id="agent-model"
                className="h-8 rounded-sm border bg-card px-2 text-[13px]"
                value={draft["model"]}
                onChange={lambda (e: ChangeEvent) { onField("model", e.target.value); }}
            >
                <option value="">Choose a model</option>
                {for m in models {
                    <option key={m[0]} value={m[0]}>{m[1]}</option>
                }}
            </select>
            <p className="meta">From the keys saved under Models and keys.</p>
        </div>;
}
