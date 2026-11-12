"""Step 1: the workspace's name and its first project."""

import from ..ui.button { Button }
import from ..ui.input { Input }
import from ..ui.label { Label }
import from ..common.glyphs { Spinner }
import from .SetupParts { StepTitle, FieldError, SaveError }

glob FIELD_LABEL: str = "text-[13px] font-medium";

def:pub TeamStep(
    orgName: str,
    projectName: str,
    orgError: str,
    projectError: str,
    saveError: str,
    busy: bool,
    onOrg: Callable[[str], None],
    onProject: Callable[[str], None],
    onSubmit: Callable[[FormEvent], any]
) -> JsxElement {
    return
        <form onSubmit={onSubmit} noValidate={True} className="flex flex-col gap-5">
            <StepTitle title="Name your workspace"/>
            <div className="grid gap-1.5">
                <Label htmlFor="setup-org" className={FIELD_LABEL}>
                    Team or company
                </Label>
                <Input
                    id="setup-org"
                    value={orgName}
                    autoComplete="organization"
                    aria-invalid={orgError != ""}
                    aria-describedby={"setup-org-error" if orgError else None}
                    onChange={lambda (e: ChangeEvent) { onOrg(e.target.value); }}
                    placeholder="Acme Robotics"
                    autoFocus={True}
                    className="h-10"
                />
                {if orgError {
                    <FieldError key="org" id="setup-org-error" message={orgError}/>
                }}
            </div>
            <div className="grid gap-1.5">
                <Label htmlFor="setup-project" className={FIELD_LABEL}>
                    First project
                </Label>
                <Input
                    id="setup-project"
                    value={projectName}
                    aria-invalid={projectError != ""}
                    aria-describedby={"setup-project-error"
                        if projectError
                        else "setup-project-hint"}
                    onChange={lambda (e: ChangeEvent) { onProject(e.target.value); }}
                    placeholder="Website redesign"
                    className="h-10"
                />
                {if projectError {
                    <FieldError
                        key="project"
                        id="setup-project-error"
                        message={projectError}
                    />
                } else {
                    <p key="hint" id="setup-project-hint" className="meta">
                        You can add more projects later from Workspace.
                    </p>
                } }
            </div>
            {if saveError {
                <SaveError key="err" message={saveError}/>
            }}
            <div className="flex justify-end">
                <Button
                    type="submit"
                    disabled={busy}
                    className="h-10 px-4 font-semibold"
                >
                    {if busy {
                        <Spinner key="sp"/>
                    }}
                    {"Saving…" if busy else "Continue"}
                </Button>
            </div>
        </form>;
}
