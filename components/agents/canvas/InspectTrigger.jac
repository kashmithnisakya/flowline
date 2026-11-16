"""The When node's settings. They are the agent's own setup, so a change here
saves the agent, not only the canvas."""

import from ....models { StepView }
import from ....constants { AGENT_EVENTS }
import from ..PickChip { PickChip }
import from ...ui.label { Label }

def:pub InspectTrigger(
    steps: list[StepView],
    picked: list[str],
    event: str,
    onToggleStep: Callable[[str], None],
    onEvent: Callable[[str], None]
) -> JsxElement {
    return
        <div className="flex flex-col gap-3">
            <div className="grid gap-2">
                <Label>Runs when a task lands on</Label>
                <div className="flex flex-wrap gap-2">
                    {for s in steps {
                        <PickChip
                            key={s.id}
                            label={s.name}
                            on={s.id in picked}
                            onClick={lambda { onToggleStep(s.id); }}
                        />
                    }}
                </div>
            </div>
            <div className="grid gap-2">
                <Label htmlFor="insp-event">Or when</Label>
                <select
                    id="insp-event"
                    className="h-8 rounded-sm border bg-card px-2 text-[13px]"
                    value={event}
                    onChange={lambda (e: ChangeEvent) { onEvent(e.target.value); }}
                >
                    {for ev in AGENT_EVENTS {
                        <option key={ev[0]} value={ev[0]}>{ev[1]}</option>
                    }}
                </select>
            </div>
        </div>;
}
