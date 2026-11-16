"""Step 1: which role the agent plays, and its name. Roles come from the Roles
page; an agent adds nothing there."""

import from ...models { RoleView }
import from ..ui.button { Button }
import from ..ui.input { Input }
import from ..ui.label { Label }

def:pub StepRole(
    draft: dict[str, any],
    roles: list[RoleView],
    editing: bool,
    onPick: Callable[[str], None],
    onField: Callable[[str, any], None],
    onAll: Callable[[], None]
) -> JsxElement {
    if len(roles) == 0 {
        return
            <p className="text-sm text-muted-foreground">
                Add a role on the Roles page first. An agent plays one of them.
            </p>;
    }
    return
        <div className="flex flex-col gap-4">
            <p className="text-sm text-muted-foreground">
                Which role does this agent play? Roles come from the Roles page.
            </p>
            <div className="grid gap-2 sm:grid-cols-2">
                {for r in roles {
                    <button
                        key={r.id}
                        type="button"
                        aria-pressed={draft["role_id"] == r.id}
                        className={"rounded-md border p-3 text-left text-[13.5px] transition-colors "
                            + (
                                "border-dashed border-ai bg-ai-wash"
                                    if draft["role_id"] == r.id
                                    else "hover:bg-accent"
                            )}
                        onClick={lambda { onPick(r.id); }}
                    >
                        <span className="font-medium">{r.name}</span>
                        <span className="meta block truncate">
                            {r.blurb or "No description"}
                        </span>
                    </button>
                }}
            </div>
            <div className="flex flex-wrap items-end gap-3">
                <div className="grid min-w-[220px] flex-1 gap-2">
                    <Label htmlFor="agent-name">Agent name</Label>
                    <Input
                        id="agent-name"
                        placeholder="Pick a role first"
                        value={draft["name"]}
                        onChange={lambda (e: ChangeEvent) { onField(
                            "name", e.target.value
                        ); }}
                    />
                </div>
                {if not editing {
                    <Button
                        key="all"
                        type="button"
                        variant="outline"
                        onClick={lambda { onAll(); }}
                    >
                        Create one agent for every role
                    </Button>
                }}
            </div>
        </div>;
}
