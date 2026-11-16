"""Ask once before an agent and its canvas are deleted."""

import from ...models { AgentView }
import from ..workspace.ConfirmDialog { ConfirmDialog }

def:pub DeleteAgentDialog(
    agent: AgentView | None,
    busy: bool,
    onConfirm: Callable[[], None],
    onCancel: Callable[[], None]
) -> JsxElement {
    return
        <ConfirmDialog
            open={agent is not None}
            title={"Delete " + (agent.name if agent else "") + "?"}
            body="Its past runs stay as history. The agent and its canvas are removed."
            confirmLabel="Delete agent"
            busy={busy}
            onConfirm={onConfirm}
            onOpenChange={lambda (o: bool) { if not o { onCancel(); }}}
        />;
}
