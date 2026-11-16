"""The body of the agent dialog: the one step on screen, from the five."""

import from ...models { RoleView, StepView, Project }
import from .StepRole { StepRole }
import from .StepWhen { StepWhen }
import from .StepTools { StepTools }
import from .StepPrompt { StepPrompt }
import from .StepModel { StepModel }

def:pub AgentSteps(
    step: int,
    editing: bool,
    draft: dict[str, any],
    roles: list[RoleView],
    steps: list[StepView],
    projects: list[Project],
    models: list[list[str]],
    handlers: dict[str, any]
) -> JsxElement {
    if step == 0 {
        return
            <StepRole
                draft={draft}
                roles={roles}
                editing={editing}
                onPick={handlers["onPickRole"]}
                onField={handlers["onField"]}
                onAll={handlers["onAllRoles"]}
            />;
    }
    if step == 1 {
        return
            <StepWhen
                draft={draft}
                steps={steps}
                projects={projects}
                onField={handlers["onField"]}
                onToggleStep={handlers["onToggleStep"]}
                onToggleProject={handlers["onToggleProject"]}
            />;
    }
    if step == 2 {
        return
            <StepTools
                draft={draft}
                onToggleDuty={handlers["onToggleDuty"]}
                onAccess={handlers["onAccess"]}
                onToggleTool={handlers["onToggleTool"]}
                onField={handlers["onField"]}
            />;
    }
    if step == 3 {
        return <StepPrompt draft={draft} onField={handlers["onField"]}/>;
    }
    return
        <StepModel
            draft={draft}
            models={models}
            onField={handlers["onField"]}
            onGoKeys={handlers["onGoKeys"]}
        />;
}
