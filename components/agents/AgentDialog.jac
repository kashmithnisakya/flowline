"""The create and edit dialog for an agent: five short steps (role, when, tools,
prompt, model). The panel owns the draft; this shows the step and reports each
change through `onField` and the toggles."""

import from ...models { RoleView, StepView, Project }
import from ..ui.button { Button }
import from ..ui.dialog {
    Dialog,
    DialogContent,
    DialogHeader,
    DialogTitle,
    DialogDescription,
    DialogFooter
}
import from ..common.glyphs { Spinner }
import from ..common.AiMark { AiMark }
import from .AgentSteps { AgentSteps }

glob STEP_NAMES: list[str] = ["Role", "When", "Tools", "Prompt", "Model"];

def:pub AgentDialog(
    open: bool,
    editing: bool,
    step: int,
    draft: dict[str, any],
    roles: list[RoleView],
    steps: list[StepView],
    projects: list[Project],
    models: list[list[str]],
    saving: bool,
    handlers: dict[str, any]
) -> JsxElement {
    last = step == 4;
    blocked = (step == 0 and draft["role_id"] == "") or saving;
    return
        <Dialog open={open} onOpenChange={handlers["onOpenChange"]}>
            <DialogContent className="bg-popover sm:max-w-2xl">
                <DialogHeader>
                    <DialogTitle className="flex items-center gap-2">
                        <AiMark/>
                        {"Edit agent" if editing else "Create agent"}
                    </DialogTitle>
                    <DialogDescription>
                        {"Step " + str(step + 1) + " of 5: " + STEP_NAMES[step]}
                    </DialogDescription>
                </DialogHeader>
                <div className="min-h-[260px] py-1">
                    <AgentSteps
                        step={step}
                        editing={editing}
                        draft={draft}
                        roles={roles}
                        steps={steps}
                        projects={projects}
                        models={models}
                        handlers={handlers}
                    />
                </div>
                <DialogFooter className="items-center sm:justify-between">
                    <Button
                        type="button"
                        variant="ghost"
                        disabled={saving}
                        onClick={lambda { handlers["onBack"](); }}
                    >
                        {"Back" if step > 0 else "Cancel"}
                    </Button>
                    <Button
                        type="button"
                        disabled={blocked}
                        onClick={lambda { handlers["onNext"](); }}
                    >
                        {if saving {
                            <Spinner key="sp"/>
                        }}
                        {(
                            "Saving…"
                                if saving
                                else ("Save agent" if editing else "Create agent")
                        )
                            if last
                            else "Next"}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>;
}
