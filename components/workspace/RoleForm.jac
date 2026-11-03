"""The inline form that adds a role or renames one: its name and what it does."""

import from ..ui.button { Button }
import from ..ui.input { Input }

def:pub RoleForm(
    name: str,
    blurb: str,
    submitLabel: str,
    saving: bool,
    onName: Callable[[str], None],
    onBlurb: Callable[[str], None],
    onSubmit: Callable[[], any],
    onCancel: Callable[[], None]
) -> JsxElement {
    return
        <form
            className="flex flex-wrap items-center gap-2"
            onSubmit={lambda (e: FormEvent) {
                e.preventDefault();
                onSubmit();
            }}
        >
            <Input
                className="h-8 w-48"
                placeholder="Role name"
                autoFocus={True}
                value={name}
                onChange={lambda (e: ChangeEvent) { onName(e.target.value); }}
            />
            <Input
                className="h-8 w-64 max-w-full"
                placeholder="What this role does (optional)"
                value={blurb}
                onChange={lambda (e: ChangeEvent) { onBlurb(e.target.value); }}
            />
            <Button type="submit" size="sm" disabled={saving or not name.strip()}>
                {submitLabel}
            </Button>
            <Button
                type="button"
                size="sm"
                variant="ghost"
                onClick={lambda { onCancel(); }}
            >
                Cancel
            </Button>
        </form>;
}
