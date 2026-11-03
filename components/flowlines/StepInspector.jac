"""A step's sheet in edit mode: what sits there (the count and first titles the
line already carries, no request), its AI, settings, entry rules and arrows, with
Connect and Delete at the foot. Every field saves on its own; there is no Save."""

import from ...models { StepView }
import from .StepSheetHead { StepSheetHead }
import from .StepPeek { StepPeek }
import from .StepAiCard { StepAiCard }
import from .StepSettings { StepSettings }
import from .StepRules { StepRules }
import from .StepLinks { StepLinks }
import from ..ui.button { Button }
import from ..common.glyphs { Spinner }

def:pub StepInspector(
    step: StepView,
    place: str = "",
    steps: list[StepView] = [],
    form: dict[str, str] = {},
    roleOptions: list[str] = [],
    connecting: bool = False,
    saving: bool = False,
    confirmingDelete: bool = False,
    onField: Callable[[str, str], None] = None,
    onNameCommit: Callable[[], None] = None,
    onConnect: Callable[[], None] = None,
    onCancelConnect: Callable[[], None] = None,
    onDelete: Callable[[], None] = None,
    onUnlink: Callable[[str, str], None] = None,
    onRule: Callable[[str, bool], None] = None,
    onClose: Callable[[], None] = None
) -> JsxElement {
    return
        <aside aria-label={step.name} className="flex min-h-0 flex-1 flex-col">
            <StepSheetHead step={step} place={place} onClose={onClose}/>
            <div
                className="flex min-h-0 flex-1 flex-col gap-5 overflow-y-auto px-5 pt-4 pb-6"
            >
                <StepPeek step={step}/>
                {if len(step.ai) > 0 {
                    <StepAiCard key="ai" names={step.ai}/>
                }}
                <StepSettings
                    form={form}
                    roleOptions={roleOptions}
                    onField={onField}
                    onNameCommit={onNameCommit}
                />
                <StepRules
                    needsDue={step.needs_due_date}
                    needsPr={step.needs_pr}
                    onRule={onRule}
                />
                <StepLinks step={step} steps={steps} onUnlink={onUnlink}/>
            </div>
            <div className="flex shrink-0 items-center gap-2 border-t px-5 py-3">
                <Button
                    size="sm"
                    variant={"destructive" if confirmingDelete else "ghost"}
                    className={""
                        if confirmingDelete
                        else "-ml-2 text-danger hover:text-danger"}
                    disabled={saving}
                    onClick={lambda { if onDelete { onDelete(); }}}
                >
                    {if saving and confirmingDelete {
                        <Spinner key="sp"/>
                    }}
                    {"Click again to delete" if confirmingDelete else "Delete step"}
                </Button>
                <Button
                    size="sm"
                    variant="outline"
                    className="ml-auto"
                    onClick={lambda { if connecting {
                        if onCancelConnect {
                            onCancelConnect();
                        }
                    } elif onConnect {
                        onConnect();
                    } }}
                >
                    {"Cancel connect" if connecting else "Connect to a step"}
                </Button>
            </div>
        </aside>;
}
