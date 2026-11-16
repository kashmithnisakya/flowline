"""Step 3: what the agent may do. Responsibilities fill in tools and a prompt, access
is the ceiling (read always, suggest and write on request), and a tool beyond
the ceiling stays locked."""

import from ...constants { AGENT_TOOLS, AGENT_DUTIES }
import from ...lib.agents { covers }
import from .PickChip { PickChip }
import from ..ui.label { Label }

def:pub StepTools(
    draft: dict[str, any],
    onToggleDuty: Callable[[str], None],
    onAccess: Callable[[str, bool], None],
    onToggleTool: Callable[[str], None],
    onField: Callable[[str, any], None]
) -> JsxElement {
    access: dict[str, bool] = draft["access"];
    return
        <div className="flex flex-col gap-5">
            <div className="grid gap-2">
                <Label>Responsibilities, start from a template</Label>
                <div className="flex flex-wrap gap-2">
                    {for d in AGENT_DUTIES {
                        <PickChip
                            key={d["key"]}
                            label={d["name"]}
                            on={d["key"] in draft["duties"]}
                            onClick={lambda { onToggleDuty(d["key"]); }}
                        />
                    }}
                </div>
                <p className="meta">
                    A review agent (reads a pull request, comments on it) runs today. The others are saved and run soon.
                </p>
            </div>
            <div className="grid gap-2">
                <Label>Access</Label>
                <div className="flex flex-wrap gap-2">
                    <PickChip
                        label="Read"
                        on={True}
                        disabled={True}
                        onClick={lambda {}}
                    />
                    <PickChip
                        label="Suggest"
                        on={bool(access["suggest"])}
                        hint="Proposals a person applies"
                        onClick={lambda { onAccess(
                            "suggest", not bool(access["suggest"])
                        ); }}
                    />
                    <PickChip
                        label="Write"
                        on={bool(access["write"])}
                        hint="Comment, append notes, send a task back"
                        onClick={lambda { onAccess(
                            "write", not bool(access["write"])
                        ); }}
                    />
                </div>
            </div>
            <div className="grid gap-2">
                <Label>Tools</Label>
                <div className="flex flex-wrap gap-2">
                    {for t in AGENT_TOOLS {
                        <PickChip
                            key={t["key"]}
                            label={t["key"]}
                            on={t["key"] in draft["tools"]}
                            disabled={not covers(access, t["kind"])}
                            hint={t["does"] + " (" + t["kind"] + ")"}
                            onClick={lambda { onToggleTool(t["key"]); }}
                        />
                    }}
                </div>
            </div>
            <div className="grid gap-2">
                <Label>Mode</Label>
                <div className="flex gap-2">
                    <PickChip
                        label="Suggest"
                        on={draft["mode"] == "suggest"}
                        onClick={lambda { onField("mode", "suggest"); }}
                    />
                    <PickChip
                        label="Apply"
                        on={draft["mode"] == "apply"}
                        onClick={lambda { onField("mode", "apply"); }}
                    />
                </div>
            </div>
        </div>;
}
