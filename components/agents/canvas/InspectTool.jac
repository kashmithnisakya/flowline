"""A Tool node's settings: which tool, what it does, and a note when the agent's
access does not cover it (the server refuses it at run time)."""

import from ....constants { AGENT_TOOLS }
import from ....lib.agents { toolKind, covers }
import from ...ui.label { Label }

def:pub InspectTool(
    tool: str, access: dict[str, bool], onTool: Callable[[str], None]
) -> JsxElement {
    kind = toolKind(tool);
    does = "";
    for t in AGENT_TOOLS {
        if t["key"] == tool {
            does = t["does"];
        }
    }
    return
        <div className="grid gap-2">
            <Label htmlFor="insp-tool">Tool</Label>
            <select
                id="insp-tool"
                className="h-8 rounded-sm border bg-card px-2 text-[13px]"
                value={tool}
                onChange={lambda (e: ChangeEvent) { onTool(e.target.value); }}
            >
                {for t in AGENT_TOOLS {
                    <option key={t["key"]} value={t["key"]}>
                        {t["key"] + " (" + t["kind"] + ")"}
                    </option>
                }}
            </select>
            <p className="meta">{does}</p>
            {if not covers(access, kind) {
                <p
                    key="lock"
                    className="rounded-md border border-dashed border-ai bg-ai-wash p-2 text-[13px]"
                >
                    {"This agent has no "
                        + kind
                        + " access, so this tool is refused. Change access under Edit."}
                </p>
            }}
        </div>;
}
