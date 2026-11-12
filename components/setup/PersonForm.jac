"""Add one person in setup: names and an optional role, a row at the panel's foot.
They are assignees, not accounts, so nothing else is asked."""

import from ..ui.button { Button }
import from ..ui.input { Input }
import from ..ui.label { Label }
import from ..common.glyphs { Spinner }
import from .SetupParts { FieldError }

def:pub PersonForm(
    first: str,
    last: str,
    role: str,
    firstError: str,
    busy: bool,
    onField: Callable[[str, str], None],
    onSubmit: Callable[[FormEvent], any]
) -> JsxElement {
    return
        <form
            onSubmit={onSubmit}
            noValidate={True}
            className="grid gap-2 p-3 sm:grid-cols-[minmax(0,1fr)_minmax(0,1fr)_minmax(0,1fr)_auto]"
        >
            <Label htmlFor="setup-first" className="sr-only">First name</Label>
            <Input
                id="setup-first"
                value={first}
                autoComplete="off"
                aria-invalid={firstError != ""}
                aria-describedby={"setup-first-error" if firstError else None}
                onChange={lambda (e: ChangeEvent) { onField("first", e.target.value); }}
                placeholder="First name"
                autoFocus={True}
                className="h-9"
            />
            <Label htmlFor="setup-last" className="sr-only">Last name</Label>
            <Input
                id="setup-last"
                value={last}
                autoComplete="off"
                onChange={lambda (e: ChangeEvent) { onField("last", e.target.value); }}
                placeholder="Last name"
                className="h-9"
            />
            <Label htmlFor="setup-role" className="sr-only">Role (optional)</Label>
            <Input
                id="setup-role"
                value={role}
                autoComplete="off"
                onChange={lambda (e: ChangeEvent) { onField("role", e.target.value); }}
                placeholder="Role (optional)"
                className="h-9"
            />
            <Button
                type="submit"
                variant="outline"
                disabled={busy}
                className="h-9 px-4 font-semibold"
            >
                {if busy {
                    <Spinner key="sp"/>
                }}
                Add
            </Button>
            {if firstError {
                <div key="first-error" className="sm:col-span-4">
                    <FieldError id="setup-first-error" message={firstError}/>
                </div>
            }}
        </form>;
}
