"""The agents as a list under one header, or an empty state that says what an
agent is and how to make the first one."""

import from ...models { AgentView, RoleView, StepView }
import from ..ui.button { Button }
import from ..ui.skeleton { Skeleton }
import from .AgentRow { AgentRow }
import from .DeleteAgentDialog { DeleteAgentDialog }

def roleNameOf(roles: list[RoleView], id: str) -> str {
    for r in roles {
        if r.id == id {
            return r.name;
        }
    }
    return "A deleted role";
}

def:pub AgentTable(
    agents: list[AgentView],
    roles: list[RoleView],
    steps: list[StepView],
    models: list[list[str]],
    busyId: str,
    loading: bool,
    onCreate: Callable[[], None],
    onToggle: Callable[[str, bool], None],
    onEdit: Callable[[AgentView], None],
    onDelete: Callable[[AgentView], None]
) -> JsxElement {
    has deleting: AgentView | None = None;

    if loading {
        return <Skeleton className="h-40 w-full"/>;
    }
    if len(agents) == 0 {
        return
            <div
                className="surface flex flex-col items-center gap-3 px-6 py-12 text-center"
            >
                <p className="text-sm font-semibold">No agents yet</p>
                <p className="max-w-md text-sm text-muted-foreground">
                    An agent is an AI teammate that plays one of your roles. It wakes on the steps you pick, uses only the tools you allow, and works on your own API key.
                </p>
                <Button onClick={lambda { onCreate(); }}>Create agent</Button>
            </div>;
    }
    return
        <>
            <div className="surface">
                <div
                    className="hidden grid-cols-[minmax(0,1.3fr)_minmax(0,1fr)_minmax(0,1.2fr)_minmax(0,1fr)_auto] items-center gap-x-4 border-b px-3 py-2 text-[12.5px] text-muted-foreground md:grid"
                >
                    <span>Agent</span>
                    <span>Role</span>
                    <span>Runs when</span>
                    <span>Model</span>
                    <span className="w-[288px]"/>
                </div>
                <ul className="divide-y">
                    {for a in agents {
                        <AgentRow
                            key={a.id}
                            agent={a}
                            roleName={roleNameOf(roles, a.role_id)}
                            steps={steps}
                            models={models}
                            busy={busyId == a.id}
                            onToggle={lambda (v: bool) { onToggle(a.id, v); }}
                            onEdit={lambda { onEdit(a); }}
                            onDelete={lambda { deleting = a; }}
                        />
                    }}
                </ul>
            </div>
            <DeleteAgentDialog
                agent={deleting}
                busy={busyId != ""}
                onConfirm={lambda {
                    if deleting is not None {
                        onDelete(deleting);
                    }
                    deleting = None;
                }}
                onCancel={lambda { deleting = None; }}
            />
        </>;
}
