"""A role's AI responsibilities under its row in the Roles tab: one line each,
add buttons for what it lacks, and the editor dialog. Every write reloads the
page's settings through `onChanged`."""

import from ....models { ResponsibilityView, StepView }
import from ....constants { AI_RESPONSIBILITIES }
import from ....services.agents.agents { SaveResponsibility, DeleteResponsibility }
import from .AddResponsibility { AddResponsibility }
import from .ResponsibilityEditor { ResponsibilityEditor }
import from .ResponsibilityLine { ResponsibilityLine }
import from "sonner" { toast }

glob BLANK: dict[str, str] = {
         "key": "",
         "instructions": "",
         "mode": "comment",
         "model": "",
         "enabled": "yes"
     };

def:pub Responsibilities(
    roleId: str,
    roleName: str,
    items: list[ResponsibilityView],
    steps: list[StepView],
    aiEnabled: bool,
    onChanged: Callable[[], any],
    onOrganization: Callable[[], None]
) -> JsxElement {
    has editorOpen: bool = False,
        editingId: str = "",
        form: dict[str, str] = BLANK,
        picked: list[str] = [],
        saving: bool = False;

    def openNew(key: str) -> None;
    def openEdit(r: ResponsibilityView) -> None;
    def setField(name: str, value: str) -> None;
    def toggleStep(stepId: str) -> None;
    def nameOf(key: str) -> str;
    def whereOf(r: ResponsibilityView) -> str;
    async def save -> None;
    async def remove -> None;
    async def flip(r: ResponsibilityView, wanted: bool) -> None;

    owned = [
        s
        for s in steps
        if s.owner == roleName
    ];
    held = [r.key for r in items];
    addable = [
        c
        for c in AI_RESPONSIBILITIES
        if c["key"] not in held
    ];
    return
        <div className="mt-2 flex flex-col gap-1.5">
            {for r in items {
                <ResponsibilityLine
                    key={r.id}
                    label={"AI " + nameOf(r.key).lower()}
                    detail={whereOf(r)}
                    enabled={r.enabled}
                    paused={not aiEnabled and r.enabled}
                    switchLabel={nameOf(r.key) + " for " + roleName}
                    onToggle={lambda (v: bool) { flip(r, v); }}
                    onOpen={lambda { openEdit(r); }}
                    onOrganization={onOrganization}
                />
            }}
            {if len(addable) > 0 {
                <AddResponsibility key="add" entries={addable} onAdd={openNew}/>
            }}
            <ResponsibilityEditor
                open={editorOpen}
                editing={bool(editingId)}
                title={nameOf(form["key"]) + " for " + roleName}
                form={form}
                picked={picked}
                steps={owned}
                saving={saving}
                onField={setField}
                onToggleStep={toggleStep}
                onOpenChange={lambda (o: bool) { editorOpen = o; }}
                onSave={save}
                onDelete={remove}
            />
        </div>;
}
