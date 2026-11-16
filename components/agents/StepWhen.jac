"""Step 2: which projects the agent works in and when it wakes: a task landing
on the steps picked, or an event."""

import from ...models { StepView, Project }
import from ...constants { AGENT_EVENTS }
import from .PickChip { PickChip }
import from ..ui.label { Label }

def:pub StepWhen(
    draft: dict[str, any],
    steps: list[StepView],
    projects: list[Project],
    onField: Callable[[str, any], None],
    onToggleStep: Callable[[str], None],
    onToggleProject: Callable[[str], None]
) -> JsxElement {
    everywhere = len(draft["projects"]) == 0;
    return
        <div className="flex flex-col gap-5">
            <div className="grid gap-2">
                <Label>Projects</Label>
                <div className="flex flex-wrap gap-2">
                    <PickChip
                        label="All projects"
                        on={everywhere}
                        onClick={lambda { onField("projects", []); }}
                    />
                    {for p in projects {
                        <PickChip
                            key={jid(p)}
                            label={p.name}
                            on={jid(p) in draft["projects"]}
                            onClick={lambda { onToggleProject(jid(p)); }}
                        />
                    }}
                </div>
            </div>
            <div className="grid gap-2">
                <Label>Runs when a task lands on</Label>
                <div className="flex flex-wrap gap-2">
                    {for s in steps {
                        <PickChip
                            key={s.id}
                            label={s.name}
                            on={s.id in draft["steps"]}
                            hint={s.kind}
                            onClick={lambda { onToggleStep(s.id); }}
                        />
                    }}
                </div>
            </div>
            <div className="grid gap-2">
                <Label htmlFor="agent-event">Or when</Label>
                <select
                    id="agent-event"
                    className="h-8 rounded-sm border bg-card px-2 text-[13px]"
                    value={draft["event"]}
                    onChange={lambda (e: ChangeEvent) { onField(
                        "event", e.target.value
                    ); }}
                >
                    {for ev in AGENT_EVENTS {
                        <option key={ev[0]} value={ev[0]}>{ev[1]}</option>
                    }}
                </select>
                <p className="meta">
                    Only a task landing on a step runs an agent today. An event is saved for when it does.
                </p>
            </div>
        </div>;
}
