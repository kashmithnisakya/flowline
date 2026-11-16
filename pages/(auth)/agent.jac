"""flowline - an agent's canvas (/agent?id=): the flow drawn for one agent, with
nodes to move, connect and edit, a panel for the selected node, and a check of
what stops it running. The When node edits the agent's own setup; every other
node is saved with the canvas. Stateful shell: data here, parts under
components/agents/canvas."""

import from "@jac/runtime" { Link }
import from ...models { AgentView, RoleView, StepView }
import from ...lib.workspace { loadWorkspace, forgetWorkspace }
import from ...lib.agents { startCanvas, statusOf, modelLabel, nodeId }
import from ...lib.canvas { newNode, findNode, flowProblems, roleName }
import from ...services.agents.crew { ListAgents, SaveAgent, SaveAgentCanvas }
import from ...services.agents.keys { ListAiKeys }
import from ...components.common.AiMark { AiMark }
import from ...components.common.LoadFailed { LoadFailed }
import from ...components.ui.button { Button }
import from ...components.ui.skeleton { Skeleton }
import from ...components.agents.canvas.AgentCanvas { AgentCanvas }
import from ...components.agents.canvas.CanvasPalette { CanvasPalette }
import from ...components.agents.canvas.NodeInspector { NodeInspector }
import from "sonner" { toast }

def:pub AgentPage -> JsxPage {
    has agent: AgentView | None = None,
        nodes: list[dict[str, any]] = [],
        edges: list[dict[str, str]] = [],
        steps: list[StepView] = [],
        roles: list[RoleView] = [],
        models: list[list[str]] = [],
        sel: str = "",
        selEdge: str = "",
        link: str = "",
        problems: list[str] = [],
        checked: bool = False,
        dirty: bool = False,
        saving: bool = False,
        loading: bool = True,
        missing: bool = False;

    can with entry {
        load();
    }

    async def load -> None;
    async def saveSetup(wanted: list[str], event: str) -> None;
    async def saveCanvas -> None;
    def moveNode(id: str, x: float, y: float) -> None;
    def addNode(kind: str) -> None;
    def setCfg(key: str, value: str) -> None;
    def connectFrom(id: str) -> None;
    def connectTo(id: str) -> None;
    def removeNode -> None;
    def removeEdge -> None;
    def pickNode(id: str) -> None;
    def toggleStep(id: str) -> None;
    def resetToSetup -> None;
    def check -> None;

    handlers: dict[str, any] = {
        "onToggleStep": toggleStep,
        "onEvent": lambda (v: str) { saveSetup([], v); },
        "onCfg": setCfg,
        "onDeleteNode": removeNode,
        "onDeleteEdge": removeEdge
    };

    if missing {
        return
            <LoadFailed
                title="That agent is gone"
                onRetry={lambda { window.location.href = "/ai"; }}
                retrying={False}
            />;
    }
    if agent is None or loading {
        return <Skeleton className="h-[520px] w-full"/>;
    }
    status = statusOf(agent, models);
    return
        <div className="flex min-w-0 flex-col gap-3">
            <div className="flex flex-wrap items-center gap-2">
                <Link
                    to="/ai?tab=agents"
                    className="inline-flex h-7 items-center rounded-sm px-2 text-[13px] text-muted-foreground hover:bg-accent"
                >
                    Back to agents
                </Link>
                <AiMark/>
                <h1 className="page-title">{agent.name}</h1>
                <span className="chip text-[12px] text-muted-foreground">
                    {roleName(roles, agent.role_id)}
                </span>
                <span className="text-[12px] text-muted-foreground">
                    {modelLabel(agent.model, models)}
                </span>
                <span
                    className={"ai-chip "
                        + ("" if status[1] == "warn" else "ai-chip-settled")}
                >
                    {status[0]}
                </span>
                {if dirty {
                    <span key="dirty" className="text-[12px] text-muted-foreground">
                        Unsaved changes
                    </span>
                }}
                <div className="ml-auto flex gap-2">
                    <Button variant="outline" onClick={lambda { resetToSetup(); }}>
                        Reset to setup
                    </Button>
                    <Button variant="outline" onClick={lambda { check(); }}>
                        Check flow
                    </Button>
                    <Button disabled={saving} onClick={lambda { saveCanvas(); }}>
                        Save flow
                    </Button>
                </div>
            </div>
            <div className="grid gap-3 lg:grid-cols-[150px_minmax(0,1fr)_290px]">
                <CanvasPalette onAdd={addNode}/>
                <AgentCanvas
                    agent={agent}
                    nodes={nodes}
                    edges={edges}
                    steps={steps}
                    roles={roles}
                    sel={sel}
                    selEdge={selEdge}
                    link={link}
                    states={{}}
                    onSelect={pickNode}
                    onMove={moveNode}
                    onDropped={lambda { dirty = True; }}
                    onOut={connectFrom}
                    onIn={connectTo}
                    onEdge={lambda (id: str) {
                        selEdge = id;
                        sel = "";
                    }}
                />
                <aside className="surface p-3" aria-label="Selected node">
                    <NodeInspector
                        agent={agent}
                        item={findNode(nodes, sel)}
                        edgeOn={selEdge != ""}
                        steps={steps}
                        roles={roles}
                        handlers={handlers}
                    />
                </aside>
            </div>
            {if checked {
                <section key="checks" className="surface p-3" aria-label="Flow check">
                    {if len(problems) == 0 {
                        <p key="fine" className="text-sm">
                            Nothing stops this flow from running.
                        </p>
                    } else {
                        <ul
                            key="list"
                            className="flex list-disc flex-col gap-1 pl-5 text-sm"
                        >
                            {for p in problems {
                                <li key={p}>{p}</li>
                            }}
                        </ul>
                    } }
                </section>
            }}
        </div>;
}
