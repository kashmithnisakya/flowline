"""The Agents tab: every agent and the create and edit dialog. It loads its own
lists (agents, roles, steps, projects, model keys) and reloads them after a write."""

import from ...models { AgentView, RoleView, StepView, Project }
import from ...lib.workspace { loadWorkspace, forgetWorkspace }
import from "@jac/runtime" { navigate }
import from ...lib.agents {
    blankAgent,
    draftOf,
    applyDuties,
    withAccess,
    seedFor,
    agentOf
}
import from ...services.agents.crew {
    ListAgents,
    SaveAgent,
    SetAgentEnabled,
    DeleteAgent
}
import from ...services.agents.keys { ListAiKeys }
import from ..ui.button { Button }
import from .AgentTable { AgentTable }
import from .AgentDialog { AgentDialog }
import from "sonner" { toast }

def:pub AgentsPanel(onGoKeys: Callable[[], None]) -> JsxElement {
    has agents: list[AgentView] = [],
        roles: list[RoleView] = [],
        steps: list[StepView] = [],
        projects: list[Project] = [],
        models: list[list[str]] = [],
        defaultModel: str = "",
        loading: bool = True,
        open: bool = False,
        editing: bool = False,
        step: int = 0,
        draft: dict[str, any] = blankAgent(""),
        saving: bool = False,
        busyId: str = "";

    can with entry {
        load();
    }

    async def load -> None;
    async def save -> None;
    async def toggle(id: str, wanted: bool) -> None;
    async def remove(target: AgentView) -> None;
    async def makeForEveryRole -> None;
    def startCreate -> None;
    def startEdit(a: AgentView) -> None;
    def setField(key: str, value: any) -> None;
    def pickRole(id: str) -> None;
    def toggleDuty(key: str) -> None;
    def flip(key: str, id: str) -> None;
    def setAccess(kind: str, on: bool) -> None;
    def toggleTool(key: str) -> None;
    def next -> None;
    def back -> None;
    def makeHandlers -> dict[str, any];

    handlers = makeHandlers();

    return
        <div className="flex flex-col gap-3">
            <div className="flex items-center gap-3">
                <p className="text-sm text-muted-foreground">
                    Each agent plays one role and works on your own API key.
                </p>
                <Button className="ml-auto" onClick={lambda { startCreate(); }}>
                    Create agent
                </Button>
            </div>
            <AgentTable
                agents={agents}
                roles={roles}
                steps={steps}
                models={models}
                busyId={busyId}
                loading={loading}
                onCreate={startCreate}
                onToggle={toggle}
                onEdit={startEdit}
                onDelete={remove}
            />
            <AgentDialog
                open={open}
                editing={editing}
                step={step}
                draft={draft}
                roles={roles}
                steps={steps}
                projects={projects}
                models={models}
                saving={saving}
                handlers={handlers}
            />
        </div>;
}
