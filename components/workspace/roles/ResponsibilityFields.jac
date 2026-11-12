"""The editor's fields: where it runs and how far it may go (ResponsibilityScope),
the team's instructions (capped at AGENT_LIMITS.max_instructions), the model
and its own switch.
"""

import from ....models { StepView }
import from ....constants { AGENT_LIMITS }
import from ...ui.input { Input }
import from ...ui.label { Label }
import from ...ui.switch { Switch }
import from ...ui.textarea { Textarea }
import from .ResponsibilityScope { ResponsibilityScope }

def:pub ResponsibilityFields(
    form: dict[str, str],
    picked: list[str],
    steps: list[StepView],
    onField: Callable[[str, str], None],
    onToggleStep: Callable[[str], None]
) -> JsxElement {
    cap = AGENT_LIMITS["max_instructions"];
    return
        <div className="flex flex-col gap-5">
            <ResponsibilityScope
                mode={form["mode"]}
                picked={picked}
                steps={steps}
                onField={onField}
                onToggleStep={onToggleStep}
            />
            <div className="flex flex-col gap-2">
                <Label htmlFor="resp-instructions">Instructions</Label>
                <Textarea
                    id="resp-instructions"
                    rows={4}
                    maxLength={cap}
                    placeholder="Check error handling and follow our style guide."
                    value={form["instructions"]}
                    onChange={lambda (e: ChangeEvent) { onField(
                        "instructions", e.target.value
                    ); }}
                />
                <p className="num text-right text-[12px] text-subtle">
                    {str(len(form["instructions"])) + " / " + str(cap)}
                </p>
            </div>
            <div className="flex flex-col gap-2">
                <Label htmlFor="resp-model">Model</Label>
                <Input
                    id="resp-model"
                    placeholder="The server's default model"
                    value={form["model"]}
                    onChange={lambda (e: ChangeEvent) { onField(
                        "model", e.target.value
                    ); }}
                />
            </div>
            <div className="flex items-center gap-3">
                <Switch
                    id="resp-enabled"
                    checked={form["enabled"] == "yes"}
                    onCheckedChange={lambda (v: bool) { onField(
                        "enabled", "yes" if v else ""
                    ); }}
                />
                <Label htmlFor="resp-enabled">On</Label>
            </div>
        </div>;
}
