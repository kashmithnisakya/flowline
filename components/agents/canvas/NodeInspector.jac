"""The panel beside the canvas: the selected node's settings, or the selected
connection's delete, or a hint when nothing is selected."""

import from ....models { AgentView, StepView, RoleView }
import from ....lib.canvas { nodeTitle }
import from ...ui.button { Button }
import from .InspectTrigger { InspectTrigger }
import from .InspectPrompt { InspectPrompt }
import from .InspectTool { InspectTool }
import from .InspectOther { InspectOther }

def:pub NodeInspector(
    agent: AgentView,
    item: dict[str, any],
    edgeOn: bool,
    steps: list[StepView],
    roles: list[RoleView],
    handlers: dict[str, any]
) -> JsxElement {
    if edgeOn {
        return
            <div className="flex flex-col gap-3">
                <h3 className="text-sm font-semibold">Connection</h3>
                <Button
                    variant="outline"
                    className="text-destructive"
                    onClick={lambda { handlers["onDeleteEdge"](); }}
                >
                    Delete connection
                </Button>
            </div>;
    }
    if not item["id"] {
        return
            <p className="text-sm text-muted-foreground">
                Select a node to edit it. Drag a node by its header to move it.
            </p>;
    }
    kind = item["type"];
    cfg = item["cfg"];
    return
        <div className="flex flex-col gap-3">
            <h3 className="text-sm font-semibold">{nodeTitle(kind)}</h3>
            {if kind == "trigger" {
                <InspectTrigger
                    key="t"
                    steps={steps}
                    picked={agent.steps}
                    event={agent.event}
                    onToggleStep={handlers["onToggleStep"]}
                    onEvent={handlers["onEvent"]}
                />
            } elif kind == "prompt" {
                <InspectPrompt
                    key="p"
                    text={cfg["text"] or ""}
                    model={agent.model}
                    onText={lambda (v: str) { handlers["onCfg"]("text", v); }}
                />
            } elif kind == "tool" {
                <InspectTool
                    key="o"
                    tool={cfg["tool"] or "read_task"}
                    access={agent.access}
                    onTool={lambda (v: str) { handlers["onCfg"]("tool", v); }}
                />
            } else {
                <InspectOther
                    key="x"
                    kind={kind}
                    expr={cfg["expr"] or ""}
                    who={cfg["who"] or agent.role_id}
                    roles={roles}
                    onCfg={handlers["onCfg"]}
                />
            }   }
            {if kind != "trigger" {
                <Button
                    key="del"
                    variant="outline"
                    className="self-start text-destructive"
                    onClick={lambda { handlers["onDeleteNode"](); }}
                >
                    Delete node
                </Button>
            }}
        </div>;
}
